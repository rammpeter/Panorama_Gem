require "test_helper"

class DbaGeneralPwTest < PlaywrightSystemTestCase

  test "Start page" do
    menu_call('DBA general', 'menu_env_start_page')
    content = page.content
    assert content['Current database']
    assert content['Server versions']
    assert content['Client versions']
    assert content['Instance data']
    assert content['Usage of Oracle management packs by Panorama']
    assert content['Handling hints']
  end

  test "DB-Locks / current" do
    menu_call('DBA general', 'DB-Locks', 'menu_dba_show_locks')
    assert_ajax_success
    assert_text 'List current locks of different types'

    page.click '#button_dml_locks:visible'
    unless assert_ajax_success_and_test_for_access_denied                       # Error dialog for "Access denied" called?
      assert_text 'DML Database locks (from GV$Lock)'                           # Check only if not error "Access denied" raised before
      slick_cell = page.query_selector('.slick-cell, .l0, .r0:visible')
      href = slick_cell.query_selector('a:visible')
      unless href.nil?                                                          # Session may not exists anymore
        puts href.inspect
        Dir.mkdir("#{Rails.root}/tmp/screenshots") unless File.exists?("#{Rails.root}/tmp/screenshots")
        page.screenshot(path: "#{Rails.root}/tmp/screenshots/peter.png")
        href.click
        assert_ajax_success
        assert_text 'Details for session SID='
      else
        Rails.logger.debug('DbaGeneralPwTest.DB-Locks / current'){"No session found with DML locks for test"}
      end
    end

    page.click '#button_blocking_dml_locks'
    unless assert_ajax_success_and_test_for_access_denied                       # Error dialog for "Access denied" called?
      assert_text 'Blocking DML-Locks from gv$Lock'                             # Check only if not error "Access denied" raised before
    end

    page.click '#button_blocking_ddl_locks'
    unless assert_ajax_success_and_test_for_access_denied                       # Error dialog for "Access denied" called?
      assert_text 'Blocking DDL-Locks in Library Cache (from DBA_KGLLock)'      # Check only if not error "Access denied" raised before
    end

    page.click '#button_2pc'
    unless assert_ajax_success_and_test_for_access_denied                       # Error dialog for "Access denied" called?
      assert_text 'Pending two-phase commits '                                  # Check only if not error "Access denied" raised before
    end


    # save_and_open_screenshot  # cannot work at headless server
  end

end

