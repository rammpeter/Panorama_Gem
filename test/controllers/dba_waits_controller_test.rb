# encoding: utf-8
require 'test_helper'

class DbaWaitsControllerTest < ActionController::TestCase

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context
    initialize_min_max_snap_id_and_times
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end


  test "show_system_events with xhr: true" do
    post :show_system_events, :params => {:format=>:html, :sample_length=>"1", :filter=>"", :suppress_idle_waits=>"1", :update_area=>:hugo }
    assert_response :success
  end

  test "show_session_waits with xhr: true" do
    post :show_session_waits, :params => {:format=>:html, :instance=>1, :event=>"Hugo", :update_area=>:hugo }
    assert_response :success
  end


  test "gc_request_latency with xhr: true" do
    get :gc_request_latency, :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success
  end

  test "list_gc_request_latency_history with xhr: true" do
    get :list_gc_request_latency_history, :params => {:format=>:html, :instance=>1, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :update_area=>:hugo }
    assert_response management_pack_license == :none ? :error : :success
  end

  test "show_ges_blocking_enqueue with xhr: true" do
    get  :show_ges_blocking_enqueue, :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success
  end

end
