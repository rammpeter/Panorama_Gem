# encoding: utf-8
require 'test_helper'

class DbaPgaControllerTest < ActionController::TestCase

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{}

    min_alter_org = sql_select_one "SELECT /* Panorama-Tool Ramm */ MAX(Begin_Interval_Time) FROM DBA_Hist_Snapshot"
    max_alter_org = min_alter_org-10000
    @time_selection_end = min_alter_org.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = (max_alter_org).strftime("%d.%m.%Y %H:%M")

  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions" do
    call_controllers_menu_entries_with_actions
  end


  test "list_pga_stat_historic" do
    post :list_pga_stat_historic, :params => {:format=>:js, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :instance =>1 }
    assert_response :success
  end

end
