# encoding: UTF-8
require 'puma'
require 'playwright'
require 'rack/handler/puma'

=begin
Precondition for using playwright
npx playwright install

=end

class PlaywrightSystemTestCase < ActiveSupport::TestCase



  def setup
    set_session_test_db_context
    set_I18n_locale('en')
    initialize_min_max_snap_id_and_times(:minutes)
    ensure_playwright_is_up
    super
  end

  def teardown
    # TODO: Screenshot at exception
    super
  end

  @@pw_browser     = nil
  @@pw_page        = nil
  def ensure_playwright_is_up
    if @@pw_browser.nil?
      pw_puma_server = Puma::Server.new(Rails.application, Puma::Events.stdio, max_threads:100)
      host = '127.0.0.1'
      port = pw_puma_server.add_tcp_listener(host, 0).addr[1]
      pw_puma_server.run
      playwright = Playwright.create(playwright_cli_executable_path: 'npx playwright')
      @@pw_browser  = playwright.playwright.chromium.launch(headless: RbConfig::CONFIG['host_os'] != 'darwin')
      @@pw_page = @@pw_browser.new_page(viewport: { width: 800, height: 500 })
      @@pw_page.set_default_timeout(30000)
      @@pw_page.goto("http://#{host}:#{port}")
      do_login

      MiniTest.after_run do                                                       # called at exit of program
        pw_puma_server&.stop
        @@pw_browser&.close
        playwright&.stop
      end
    end
  end

  def page
    @@pw_page
  end

  def do_login
    test_config = PanoramaTestConfig.test_config
    # page.screenshot(path: '/tmp/playwright.png')
    #
    if test_config[:tns_or_host_port_sn] == :TNS
      page.query_selector("#database_modus_tns").check
      page.select_option('#database_tns', value: test_config[:tns])
    else
      page.query_selector("#database_modus_host").check
      page.query_selector('#database_host').fill(test_config[:host])

      page.query_selector('#database_port').fill(test_config[:port])

      page.query_selector('#database_sid_usage_SERVICE_NAME').check
      page.query_selector('#database_sid').fill(test_config[:sid])
    end

    page.query_selector('#database_user').fill(test_config[:user])
    page.query_selector('#database_password').fill(test_config[:password_decrypted])
    page.query_selector('#submit_login_dialog').click
    page.wait_for_selector('#management_pack_license_diagnostics_pack')   # dialog shown
    sleep(0.1)
    page.query_selector("#management_pack_license_#{management_pack_license}").check
    page.query_selector('text="Acknowledge and proceed"').click
    page.wait_for_selector('#main_menu')
  end

  # Call menu, last argument is DOM-ID of menu entry to click on
  # previous arguments are captions of submenus for hover to open submenu
  def menu_call(*args)
    if page.visible?('#main_menu >> #menu_node_0')                              #  menu 'Menu' if exists (small window width)
      page.query_selector('#main_menu >> #menu_node_0').hover                   # Open first level menu under "Menu"
    end

    args.each_index do |i|
      if i < args.length-1                                                      # SubMenu
        submenu = page.query_selector("#main_menu >> .sf-with-ul >> text =\"#{args[i]}\"")
        submenu.hover        # Expand menu node
      else                                                                      # last argument is DOM-ID of menu entry to click on
        page.query_selector("##{args[i]}").click                                # click menu
      end
    end
    assert_ajax_success
  end

  def wait_for_ajax(timeout_secs = 5)
    # page.expect_request_finished
    loop_count = 0
    while page.evaluate('indicator_call_stack_depth') > 0 && loop_count < timeout_secs
      sleep(0.1)
      loop_count += 0.1
      # puts "After #{loop_count} seconds: indicator_call_stack_depth = #{page.evaluate_script('indicator_call_stack_depth')}"
    end
    if loop_count >= timeout_secs
      message = "Timeout raised in wait_for_ajax after #{loop_count} seconds, indicator_call_stack_depth=#{page.evaluate_script('indicator_call_stack_depth') }"
      Rails.logger.error "############ #{message}"
      raise message
    end

    # Wait until indicator dialog becomes really unvisible
    loop_count = 0
    #    sleep(0.1)                                                                  # Allow browser to update DOM after setting ajax_indicator invisible
    while page.query_selector('#ajax_indicator:visible') && loop_count < timeout_secs   # only visible elements evaluate to true in has_css?
      Rails.logger.info "wait_for_ajax: ajax_indicator is still visible, retrying..."
      sleep(0.1)                                                                # Allow browser to update DOM after setting ajax_indicator invisible
      loop_count += 0.1
    end
    if loop_count >= timeout_secs
      message = "Timeout raised in wait_for_ajax after #{loop_count} seconds, indicator-dialog did not disappear') }"
      Rails.logger.error "############ #{message}"
      raise message
    end
  end

  def assert_ajax_success(timeout_secs = 60)
    wait_for_ajax(timeout_secs)
    assert_not error_dialog_open?
  end

  # Does the page contain the text
  def assert_text(expected_text)
    assert(page.content[expected_text], "Page should contain: #{expected_text}")
  end

  def error_dialog_open?
    page.query_selector('#error_dialog:visible')
  end

  # accept error due to missing management pack license
  # Error message "Access denied" called for _management_pack_license = :none ?
  def assert_ajax_success_and_test_for_access_denied(timeout_secs = 60)
    wait_for_ajax(timeout_secs)

    if  error_dialog_open?
      allowed_msg_content = []
      if management_pack_license != :diagnostics_and_tuning_pack
        allowed_msg_content << 'Sorry, accessing DBA_HIST_Reports requires licensing of Diagnostics and Tuning Pack'
      end

      if management_pack_license == :none
        allowed_msg_content <<  'because of missing license for '               # Access denied on table
      end

      raise_error = true
      error_dialog = page.query_selector('#error_dialog')
      allowed_msg_content.each do |amc|
        if error_dialog.content[amc]                                            # No error if dialog contains any of the strings
          raise_error = false
          begin
            page.click('#error_dialog_close_button')                            # Close the error dialog to ensure next actions may see the target, use ID for identification
          rescue Exception
            sleep(5)                                                            # retry after x seconds if exception raised
            page.click('#error_dialog_close_button')                            # Close the error dialog to ensure next actions may see the target, use ID for identification
          end
        end
      end

      assert(!raise_error, "ApplicationSystemTestCase.assert_ajax_success_or_access_denied: Error dialog raised but not because missing management pack license.\nmanagement_pack_license = #{management_pack_license} (#{management_pack_license.class})\nError dialog:\n#{error_dialog.text}")
      return true
    else
      return false                                                              # Error dialog not shown
    end
  end


end
