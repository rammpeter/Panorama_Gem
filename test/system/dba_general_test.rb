require "test_helper"

class DbaGeneralTest < ApplicationSystemTestCase

  setup do
    set_session_test_db_context
    set_I18n_locale('en')
    initialize_min_max_snap_id_and_times(:minutes)
  end

  test "DB-Locks / Blocking locks historic" do
    login_and_menu_call('DBA general', 'DB-Locks', 'menu_active_session_history_show_blocking_locks_historic')
    assert_ajax_success

    assert_text 'Blocking Locks from '

    fill_in('time_selection_start_default', with: @time_selection_start)
    fill_in('time_selection_end_default',   with: @time_selection_end)

    page.click_button 'Blocking locks session dependency tree'
    unless assert_ajax_success_and_test_for_access_denied(300)                  # May last a bit longer
      assert_text 'Blocking locks between'
    end

    page.click_button 'Blocking locks event dependency'
    unless assert_ajax_success_and_test_for_access_denied(300)                  # May last a bit longer
      assert_text 'Event combinations for waiting and blocking sessions'
    end
  end


end