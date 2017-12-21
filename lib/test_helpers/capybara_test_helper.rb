require "minitest/rails/capybara"

require 'capybara/poltergeist'

# replaced by chrome
=begin
class Capybara::Rails::TestCase


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

    Capybara.current_driver    = :poltergeist                                    # Setting works for all Capybara-Tests
    Capybara.javascript_driver = :poltergeist

    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app, window_size: [2560, 1440])          # Menu should not wrap to vertical
    end

#    Capybara.current_driver     = :webkit                                       # Setting works for all Capybara-Tests
#    Capybara.javascript_driver  = :webkit                                       # Setting works for all Capybara-Tests

    begin
      visit root_path                                                             # /env/index
      puts "Next step after calling visit root_path"
    rescue
      puts "Exception catched from calling visit root_path"
    end

    #page.save_and_open_page
    #assert_content page, "Please choose saved connection"

    page.must_have_content "Please choose saved connection"

    #test_config = PanoramaOtto::Application.config.database_configuration["test_#{ENV['DB_VERSION']}"]
    test_config = PanoramaTestConfig.test_config

    test_url          = test_config['test_url'].split(":")
    test_host         = test_url[3].delete "@"
    test_port         = test_url[4].split('/')[0].split(':')[0]
    test_sid          = test_url[5]
    test_service_name = test_url[4].split('/')[1]
    test_user         = test_config["test_username"]
    test_password     = test_config["test_password"]

    page.find_by_id('database_modus_host').set(true)                            # Choose host/port/sid for entry
    #print page.html

    fill_in('database[host]', with: test_host)
    fill_in('database[port]', with: test_port)
    if (test_sid)
      page.find_by_id('database_sid_usage_SID').set(true)
      fill_in('database_sid', with: test_sid)
    end
    if (test_service_name)
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

    args.each_index do |i|
      if i < args.length-1                                                      # SubMenu
        page.find('.sf-with-ul', :text => args[i]).hover                        # Expand menu node
        sleep(0.5)
      else                                                                      # last argument is DOM-ID of menu entry to click on
        click_link args[i]                                                      # click menu
        wait_for_ajax                                                           # Wait for ajax request to complete
      end
    end
  end

end
=end
