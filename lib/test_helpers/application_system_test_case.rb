#require "test_helper"

#TODO: test/dummy/public/assets entsorgen incl. .sprockets* vor Tests

# Remark 2020-01-06
# You also don’t need to use Capybara’s save_and_open_screenshot, because Rails provides a take_screenshot method, that saves a screenshot in /tmp, and provides a link in the test output for easy access.


=begin
Capybara.register_driver :headless_chrome do |app|
  args = ['window-size=1400,1000']                                              # window must be large enough in Y-dimension to paint full menu
  args.concat %w[headless disable-gpu] if RbConfig::CONFIG['host_os'] != 'darwin' # run headless if not Mac-OS
  args.concat ['--no-sandbox']                                                  # allow running chrome as root in docker
  args.concat ["--enable-logging", "--verbose", "--log-path=chromedriver.log"]  # don't suppress chromedriver_helper log output
  args.concat ['--disable-dev-shm-usage']                                       # try to prevent Selenium::WebDriver::Error::NoSuchDriverError: invalid session id



  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
      loggingPrefs: {browser: 'ALL', driver: 'ALL', performance: 'ALL'},                           # Activate logging by selenium webdriver
      chromeOptions: { args: args }
  )

  # Enable debug by "$DEBUG = true" or by environment variable "export DEBUG=1"
  # This drives debug logging in selenium-webdriver/lib/selenium/webdriver/common/logger.rb
  driver = Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      desired_capabilities: capabilities
  )

  # Selenium::WebDriver.logger.level = :debug                                     # Enable Selenium logging to console

  driver
end
=end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # $DEBUG = true # Activate logging for Webdriver also
  using   = (RbConfig::CONFIG['host_os'] != 'darwin' ? :headless_chrome : :chrome) # run headless if not Mac-OS
  service = ::Selenium::WebDriver::Service.chrome(args: { whitelisted_ips: true, verbose: true, log_path: '/tmp/chromedriver.log' })
#  options = {service: service}
  options = {}
#options = {driver_opts: '--whitelisted-ips'}  # command line options for chromedriver

  driven_by :selenium, using: using, screen_size: [1400, 1000], options: options do |driver_options|
    driver_options.add_argument('--no-sandbox')                                 # allow running chrome as root in docker
    driver_options.add_argument('--disable-gpu')                                # run headless in docker if not Mac-OS
    driver_options.add_argument('--disable-dev-shm-usage')                      # try to prevent Selenium::WebDriver::Error::NoSuchDriverError: invalid session id
  end

  def wait_for_ajax(timeout_secs = 300)
    loop_count = 0
    while page.evaluate_script('indicator_call_stack_depth') > 0 && loop_count < timeout_secs
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
    while page.has_css?('#ajax_indicator') && loop_count < timeout_secs   # only visible elements evaluate to true in has_css?
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

  # Wait unti css node becomes visible
  # return node or nil after timeout
  def wait_for_css_visibility(css_selector, visibility_needed = true)
    css_node = page.find(:css, css_selector, visible: visibility_needed)
    loop_count = 0
    while !css_node.visible? do
      loop_count += 1
      puts "Sleeping #{loop_count/10.0} seconds waiting for menu node '#{css_selector}' to become visible"
      sleep(0.1)
      return nil if loop_count > 100
    end
    css_node
  end

  def click_button_with_retry(caption)
    retry_count = 0
    max_retries = 100
    while retry_count < max_retries do
      retry_count += 1
      begin
        click_button(caption)
        break                                                                   # Leave while loop if successful
      rescue Exception => e
        if retry_count == max_retries
          Rails.logger.info "#{Time.now} click_button_with_retry for '#{caption}': Last retry failed with #{e.class} #{e.message}"
          raise e
        else
          Rails.logger.info "#{Time.now} click_button_with_retry for '#{caption}': Retry after #{e.class} #{e.message}"
          sleep 0.5                                                            # sleep not too long to prevent mouse over hint
        end
      end
    end
  end

  # Login application at test-DB an create menu in browser
  MAX_LOOPS = 100
  def login_until_menu
    loop_count = 0
    msg = ''
    while loop_count < MAX_LOOPS
      begin
        visit root_path                                                         # /env/index
        break
      rescue Exception => e
        Rails.logger.error "Exception '#{e.message}' catched from calling visit root_path in first tries"
        msg = e.message
        sleep 1                                                                     # Waiting for chromedriver to prevent 'unable to connect to chromedriver 127.0.0.1:9515'
        loop_count += 1
      end
    end

    if loop_count >= MAX_LOOPS
      puts "Exception '#{msg}' catched from calling visit root_path in last try"
      raise msg
    end

    begin
      assert_text "Please choose saved connection"
    rescue Capybara::ExpectationNotMet
      Rails.logger.info "Retry Please choose saved connection"
      sleep 5                                                                   # Sleep some time let rails start
      assert_text "Please choose saved connection"                              # try again
    end

    test_config = PanoramaTestConfig.test_config

    test_sid          = nil
    test_service_name = test_config[:sid]

    page.find_by_id('database_modus_host').set(true)                            # Choose host/port/sid for entry
