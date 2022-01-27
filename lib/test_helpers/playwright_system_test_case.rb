# encoding: UTF-8
require 'puma'
require 'playwright'

=begin
Precondition for using playwright
npx playwright install

=end

class PlaywrightSystemTestCase < ActiveSupport::TestCase

  def setup
    set_session_test_db_context
    set_I18n_locale('en')
    initialize_min_max_snap_id_and_times(:minutes)

    require 'rack/handler/puma'
    @server = Puma::Server.new(Rails.application, Puma::Events.stdio, max_threads:100)
    @host = '127.0.0.1'
    @port = @server.add_tcp_listener(@host, 0).addr[1]
    @server.run

    @playwright = Playwright.create(playwright_cli_executable_path: 'npx playwright')
    @browser    = @playwright.playwright.chromium.launch(headless: RbConfig::CONFIG['host_os'] != 'darwin')
    @page       = @browser.new_page(viewport: { width: 800, height: 500 })
    @page.set_default_timeout(30000)
    do_login
    super
  end

  def teardown
    # TODO: Screenshot at exception
    @browser&.close
    @playwright&.stop
    @server&.stop
    super
  end

  def do_login
    test_config = PanoramaTestConfig.test_config
    @page.goto("http://#{@host}:#{@port}")
    # page.screenshot(path: '/tmp/playwright.png')
    #
    if test_config[:tns_or_host_port_sn] == :TNS
      @page.query_selector("#database_modus_tns").check
      @page.select_option('#database_tns', value=test_config[:tns])
    else
      @page.query_selector("#database_modus_host").check
      @page.query_selector('#database_host').fill(test_config[:host])

      @page.query_selector('#database_port').fill(test_config[:port])

      @page.query_selector('#database_sid_usage_SERVICE_NAME').check
      @page.query_selector('#database_sid').fill(test_config[:sid])
    end

    @page.query_selector('#database_user').fill(test_config[:user])
    @page.query_selector('#database_password').fill(test_config[:password_decrypted])
    @page.query_selector('#submit_login_dialog').click
    @page.wait_for_selector('#management_pack_license_diagnostics_pack')   # dialog shown
    sleep(0.1)
    @page.query_selector("#management_pack_license_#{management_pack_license}").check
    @page.query_selector('text="Acknowledge and proceed"').click
    @page.wait_for_selector('#main_menu')
  end

  # Call menu, last argument is DOM-ID of menu entry to click on
  # previous arguments are captions of submenus for hover to open submenu
  def menu_call(*args)
    if @page.visible?('#main_menu >> #menu_node_0')                               #  menu 'Menu' if exists (small window width)
      @page.query_selector('#main_menu >> #menu_node_0').hover                    # Open first level menu under "Menu"
    end

    args.each_index do |i|
      if i < args.length-1                                                    # SubMenu
        submenu = @page.query_selector("#main_menu >> .sf-with-ul >> text =\"#{args[i]}\"")
        submenu.hover        # Expand menu node
      else                                                                    # last argument is DOM-ID of menu entry to click on
        @page.query_selector("##{args[i]}").click                              # click menu
      end
    end
    wait_for_ajax
  end

  def wait_for_ajax(timeout_secs = 5)
    # temporary implementation
    # TODO: should be replaced with @page.wait_for_event('ajaxSuccess') if this function becomes available

    # process browser until timeout
    begin
      @page.wait_for_selector('#nonexistent_selector', timeout: timeout_secs * 1000)
    rescue
    end
  end
end
