# encoding: utf-8
require 'test_helper'

class DbaHistoryControllerTest < ActionController::TestCase

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{}

    #time_selection_end  = Time.new
    # TODO: Additional test with overlapping start and end (first snapshot after start and last snapshot before end)
    # End with latest existing sample
    time_selection_end = sql_select_one "SELECT /* Panorama-Tool Ramm */ MAX(Begin_Interval_Time) FROM DBA_Hist_Snapshot"
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")
    @min_snap_id = sql_select_one ["SELECT  /* Panorama-Tool Ramm */ MIN(Snap_ID)
                                   FROM    DBA_Hist_Snapshot
                                   WHERE   Begin_Interval_Time >= ?", time_selection_start ]
    raise "No snapshot found after #{time_selection_start}" if @min_snap_id.nil?

    @max_snap_id = sql_select_one ["SELECT  /* Panorama-Tool Ramm */ MAX(Snap_ID)
                                   FROM    DBA_Hist_Snapshot
                                   WHERE   Begin_Interval_Time <= ?", time_selection_end ]
    raise "No snapshot found before #{time_selection_end}" if @max_snap_id.nil?
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end


  test "segment_stat_historic with xhr: true" do
    post :list_segment_stat_historic_sum, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :update_area=>:hugo }
    assert_response :success
    post :list_segment_stat_historic_sum, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1, :update_area=>:hugo }
    assert_response :success

    post :list_segment_stat_hist_detail, :params => {:format=>:html, :instance=>1, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :owner=>'sys', :object_name=>'SEG$', :update_area=>:hugo }
    assert_response :success

    post :list_segment_stat_hist_sql, :params => {:format=>:html, :instance=>1,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :owner =>"sys", :object_name=> "all_tables", :update_area=>:hugo }
    assert_response :success
  end



  test "sql_area_historic with xhr: true" do
    ['ElapsedTimePerExecute',
     'ElapsedTimeTotal',
     'ExecutionCount',
     'RowsProcessed',
     'ExecsPerDisk',
     'BufferGetsPerRow',
     'CPUTime',
     'BufferGets',
     'ClusterWaits'
    ].each do |topSort|
      post :list_sql_area_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :maxResultCount=>100, :topSort=>topSort, :update_area=>:hugo }
      assert_response :success

      post :list_sql_area_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :maxResultCount=>100, :topSort=>topSort, :sql_id=>'14147ß1471', :update_area=>:hugo }
      assert_response :success

      post :list_sql_area_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :maxResultCount=>100, :topSort=>topSort, :filter=>'hugo<>%&', :update_area=>:hugo }
      assert_response :success

      post :list_sql_area_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :maxResultCount=>100, :topSort=>topSort, :instance=>1, :update_area=>:hugo }
      assert_response :success
    end

    post :list_sql_detail_historic, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :sql_id=>@sga_sql_id, :update_area=>:hugo }
     assert_response :success

    post :list_sql_detail_historic, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :sql_id=>@sga_sql_id, :instance=>1, :update_area=>:hugo }
    assert_response :success

    post :list_sql_detail_historic, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :sql_id=>@sga_sql_id, :parsing_schema_name=>@sga_parsing_schema_name, :update_area=>:hugo }
    assert_response :success

    post :list_sql_history_snapshots, :params => {:format=>:html, :sql_id=>@sga_sql_id, :instance=>1, :parsing_schema_name=>@sga_parsing_schema_name, :groupby=>:day, :update_area=>:hugo}
    assert_response :success
    post :list_sql_history_snapshots, :params => {:format=>:html, :sql_id=>@sga_sql_id, :instance=>1, :parsing_schema_name=>@sga_parsing_schema_name,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :update_area=>:hugo }
    assert_response :success

    post :list_sql_historic_execution_plan, :params => {:format=>:html, :sql_id=>@sga_sql_id, :instance=>1, :parsing_schema_name=>@sga_parsing_schema_name,
                                                        :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :update_area=>:hugo }
    assert_response :success
  end


  test "show_using_sqls_historic with xhr: true" do
    post :show_using_sqls_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
                                    :ObjectName => "WRH$_sysmetric_history", :update_area=>:hugo }
    assert_response :success
  end

  test "list_system_events_historic with xhr: true" do
    post :list_system_events_historic, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :instance=>1, :update_area=>:hugo }
     assert_response :success
  end

  test "list_system_events_historic_detail with xhr: true" do
    post :list_system_events_historic_detail, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
         :instance=>1, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :event_id=>1, :event_name=>"Hugo", :update_area=>:hugo }
     assert_response :success
     assert_response :success
  end

  test "list_system_statistics_historic with xhr: true" do
    post :list_system_statistics_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :stat_class=> {:bit => 1}, :instance=>1, :sum=>1, :update_area=>:hugo }
    assert_response :success
    post :list_system_statistics_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :stat_class=> {:bit => 1}, :instance=>1, :full=>1, :verdichtung=>{:tag =>"MI"}, :update_area=>:hugo }
    assert_response :success
    post :list_system_statistics_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :stat_class=> {:bit => 1}, :instance=>1, :full=>1, :verdichtung=>{:tag =>"HH24"}, :update_area=>:hugo }
    assert_response :success
    post :list_system_statistics_historic, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :stat_class=> {:bit => 1}, :instance=>1, :full=>1, :verdichtung=>{:tag =>"DD"}, :update_area=>:hugo }
    assert_response :success
  end

  test "list_system_statistics_historic_detail with xhr: true" do
    post :list_system_statistics_historic_detail, :params => {:format=>:html,  :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1,
         :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id, :stat_id=>1, :stat_name=>"Hugo", :update_area=>:hugo }
    assert_response :success
  end

  test "list_sysmetric_historic with xhr: true" do
    # Evtl. als sysdba auf Test-DB Table loeschen wenn noetig: truncate table sys.WRH$_SYSMETRIC_HISTORY;

    if get_current_database[:host] == "ramm.osp-dd.de"                              # Nur auf DB ausführen wo Test-User ein ALTER-Grant auf sys.WRH$_SYSMETRIC_HISTORY hat
      puts "Prepare for Test: Executing ALTER INDEX sys.WRH$_SYSMETRIC_HISTORY_INDEX shrink space"
      ActiveRecord::Base.connection.execute("ALTER INDEX sys.WRH$_SYSMETRIC_HISTORY_INDEX shrink space");
    end

   ['SS', 'MI', 'HH24', 'DD'].each do |grouping|
     # Zeitabstand deutlich kuerzer fuer diesen Test
     time_selection_end  = Time.new
     time_selection_start  = time_selection_end-80          # x Sekunden Abstand
     time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
     time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

     post :list_sysmetric_historic, :params => {:format=>:html,  :time_selection_start =>time_selection_start, :time_selection_end =>time_selection_end, :detail=>1, :grouping=>{:tag =>grouping}, :update_area=>:hugo }
     assert_response :success
     post :list_sysmetric_historic, :params => {:format=>:html,  :time_selection_start =>time_selection_start, :time_selection_end =>time_selection_end, :instance=>1, :detail=>1, :grouping=>{:tag =>grouping}, :update_area=>:hugo }
     assert_response :success
     post :list_sysmetric_historic, :params => {:format=>:html,  :time_selection_start =>time_selection_start, :time_selection_end =>time_selection_end, :summary=>1, :grouping=>{:tag =>grouping}, :update_area=>:hugo }
     assert_response :success
     post :list_sysmetric_historic, :params => {:format=>:html,  :time_selection_start =>time_selection_start, :time_selection_end =>time_selection_end, :instance=>1, :summary=>1, :grouping=>{:tag =>grouping}, :update_area=>:hugo }
     assert_response :success
   end
  end

  test "mutex_statistics_historic with xhr: true" do
    [:Blocker, :Waiter, :Timeline].each do |submit_name|
      post :list_mutex_statistics_historic, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1, submit_name=>"Hugo", :update_area=>:hugo }
      assert_response :success
      post :list_mutex_statistics_historic, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, submit_name=>"Hugo", :update_area=>:hugo }
      assert_response :success
    end

    get :list_mutex_statistics_historic_samples, :params => {:format=>:html, :instance=>1, :mutex_type=>:Hugo, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
        :filter=>:Blocking_Session, :filter_session=>@sid, :update_area=>:hugo }
    assert_response :success

    get :list_mutex_statistics_historic_samples, :params => {:format=>:html, :instance=>1, :mutex_type=>:Hugo, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end,
        :filter=>:Requesting_Session, :filter_session=>@sid, :update_area=>:hugo }
    assert_response :success
  end

  test "latch_statistics_historic with xhr: true" do
    post :list_latch_statistics_historic, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1 }
    assert_response :success

    post :list_latch_statistics_historic_details, :params => {:format=>:html, :instance=>1, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id,
         :latch_hash => 12313123, :latch_name=>"Hugo" }
    assert_response :success
  end

  test "enqueue_statistics_historic with xhr: true" do
    post :list_enqueue_statistics_historic, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_start, :instance=>1 }
    assert_response :success

    post :list_enqueue_statistics_historic_details, :params => {:format=>:html, :instance=>1, :min_snap_id=>@min_snap_id, :max_snap_id=>@max_snap_id,
         :eventno => 12313123, :reason=>"Hugo", :description=>"Hugo" }
    assert_response :success
  end

  test "list_compare_sql_area_historic with xhr: true" do
    tag1 = Time.new
    post :list_compare_sql_area_historic, :params => {:format=>:html, :instance=>1, :filter=>"Hugo", :sql_id=>@sga_sql_id, :minProzDiff=>50,
         :tag1=> tag1.strftime("%d.%m.%Y"), :tag2=>(tag1-86400).strftime("%d.%m.%Y") }
    assert_response :success
  end

  test "genuine_oracle_reports with xhr: true" do
    post :list_awr_report_html, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1 }
    assert_response :success

    post :list_awr_global_report_html, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end }
    assert_response :success

    post :list_awr_global_report_html, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1 }
    assert_response :success

    post :list_ash_report_html, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1 }
    assert_response :success

    post :list_ash_global_report_html, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end }
    assert_response :success

    post :list_ash_global_report_html, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1 }
    assert_response :success

    post :list_awr_sql_report_html, :params => {:format=>:html, :time_selection_start =>@time_selection_start, :time_selection_end =>@time_selection_end, :instance=>1, :sql_id=>@sga_sql_id }
    assert_response :success
  end



end
