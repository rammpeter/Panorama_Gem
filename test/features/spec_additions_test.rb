require "test_helper"

class SpecAdditionsTest < Capybara::Rails::TestCase

  test "Dragnet investigation" do
    # Call menu entry
    login_and_menu_call('Spec. additions', 'menu_dragnet_show_selection')

    page.must_have_content 'Dragnet investigation for performance bottlenecks and usage of anti-pattern'
    page.must_have_content 'Select dragnet-SQL for execution'
    page.must_have_content '1. Potential in DB-structures'

    # click first node
    page.first(:xpath, "//i[contains(@class, 'jstree-icon') and contains(@class, 'jstree-ocl') and contains(@role, 'presentation')]").click
    wait_for_ajax
    page.must_have_content '1. Ensure optimal storage parameter for indexes'

    # click point 1.6
    page.first(:xpath, "//a[contains(@id, '_0_5_anchor')]").click
    wait_for_ajax
    page.must_have_content 'Protection of colums with foreign key references by index can be necessary for'

    # Click "Show SQL"                                       ^
    page.first(:xpath, "//input[contains(@type, 'submit') and contains(@name, 'commit_show')]").click
    wait_for_ajax
    page.must_have_content 'FROM   DBA_Constraints Ref'

    # Click "Do selection"
    page.first(:xpath, "//input[contains(@type, 'submit') and contains(@name, 'commit_exec')]").click
    wait_for_ajax

  end

=begin
  test "DB-Locks / current" do
    login_and_menu_call('DBA general', 'DB-Locks', 'menu_dba_show_locks')
    page.must_have_content 'List current locks of different types'

    page.click_button 'button_dml_locks'
    wait_for_ajax
    page.must_have_content 'DML Database locks (from GV$Lock)'

    # click first row column "SID/SN" in grid
    page.first(:xpath, "//div[contains(@class, 'slick-cell') and contains(@class, 'l0') and contains(@class, 'r0')]").first('a').click
    wait_for_ajax
    page.must_have_content 'Details for session SID='

    # click first row column "Module" in grid
    page.first(:xpath, "//div[contains(@class, 'slick-inner-cell') and contains(@row, '0') and contains(@column, 'col2')]").first('a').click
    wait_for_ajax

    # click first row column "Action" in grid
    page.first(:xpath, "//div[contains(@class, 'slick-inner-cell') and contains(@row, '0') and contains(@column, 'col3')]").first('a').click
    wait_for_ajax

    page.click_button 'button_blocking_dml_locks'
    wait_for_ajax
    page.must_have_content 'Blocking DML-Locks from gv$Lock'

    page.click_button 'button_blocking_ddl_locks'
    wait_for_ajax
    page.must_have_content 'Blocking DDL-Locks in Library Cache (from DBA_KGLLock)'

    page.click_button 'button_2pc'
    wait_for_ajax
    page.must_have_content 'Pending two-phase commits '

    # save_and_open_screenshot  # cannot work at headless server
  end
=end

end
