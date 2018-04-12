# encoding: utf-8
require 'test_helper'
include ActionView::Helpers::TranslationHelper
#include ActionDispatch::Http::URL

class DbaControllerTest < ActionController::TestCase

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context

    initialize_min_max_snap_id_and_times

    @DBA_KGLLOCK_exists = sql_select_one("select COUNT(*) from dba_views where view_name='DBA_KGLLOCK' ")
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end


  test "redologs with xhr: true"       do
    get  :show_redologs, :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success

    post  :show_redologs, :params => {:format=>:html, :update_area=>:hugo, instance: 1 }
    assert_response :success

    post :list_redologs_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :update_area=>:hugo }
    assert_response management_pack_license == :none ? :error : :success
    post :list_redologs_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1, :update_area=>:hugo }
    assert_response management_pack_license == :none ? :error : :success
  end

  test "locks with xhr: true"       do
    post :list_dml_locks, :params => {:format=>:html }
    assert_response :success

    if @DBA_KGLLOCK_exists > 0      # Nur Testen wenn View auch existiert
      post :list_ddl_locks, :format=>:html;  assert_response :success
    end

    post :list_blocking_dml_locks, :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success
  end

  test "list_sessions with xhr: true" do
    post :list_sessions, :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success

    post :list_sessions, :params => {:format=>:html, :onlyActive=>1, :showOnlyUser=>1, :instance=>1, :filter=>'hugo', :object_owner=>'SYS', :object_name=>'HUGO', :update_area=>:hugo }
    assert_response :success
  end

  test "show_session_detail with xhr: true" do
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
  end

  test "show_session_waits with xhr: true" do
    get  :show_session_waits, :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success
    #test "show_application" do get  :show_application, :applexec_id => "0";  assert_response :success; end
    #test "show_segment_statistics" do get  :show_segment_statistics;  assert_response :success; end
  end

    test "list_waits_per_event with xhr: true" do
    get :list_waits_per_event, :params => {:format=>:html, :event=>"db file sequential read", :instance=>"1", :update_area=>"hugo" }
    assert_response :success
  end

  test "show_explain_plan with xhr: true"       do
    post  :show_explain_plan, :params => {:format=>:html, :statement => "SELECT SYSDATE FROM DUAL", :update_area=>:hugo }
    assert_response :success
  end

  test "segment_stat with xhr: true"       do
    get  :segment_stat, :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success
  end

  test "list_server_logs with xhr: true" do
    ['SS', 'MI', 'HH24', 'DD'].each do |tag|
      ['all', 'tnslsnr', 'rdbms', 'asm'].each do |log_type|
        [:group, :detail].each do |button|
          [nil, 'hugo'].each do |incl_filter|
            [nil, 'hugo'].each do |excl_filter|
              post :list_server_logs, :params => {format:               :html,
                                                  time_selection_start: @time_selection_start,
                                                  time_selection_end:   @time_selection_end,
                                                  log_type:             log_type,
                                                  verdichtung:          {tag: tag},
                                                  button                => 'hugo',
                                                  incl_filter:          incl_filter,
                                                  excl_filter:          excl_filter,
                                                  :update_area          => :hugo
              }
              assert_response :success
            end
          end
        end
      end
    end
  end

  test 'show_rowid_details with xhr: true' do

    # Readable table with primary key and records
    data_object = sql_select_first_row "SELECT o.Data_Object_ID, t.Owner, t.Table_Name
                                        FROM   All_Tables t
                                        JOIN   All_Constraints c ON c.Owner = t.Owner AND c.Table_Name = t.Table_Name AND c.Constraint_Type = 'P'
                                        JOIN   DBA_Objects o ON o.Owner = t.Owner AND o.Object_Name = t.Table_Name
                                        WHERE  t.Cluster_Name IS NULL
                                        AND    t.IOT_Name IS NULL
                                        AND    t.Table_Name NOT LIKE '%$%'
                                        AND    t.Num_Rows > 0
                                        AND    o.Data_Object_ID IS NOT NULL
                                        AND    RowNum < 2
                                        "

    raise "No readable table with num_rows > 0 found in database" if data_object.nil?

    waitingforrowid = sql_select_one "SELECT RowIDTOChar(RowID) FROM #{data_object.owner}.#{data_object.table_name} WHERE RowNum < 2"

    post :show_rowid_details, :params => {format: :html, data_object_id: data_object.data_object_id, waitingforrowid: waitingforrowid, update_area: :hugo }
    assert_response :success

  end

end