#print page.html

    fill_in('database[host]', with: test_config[:host])
    fill_in('database[port]', with: test_config[:port])
    if test_sid
      page.find_by_id('database_sid_usage_SID').set(true)
      fill_in('database_sid', with: test_sid)
    end
    if test_service_name
      find_by_id('database_sid_usage_SERVICE_NAME').set(true)
      fill_in('database_sid', with: test_service_name)
    end
    fill_in('database_user', with: test_config[:user])
    fill_in('database_password', with: test_config[:password_decrypted])
    click_button('submit_login_dialog')

    wait_for_ajax                                                               # Wait until choose management pack is loaded

    if page.html['please choose your management pack license'] && page.html['Usage of Oracle management packs by Panorama']
      page.find_by_id("management_pack_license_#{management_pack_license}").set(true) # Set license according to test setting
      click_button_with_retry('Acknowledge and proceed')
      wait_for_ajax                                                             # Wait until start_page is loaded
    end
  end

  # Call menu, last argument is DOM-ID of menu entry to click on
  # previous arguments are captions of submenus for hover to open submenu
  def login_and_menu_call(*args)
    login_until_menu

    if page.has_css?('#main_menu #menu_node_0')                                 #  menu 'Menu' if exists (small window width)
      page.first(:css, '#main_menu #menu_node_0').hover                         # Open first level menu under "Menu"
      sleep 0.2
    end

    #menu_node_0 = page.first(:css, '#main_menu #menu_node_0')                   # find menu 'Menu' if exists (small window width)
    #unless menu_node_0.nil?
    #  menu_node_0.hover
    #  sleep 0.2
    #end

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
    if page.has_css?('.ui-dialog-titlebar .ui-icon-closethick')
      close_button = page.first(:css, '.ui-dialog-titlebar .ui-icon-closethick')
      close_button.click
      sleep 0.5
    end
  end

  # Check if error-dialog has been shown by previous ajax call
  def error_dialog_open?
    # error_dialog = page.first(:css, '#error_dialog')
    # !error_dialog.nil? && error_dialog.visible?
    page.has_css?('#error_dialog', visible: true)
  end

  def assert_ajax_success(timeout_secs = 60)
    wait_for_ajax(timeout_secs)
    assert_not error_dialog_open?
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
        allowed_msg_content <<  'because of missing license for '       # Access denied on table
      end

      raise_error = true
      error_dialog = page.first(:css, '#error_dialog')
      allowed_msg_content.each do |amc|
        raise_error = false if error_dialog.text[amc]                           # No error if dialog contains any of the strings
      end

      assert(!raise_error, "ApplicationSystemTestCase.assert_ajax_success_or_access_denied: Error dialog raised but not because missing management pack license.\nmanagement_pack_license = #{management_pack_license} (#{management_pack_license.class})\nError dialog:\n#{error_dialog.text}")
      return true
    else
      return false                                                              # Error dialog not shown
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

end
