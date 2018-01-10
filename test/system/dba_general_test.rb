require "application_system_test_case"

class DbaGeneralTest < ApplicationSystemTestCase

  test "Start page" do
    login_and_menu_call('DBA general', 'menu_env_start_page')
    assert_ajax_success

    assert_text 'Current database'
    assert_text 'Server versions'
    assert_text 'Client versions'
    assert_text 'Instance data'
    assert_text 'Usage of Oracle management packs by Panorama'
    assert_text 'Handling hints'
  end

  test "DB-Locks / current" do
    login_and_menu_call('DBA general', 'DB-Locks', 'menu_dba_show_locks')
    assert_ajax_success
    assert_text 'List current locks of different types'

    page.click_button 'button_dml_locks'
    assert_ajax_success
    assert_text 'DML Database locks (from GV$Lock)'

    # click first row column "SID/SN" in grid
    page.first(:xpath, "//div[contains(@class, 'slick-cell') and contains(@class, 'l0') and contains(@class, 'r0')]").first('a').click
    assert_ajax_success
    assert_text 'Details for session SID='

    # click first row column "Module" in grid
    page.first(:xpath, "//div[contains(@class, 'slick-inner-cell') and contains(@row, '0') and contains(@column, 'col2')]").first('a').click
    assert_ajax_success

    # click first row column "Action" in grid
    page.first(:xpath, "//div[contains(@class, 'slick-inner-cell') and contains(@row, '0') and contains(@column, 'col3')]").first('a').click
    assert_ajax_success

    page.click_button 'button_blocking_dml_locks'
    assert_ajax_success
    assert_text 'Blocking DML-Locks from gv$Lock'

    page.click_button 'button_blocking_ddl_locks'
    assert_ajax_success
    assert_text 'Blocking DDL-Locks in Library Cache (from DBA_KGLLock)'

    page.click_button 'button_2pc'
    assert_ajax_success
    assert_text 'Pending two-phase commits '

    # save_and_open_screenshot  # cannot work at headless server
  end

  test "DB-Locks / Blocking locks historic" do
    login_and_menu_call('DBA general', 'DB-Locks', 'menu_active_session_history_show_blocking_locks_historic')
    assert_ajax_success
    assert_text 'Blocking Locks from DBA_Hist_Active_Sess_History'



  end


end