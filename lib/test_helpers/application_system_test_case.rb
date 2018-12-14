#require "test_helper"

#TODO: test/dummy/public/assets entsorgen incl. .sprockets* vor Tests


Capybara.register_driver :headless_chrome do |app|
  args = ['window-size=1400,1000']                                              # window must be large enough in Y-dimension to paint full menu
  args.concat %w[headless disable-gpu] if RbConfig::CONFIG['host_os'] != 'darwin' # run headless if not Mac-OS
  args.concat ['--no-sandbox']                                                  # allow running chrome as root in docker
  args.concat ["--enable-logging", "--verbose", "--log-path=chromedriver.log"]   # don't suppress chromedriver_helper log output

  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
      loggingPrefs: {browser: 'ALL', driver: 'DEBUG'},                           # Activate logging by selenium webdriver
      chromeOptions: { args: args }
  )

  # Enable debug by "$DEBUG = true" or by environment variable "export DEBUG=1"
  # This drives debug logging in selenium-webdriver/lib/selenium/webdriver/common/logger.rb
  Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      desired_capabilities: capabilities,
      driver_opts: { port_server: 9215, logLevel: :debug}     # pin chromedriver to use port 9215
  )
  puts "Waiting for chromedriver_helper to start"
  sleep 10
  puts "Assuming chromedriver_helper has started now and may accept network requests"
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  #driven_by :selenium, using: :chrome, screen_size: [2560, 1440]
  driven_by :headless_chrome

  def wait_for_ajax(timeout_secs = 60)

    loop_count = 0
    while page.evaluate_script('indicator_call_stack_depth') > 0 && loop_count < timeout_secs
      sleep(1)
      loop_count += 1
      # puts "After #{loop_count} seconds: indicator_call_stack_depth = #{page.evaluate_script('indicator_call_stack_depth')}"
    end
    if loop_count == timeout_secs
      Rails.logger.error "############ Timeout raised in wait_for_ajax after #{loop_count} seconds, indicator_call_stack_depth=#{page.evaluate_script('indicator_call_stack_depth') }"
    end
  end

  # Login application at test-DB an create menu in browser
  def login_until_menu

    begin
      visit root_path                                                             # /env/index
    rescue Exception => e
      puts "Exception '#{e.message}' catched from calling visit root_path"
      raise e
    end

    begin
      assert_text "Please choose saved connection"
    rescue Capybara::ExpectationNotMet
      sleep 5                                                                   # Sleep some time let rails start
      assert_text "Please choose saved connection"                              # try again
    end

    test_config = PanoramaTestConfig.test_config

    test_url          = test_config[:test_url].split(":")
    test_host         = test_url[3].delete "@"
    test_port         = test_url[4].split('/')[0].split(':')[0]
    test_sid          = test_url[5]
    test_service_name = test_url[4].split('/')[1]
    test_user         = test_config[:test_username]
    test_password     = test_config[:test_password]

    page.find_by_id('database_modus_host').set(true)                            # Choose host/port/sid for entry
#print page.html

    fill_in('database[host]', with: test_host)
    fill_in('database[port]', with: test_port)
    if test_sid
      page.find_by_id('database_sid_usage_SID').set(true)
      fill_in('database_sid', with: test_sid)
    end
    if test_service_name
      find_by_id('database_sid_usage_SERVICE_NAME').set(true)
      fill_in('database_sid', with: test_service_name)
    end
    fill_in('database_user', with: test_user)
    fill_in('database_password', with: test_password)
    click_button('submit_login_dialog')

    wait_for_ajax                                                               # Wait until start_page is loaded

    if page.html['please choose your management pack license'] && page.html['Usage of Oracle management packs by Panorama']
      page.find_by_id('management_pack_license_diagnostics_and_tuning_pack').set(true)
      click_button('Acknowledge and proceed')
      wait_for_ajax                                                               # Wait until start_page is loaded
    end
  end

  # Call menu, last argument is DOM-ID of menu entry to click on
  # previous arguments are captions of submenus for hover to open submenu
  def login_and_menu_call(*args)
    login_until_menu

    menu_node_0 = page.first(:css, '#main_menu #menu_node_0')                   # find menu 'Menu' if exists (small window width)
    unless menu_node_0.nil?
      menu_node_0.hover
      sleep 0.2
    end

    args.each_index do |i|
      if i < args.length-1                                                      # SubMenu
        page.find('#main_menu .sf-with-ul', :text => args[i], visible: false).hover        # Expand menu node
        sleep(0.5)
      else                                                                      # last argument is DOM-ID of menu entry to click on
        click_link(args[i], visible: false)                                     # click menu
        wait_for_ajax                                                           # Wait for ajax request to complete
      end
    end
  end

  # close popup dialog if open. May be this dialog hides menu entries
  def close_possible_popup_message
    close_button = page.first(:css, '.ui-dialog-titlebar .ui-icon-closethick')
    if !close_button.nil? && close_button.visible?
      close_button.click
      sleep 0.5
    end
  end

  # Check if error-dialog has been shown by previous ajax call
  def error_dialog_open?
    error_dialog = page.first(:css, '#error_dialog')
    !error_dialog.nil? && error_dialog.visible?
  end

  def assert_ajax_success
    wait_for_ajax
    assert_not error_dialog_open?
  end

  # accept error due to missing management pack license
  def assert_ajax_success_or_access_denied
    wait_for_ajax
    error_dialog = page.first(:css, '#error_dialog')
    if  !error_dialog.nil? && error_dialog.visible?
      if management_pack_license == :none
        message = "ApplicationSystemTestCase.assert_ajax_success_or_access_denied: Error dialog raised but not because missing management pack license. Error dialog:\n#{error_dialog.text}"
        assert(((error_dialog.text['Access denied on table'] && error_dialog.text['because of missing license for ']) ||
                        error_dialog.text['Sorry, accessing DBA_HIST_Reports requires licensing of Diagnostics and Tuning Pack']
                    ),
                    message)
      end
    end
  end

  # click first occurrence of tag in xpath expression and wait for successful ajax action
  def click_first_xpath_hit(xpath_expression, comment, tag = 'a')
    xpath_object = page.first(:xpath, xpath_expression)
    raise "xpath expression not found\n#{xpath_expression}\n#{comment}" if xpath_object.nil?
    tag_object = xpath_object.first(tag)

    raise "tag '#{tag}' in xpath expression not found\n#{xpath_expression}\n#{comment}" if tag_object.nil?
    raise "tag '#{tag}' in xpath expression not visible\n#{xpath_expression}\n#{comment}" if !tag_object.visible?

    tag_object.click
    assert_ajax_success
  rescue Exception => e
    message = "Exception '#{e.class}': '#{e.message}' for '#{comment}'"
    Rails.logger.error message                                                # Show message in test.log
    puts message                                                              # Show message in test output
    raise
  end

  def get_time_string(minutes_back = 0, mask = :minutes)
    full_mask = case mask
                  when :minutes then '%Y-%m-%d %H:%M'
                  when :seconds then '%Y-%m-%d %H:%M:%S'
                  else raise "Unknown mask '#{mask}'"
                end

    (Time.now - minutes_back * 60).strftime(full_mask)
  end

end
