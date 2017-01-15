# encoding: utf-8
require 'test_helper'
include ActionView::Helpers::TranslationHelper
#include ActionDispatch::Http::URL

class DbaControllerTest < ActionController::TestCase

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{}
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end


  test "dba with xhr: true"       do
    get  :show_redologs, :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success

    post :list_redologs_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :update_area=>:hugo }
    assert_response :success
    post :list_redologs_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1, :update_area=>:hugo }
    assert_response :success

    post :list_dml_locks, :params => {:format=>:html }
    assert_response :success


    if sql_select_one("select COUNT(*) from dba_views where view_name='DBA_KGLLOCK' ") > 0      # Nur Testen wenn View auch existiert
      post :list_ddl_locks, :format=>:html;  assert_response :success
    end

    post :list_blocking_dml_locks, :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success

    post :list_sessions, :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success

    post :list_sessions, :params => {:format=>:html, :onlyActive=>1, :showOnlyUser=>1, :instance=>1, :filter=>'hugo', :object_owner=>'SYS', :object_name=>'HUGO', :update_area=>:hugo }
    assert_response :success

    get :list_waits_per_event, :params => {:format=>:html, :event=>"db file sequential read", :instance=>"1", :update_area=>"hugo" }
    assert_response :success

    get  :show_session_detail, :params => {:format=>:html, :instance=>@instance, :sid=>@sid, :serialno=>@serialno, :update_area=>:hugo }
    assert_response :success

    post :show_session_details_waits, :params => {:format=>:html, :instance=>@instance, :sid=>@sid, :serialno=>@serialno, :update_area=>:hugo }
    assert_response :success

    post :show_session_details_locks, :params => {:format=>:html, :instance=>@instance, :sid=>@sid, :serialno=>@serialno, :update_area=>:hugo }
    assert_response :success

    post :show_session_details_temp, :params => {:format=>:html, :instance=>@instance, :sid=>@sid, :serialno=>@serialno, :saddr=>@saddr, :update_area=>:hugo }
    assert_response :success

    post :list_open_cursor_per_session, :params => {:format=>:html, :instance=>@instance, :sid=>@sid, :serialno=>@serialno, :update_area=>:hugo }
    assert_response :success

    post :list_accessed_objects, :params => {:format=>:html, :instance=>@instance, :sid=>@sid, :update_area=>:hugo }
    assert_response :success

    post :list_session_statistic, :params => {:format=>:html, :instance=>@instance, :sid=>@sid, :update_area=>:hugo }
    assert_response :success

    post :list_session_optimizer_environment, :params => {:format=>:html, :instance=>@instance, :sid=>@sid, :update_area=>:hugo }
    assert_response :success

    post :show_session_details_waits_object, :params => {:format=>:html, :event=>"db file sequential read", :update_area=>:hugo }
    assert_response :success

    post  :show_explain_plan, :params => {:format=>:html, :statement => "SELECT SYSDATE FROM DUAL", :update_area=>:hugo }
    assert_response :success

    get  :show_session_waits, :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success
    #test "show_application" do get  :show_application, :applexec_id => "0";  assert_response :success; end
    #test "show_segment_statistics" do get  :show_segment_statistics;  assert_response :success; end

    get  :segment_stat, :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success

#    get :oracle_parameter, :format=>:html
#    assert_response :success
  end




end
