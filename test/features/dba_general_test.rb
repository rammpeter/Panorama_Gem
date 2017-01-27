require "test_helper"

class DbaGeneralTest < Capybara::Rails::TestCase

  test "Start page" do
    login_and_menu_call('DBA general', 'menu_env_start_page')

    page.must_have_content 'Current database'
    page.must_have_content 'Server versions'
    page.must_have_content 'Client versions'
    page.must_have_content 'Instance data'
    page.must_have_content 'Usage of Oracle management packs by Panorama'
    page.must_have_content 'Handling hints'
  end

  test "DB-Locks current" do
    login_and_menu_call('DBA general', 'DB-Locks', 'menu_dba_show_locks')
    page.must_have_content 'List current locks of different types'

    page.click_button 'DML-locks complete'
    wait_for_ajax
    page.must_have_content 'DML Database locks (from GV$Lock)'
    save_and_open_screenshot

  end
end





