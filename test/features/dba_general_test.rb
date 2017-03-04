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

  test "DB-Locks / current" do
    login_and_menu_call('DBA general', 'DB-Locks', 'menu_dba_show_locks')
    page.must_have_content 'List current locks of different types'

    page.click_button 'DML-locks complete'
    wait_for_ajax
    page.must_have_content 'DML Database locks (from GV$Lock)'

    # click first row column "SID/SN" in grid
    page.find(:xpath, "//div[contains(@class, 'slick-cell') and contains(@class, 'l0') and contains(@class, 'r0')]").first('a').click
    wait_for_ajax
    page.must_have_content 'Details for session SID='

    # click first row column "Module" in grid
    page.first(:xpath, "//div[contains(@class, 'slick-inner-cell') and contains(@row, '0') and contains(@column, 'col2')]").first('a').click
    wait_for_ajax

    # click first row column "Action" in grid
    page.first(:xpath, "//div[contains(@class, 'slick-inner-cell') and contains(@row, '0') and contains(@column, 'col3')]").first('a').click
    wait_for_ajax

    page.click_button 'Blocking DML-Locks'
    wait_for_ajax
    page.must_have_content 'Blocking DML-Locks from gv$Lock'

    page.click_button 'Blocking DDL-Locks'
    wait_for_ajax
    page.must_have_content 'Blocking DDL-Locks in Library Cache (from DBA_KGLLock)'

    # save_and_open_screenshot  # cannot work at headless server
  end

  test "DB-Locks / Blocking locks historic" do
    login_and_menu_call('DBA general', 'DB-Locks', 'menu_active_session_history_show_blocking_locks_historic')
    page.must_have_content 'Blocking Locks from DBA_Hist_Active_Sess_History'



  end

  
end
