# encoding: utf-8
require 'test_helper'

class DbaSgaControllerTest < ActionDispatch::IntegrationTest

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context

    # TODO: Additional test with overlapping start and end (first snapshot after start and last snapshot before end)
    # End with latest existing sample
    time_selection_end = sql_select_one "SELECT /* Panorama-Tool Ramm */ MAX(Begin_Interval_Time) FROM DBA_Hist_Snapshot"
    #time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

    @topSort = ["ElapsedTimePerExecute",
               "ElapsedTimeTotal",
               "ExecutionCount",
               "RowsProcessed",
               "ExecsPerDisk",
               "BufferGetsPerRow",
               "CPUTime",
               "BufferGets",
               "ClusterWaits"
    ]

    sql_row = sql_select_first_row "SELECT SQL_ID, Child_Number, Parsing_Schema_Name FROM v$sql WHERE SQL_Text LIKE '%OBJ$%' AND Object_Status = 'VALID' ORDER BY Executions DESC"
    @hist_sql_id = sql_row.sql_id
    @sga_child_number = sql_row.child_number
    @hist_parsing_schema_name = sql_row.parsing_schema_name

    @object_id = sql_select_one "SELECT Object_ID FROM DBA_Objects WHERE Object_Name = 'OBJ$'"
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end


  test "show_application_info with xhr: true" do
    get '/dba_sga/show_application_info', :params => {:format=>:html, :moduletext=>"Application = 128", :update_area=>:hugo }
    assert_response :success
  end

  test "list_sql_area_sql_id with xhr: true" do
    @topSort.each do |ts|
      post '/dba_sga/list_sql_area_sql_id', :params => {:format=>:html, :maxResultCount=>"100", :topSort=>ts, :update_area=>:hugo }
      assert_response :success

      post '/dba_sga/list_sql_area_sql_id', :params => {:format=>:html, :maxResultCount=>"100", :instance=>"1", :topSort=>ts, :update_area=>:hugo }
      assert_response :success

      post '/dba_sga/list_sql_area_sql_id', :params => {:format=>:html, :maxResultCount=>"100", :instance=>"1", :username=>'hugo', :sql_id=>"", :topSort=>ts, :update_area=>:hugo }
      assert_response :success

      post '/dba_sga/list_sql_area_sql_id', :params => {:format=>:html, :maxResultCount=>"100", :instance=>"1", :sql_id=>"", :topSort=>ts, :update_area=>:hugo }
      assert_response :success
    end
  end

  test "list_sql_area_sql_id_childno with xhr: true" do
    @topSort.each do |ts|
      post '/dba_sga/list_sql_area_sql_id_childno', :params => {:format=>:html, :maxResultCount=>"100", :topSort=>ts, :update_area=>:hugo }
      assert_response :success

      post '/dba_sga/list_sql_area_sql_id_childno', :params => {:format=>:html, :maxResultCount=>"100", :instance=>"1", :topSort=>ts, :update_area=>:hugo }
      assert_response :success

      post '/dba_sga/list_sql_area_sql_id_childno', :params => {:format=>:html, :maxResultCount=>"100", :instance=>"", :username=>'hugo', :topSort=>ts, :update_area=>:hugo }
      assert_response :success

      post '/dba_sga/list_sql_area_sql_id_childno', :params => {:format=>:html, :maxResultCount=>"100", :instance=>"", :username=>'hugo', :sql_id=>"", :topSort=>ts, :update_area=>:hugo }
      assert_response :success
    end
  end

  test "list_sql_detail_sql_id_childno with xhr: true" do
    get '/dba_sga/list_sql_detail_sql_id_childno', :params => {:format=>:html, :instance => "1", :sql_id => @hist_sql_id, child_number: @sga_child_number, :update_area=>:hugo  }
    assert_response :success
  end

  test "list_sql_detail_sql_id with xhr: true" do
    get  '/dba_sga/list_sql_detail_sql_id' , :params => {:format=>:html, :instance => "1", :sql_id => @hist_sql_id, :update_area=>:hugo }
    assert_response :success

    get  '/dba_sga/list_sql_detail_sql_id' , :params => {:format=>:html, :sql_id => @hist_sql_id, :update_area=>:hugo }
    assert_response :success

    post '/dba_sga/list_sql_profile_detail', :params => {:format=>:html, :profile_name=>'Hugo', :update_area=>:hugo }
    assert_response :success

  end

  test "list_bind_variables_per_sql with xhr: true" do
    post '/dba_sga/list_bind_variables', :params => {format: :html, instance: 1, sql_id: @hist_sql_id, update_area: :hugo }
    assert_response :success

    post '/dba_sga/list_bind_variables', :params => {format: :html, instance: 1, sql_id: @hist_sql_id, child_number: 0, child_address: 'ABC', update_area: :hugo }
    assert_response :success
  end


  test "list_open_cursor_per_sql with xhr: true" do
    get '/dba_sga/list_open_cursor_per_sql', :params => {:format=>:html, :instance=>1, :sql_id => @hist_sql_id, :update_area=>:hugo }
    assert_response :success
  end

  test "list_sga_components with xhr: true" do
    post '/dba_sga/list_sga_components', :params => {:format=>:html, :instance=>1, :update_area=>:hugo }
    assert_response :success

    post '/dba_sga/list_sga_components', :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success

    post '/dba_sga/list_sql_area_memory', :params => {:format=>:html, :instance=>1, :update_area=>:hugo }
    assert_response :success

    post '/dba_sga/list_object_cache_detail', :params => {:format=>:html, :instance=>1, :type=>"CURSOR", :namespace=>"SQL AREA", :db_link=>"", :kept=>"NO", :order_by=>"sharable_mem", :update_area=>:hugo }
    assert_response :success

    post '/dba_sga/list_object_cache_detail', :params => {:format=>:html, :instance=>1, :type=>"CURSOR", :namespace=>"SQL AREA", :db_link=>"", :kept=>"NO", :order_by=>"record_count", :update_area=>:hugo }
    assert_response :success

  end

  test "list_db_cache_content with xhr: true" do
    post '/dba_sga/list_db_cache_content', :params => {:format=>:html, :instance=>1, :update_area=>:hugo }
    assert_response :success
  end

  test "show_using_sqls with xhr: true" do
    get '/dba_sga/show_using_sqls', :params => {:format=>:html, :ObjectName=>"gv$sql", :update_area=>:hugo }
    assert_response :success
  end

  test "list_cursor_memory with xhr: true" do
    get '/dba_sga/list_cursor_memory', :params => {:format=>:html, :instance=>1, :sql_id=>@hist_sql_id, :update_area=>:hugo }
    assert_response :success
  end

  test "compare_execution_plans with xhr: true" do
    post '/dba_sga/list_compare_execution_plans', :params => {:format=>:html, :instance_1=>1, :sql_id_1=>@hist_sql_id, :child_number_1 =>@sga_child_number, :instance_2=>1, :sql_id_2=>@hist_sql_id, :child_number_2 =>@sga_child_number, :update_area=>:hugo }
    assert_response :success
  end

  test "list_result_cache with xhr: true" do
    post '/dba_sga/list_result_cache', :params => {:format=>:html, :instance=>1, :update_area=>:hugo }
    assert_response :success
    post '/dba_sga/list_result_cache', :params => {:format=>:html, :update_area=>:hugo }
    assert_response :success

    if get_db_version >= '11.2'
      get '/dba_sga/list_result_cache_single_results', :params => {:format=>:html, :instance=>1, :status=>'Published', :name=>'Hugo', :namespace=>'PLSQL', :update_area=>:hugo }
      assert_response :success
    end

    get '/dba_sga/list_result_cache_dependencies_by_id', :params => {:format=>:html, :instance=>1, :id=>100, :status=>'Published', :name=>'Hugo', :namespace=>'PLSQL', :update_area=>:hugo }
    assert_response :success

    get '/dba_sga/list_result_cache_dependencies_by_name', :params => {:format=>:html, :instance=>1, :status=>'Published', :name=>'Hugo', :namespace=>'PLSQL', :update_area=>:hugo }
    assert_response :success

    get '/dba_sga/list_result_cache_dependents', :params => {:format=>:html, :instance=>1, :id=>100, :status=>'Published', :name=>'Hugo', :namespace=>'PLSQL', :update_area=>:hugo }
    assert_response :success
  end

  test "list_db_cache_advice_historic with xhr: true" do
    post '/dba_sga/list_db_cache_advice_historic', :params => {:format=>:html, :instance=>1, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :update_area=>:hugo }
    assert_response :success
  end

  test "list_db_cache_by_object_id with xhr: true" do
    post '/dba_sga/list_db_cache_by_object_id', :params => {:format=>:html, :object_id=>@object_id, :update_area=>:hugo }
    assert_response :success
  end

  test "plan_management with xhr: true" do
    post '/dba_sga/list_sql_profile_sqltext', :params => {:format=>:html, :profile_name=>'Hugo', :update_area=>:hugo }
    assert_response :success

    post '/dba_sga/list_sql_plan_baseline_sqltext', :params => {:format=>:html, :plan_name=>'Hugo', :update_area=>:hugo }
    assert_response :success

    if get_db_version >= '12.1'
      [nil, @hist_sql_id].each do |translation_sql_id|
        post '/dba_sga/show_sql_translations', :params => {:format=>:html, :translation_sql_id=>translation_sql_id, :update_area=>:hugo }
        assert_response :success
      end
    end
  end

  test "generate_sql_translation with xhr: true" do
    if get_db_version >= '12.1'
      [:SGA, :AWR].each do |location|
        [nil, true].each do |fixed_user|
          post '/dba_sga/show_sql_translations', :params => {:format      => :html,
                                                   :location    => location,
                                                   :sql_id      => @hist_sql_id,
                                                   :user_name   => @hist_parsing_schema_name,
                                                   :fixed_user  => fixed_user,
                                                   :update_area => :hugo
          }
          assert_response :success
        end
      end
    end
  end

  test "generate_sql_patch with xhr: true" do
    if get_db_version >= '12.1'
      post '/dba_sga/generate_sql_patch', :params => {format: :html, sql_id: @hist_sql_id, update_area: :hugo }
      assert_response :success
    end
  end

  test "list_sql_monitor with xhr: true" do
    begin

      sql_montitor_data = sql_select_first_row "SELECT Inst_ID, SID, Session_Serial# SerialNo, SQL_ID, SQL_Exec_ID
                                                FROM gv$SQL_Monitor
                                                ORDER BY Last_Refresh_Time DESC"

      if sql_montitor_data.nil?
        Rails.logger.info "Test list_sql_monitor: no data found from gv$SQL_Monitor, test terminated"
      else
        post '/dba_sga/list_sql_monitor', :params => {format:       :html,
                                                      instance:     sql_montitor_data.inst_id,
                                                      sid:          sql_montitor_data.sid,
                                                      serialno:     sql_montitor_data.serialno,
                                                      sql_id:       sql_montitor_data.sql_id,
                                                      sql_exec_id:  sql_montitor_data.sql_exec_id,
        }
        assert_response :success
      end
    rescue PopupMessageException
      # each request without :diagnostics_and_tuning_pack should result in PopupMessageException
      if get_current_database[:management_pack_license] == :diagnostics_and_tuning_pack
        raise "#{self.class} test list_sql_monitor: PopupMessageException catched for get_current_database[:management_pack_license] == :diagnostics_and_tuning_pack"
      end
    end
  end

  test "list_sql_monitor_sessions with xhr :true" do
    begin
      # call render or start_sql_monitor_in_new_window depending from result count
  #    ["COUNT(*) = 1", "COUNT(*) > 1"].each do |having|    # "COUNT(*) = 1 causes redirect via browser which does not function in test environment
      ["COUNT(*) > 1"].each do |having|
        sql_montitor_data = sql_select_first_row "SELECT Inst_ID, SID, Session_Serial# SerialNo, SQL_ID, SQL_Plan_Hash_Value
                                                  FROM   gv$SQL_Monitor
                                                  WHERE  DECODE(Process_Name, 'ora', 1, 0) = 1
                                                  GROUP BY Inst_ID, SID, Session_Serial#, SQL_ID, SQL_Plan_Hash_Value
                                                  HAVING #{having}
                                                  ORDER BY MAX(Last_Refresh_Time) DESC"

        if sql_montitor_data.nil?
          Rails.logger.info "Test list_sql_monitor_sessions: no data found from gv$SQL_Monitor, test terminated"
        else
          post '/dba_sga/list_sql_monitor_sessions', :params => {format:          :html,
                                                                 instance:        sql_montitor_data.inst_id,
                                                                 sid:             sql_montitor_data.sid,
                                                                 serialno:        sql_montitor_data.serialno,
                                                                 sql_id:          sql_montitor_data.sql_id,
                                                                 plan_hash_value: sql_montitor_data.sql_plan_hash_value,
          }
          assert_response :success
        end
      end
    rescue PopupMessageException
      # each request without :diagnostics_and_tuning_pack should result in PopupMessageException
      if get_current_database[:management_pack_license] == :diagnostics_and_tuning_pack
        raise "#{self.class} test list_sql_monitor: PopupMessageException catched for get_current_database[:management_pack_license] == :diagnostics_and_tuning_pack"
      end
    end
  end


end
