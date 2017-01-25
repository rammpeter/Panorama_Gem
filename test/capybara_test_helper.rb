class Capybara::Rails::TestCase


  def wait_for_ajax(timeout_secs = 10)

    loop_count = 0
    while page.evaluate_script('indicator_call_stack_depth') > 0 && loop_count < timeout_secs
      sleep(1)
      loop_count += 1
      # puts "After #{loop_count} seconds: indicator_call_stack_depth = #{page.evaluate_script('indicator_call_stack_depth')}"
    end
    if loop_count == timeout_secs
      raise "Timeout raise in wait_for_ajax after #{loop_count} seconds"
    end
  end


  # Login application at test-DB an create menu in browser
  def login_until_menu
    Capybara.current_driver     = :webkit                                       # Setting works for all Capybara-Tests
    Capybara.javascript_driver  = :webkit                                       # Setting works for all Capybara-Tests

    visit root_path                                                             # /env/index
    #page.save_and_open_page
    #assert_content page, "Please choose saved connection"

    page.must_have_content "Please choose saved connection"

    test_config = PanoramaOtto::Application.config.database_configuration["test_#{ENV['DB_VERSION']}"]
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
  end
end
