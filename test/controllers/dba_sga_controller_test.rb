# encoding: utf-8
require 'test_helper'

class DbaSgaControllerTest < ActionDispatch::IntegrationTest

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context

    initialize_min_max_snap_id_and_times

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

  test "list_sql_detail_execution_plan with xhr: true" do
    post '/dba_sga/list_sql_detail_execution_plan' , params: {format: :html, instance: "1", sql_id: @hist_sql_id, update_area: :hugo }
    assert_response :success
    post '/dba_sga/list_sql_detail_execution_plan' , params: {format: :html, instance: "1", sql_id: @hist_sql_id, child_number: 1, child_address: 'ABC', update_area: :hugo }
    assert_response :success
  end

  test "list_sql_child_cursors with xhr: true" do
    post '/dba_sga/list_sql_child_cursors' , params: {format: :html, instance: '1', sql_id: @hist_sql_id, update_area: :hugo }
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
    assert_response management_pack_license == :none ? :error : :success
  end

  test "list_db_cache_by_object with xhr: true" do
    post '/dba_sga/list_db_cache_by_object', :params => {:format=>:html, owner: 'SYS', object_name: 'OBJ$', :update_area=>:hugo }
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

  test "list_resize_operations_historic with xhr: true" do
    if get_db_version >= "11.1"
      [nil,1].each do |instance|
        historic_resize_grouping_options.each do |time_groupby|
          post :list_resize_operations_historic, params: {format: :html, time_groupby: time_groupby,  time_selection_start: @time_selection_start, time_selection_end: @time_selection_end, instance: instance, update_area: :hugo }
          assert_response_success_or_management_pack_violation("list_resize_operations_historic time_groupby=#{time_groupby}")
        end
      end
    end
  end

end
