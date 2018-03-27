# encoding: utf-8
require 'test_helper'

class DbaPgaControllerTest < ActionController::TestCase

  setup do
    set_session_test_db_context

    initialize_min_max_snap_id_and_times
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end


  test "list_pga_stat_historic with xhr: true" do
    post :list_pga_stat_historic, :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :instance =>1 }
    assert_response management_pack_license == :none ? :error : :success
  end

end
