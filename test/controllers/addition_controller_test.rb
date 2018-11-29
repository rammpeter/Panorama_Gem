# encoding: utf-8
require 'test_helper'

# Execution of WorkerThreadTest is precondition for successful run (initial table creation must be executed before this test)

class AdditionControllerTest < ActionDispatch::IntegrationTest
  include MenuHelper

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context

    #connect_oracle_db     # Nutzem Oracle-DB für Selektion
    @ttime_selection_end    = Time.new
    @ttime_selection_start  = @ttime_selection_end-10000          # x Sekunden Abstand
    @time_selection_end     = @ttime_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start   = @ttime_selection_start.strftime("%d.%m.%Y %H:%M")
    @gather_date            = @ttime_selection_end.strftime("%d.%m.%Y %H:%M:%S")

    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

    set_current_database(get_current_database.merge( {panorama_sampler_schema: get_current_database[:user]} ))    # Ensure Panorama's tables are serached here
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end

  test "blocking_locks_history with xhr: true" do
    PanoramaSamplerStructureCheck.do_check(prepare_panorama_sampler_thread_db_config, :BLOCKING_LOCKS)         # Ensure that structures are existing

    post '/addition/list_blocking_locks_history', :params => { :format=>:html,
         :time_selection_start =>"01.01.2011 00:00",
         :time_selection_end =>"01.01.2011 01:00",
         :timeslice =>"10",
         :commit_table => "1",
         :update_area=>:hugo } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    post '/addition/list_blocking_locks_history', :params => { :format=>:html,
         :time_selection_start =>"01.01.2011 00:00",
         :time_selection_end =>"01.01.2011 01:00",
         :timeslice =>'10',
         :commit_hierarchy => "1",
         :update_area=>:hugo } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    post '/addition/list_blocking_locks_history_hierarchy_detail', :params => { :format=>:html,
         :blocking_instance => 1,
         :blocking_sid => 1,
         :blocking_serialno => 1,
         :snapshot_timestamp =>"01.01.2011 00:00:00",
         :update_area=>:hugo } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success
  end


  test "db_cache_historic with xhr: true" do
    PanoramaSamplerStructureCheck.do_check(prepare_panorama_sampler_thread_db_config, :CACHE_OBJECTS)         # Ensure that structures are existing

    [nil, 1].each do |instance|
      [nil, 1].each do |show_partitions|
        post '/addition/list_db_cache_historic', :params => { :format               => :html,
                                                              :time_selection_start => "01.01.2011 00:00",
                                                              :time_selection_end   => "01.01.2011 01:00",
                                                              :instance             => instance,
                                                              :maxResultCount       => 100,
                                                              :show_partitions      => show_partitions,
                                                              :update_area          => :hugo } if ENV['DB_VERSION'] >= '11.2'
        assert_response :success
      end

    end

    [nil, 1].each do |show_partitions|
      get '/addition/list_db_cache_historic_detail', :params => { :format               =>:html,
                                                                  :time_selection_start =>"01.01.2011 00:00",
                                                                  :time_selection_end   =>"01.01.2011 01:00",
                                                                  :instance             => 1,
                                                                  :owner                => "sysp",
                                                                  :name                 => "Employee",
                                                                  show_partitions:      show_partitions,
                                                                  partitionname:        show_partitions ? 'PART1' : nil,
                                                                  :update_area          => :hugo  } if ENV['DB_VERSION'] >= '11.2'
      assert_response :success

    end

    [nil, 1].each do |instance|
      [nil, 1].each do |show_partitions|
        post '/addition/list_db_cache_historic_timeline', :params => {  format:               :html,
                                                                        time_selection_start: "01.01.2011 00:00",
                                                                        time_selection_end:   "01.01.2011 01:00",
                                                                        :instance             => instance,
                                                                        :show_partitions      => show_partitions,
                                                                        :update_area          => :hugo } if ENV['DB_VERSION'] >= '11.2'
        assert_response :success

      end
    end

    [nil,1].each do |show_partitions|
      get '/addition/list_db_cache_historic_snap', :params => { :format=>:html,
                                                                :snapshot_timestamp =>"01.01.2011 00:00",
                                                                :instance  => "1",
                                                                show_partitions: show_partitions,
                                                                :update_area=>:hugo } if ENV['DB_VERSION'] >= '11.2'
      assert_response :success
    end

  end

  test "object_increase with xhr: true" do
    PanoramaSamplerStructureCheck.do_check(prepare_panorama_sampler_thread_db_config, :OBJECT_SIZE)         # Ensure that structures are existing

    @sampler_config_entry                                  = get_current_database
    @sampler_config_entry[:owner]                          = @sampler_config_entry[:user] # Default

    # Create test data
    PanoramaSamplerSampling.do_sampling(PanoramaSamplerConfig.new(@sampler_config_entry), @ttime_selection_start, :OBJECT_SIZE)
    PanoramaSamplerSampling.do_sampling(PanoramaSamplerConfig.new(@sampler_config_entry), @ttime_selection_end,   :OBJECT_SIZE)

    [all_dropdown_selector_name, 'SYSTEM'].each do |tablespace|
      [all_dropdown_selector_name, 'SYS'].each do |schema|
        ['Segment_Type', 'Tablespace_Name', 'Owner'].each do |gruppierung_tag|
          [{:detail=>1}, {:timeline=>1}].each do |submit_tag|
            post '/addition/list_object_increase',  {:params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end,
                                                                  :tablespace=>{"name"=>tablespace}, "schema"=>{"name"=>schema}, :gruppierung=>{"tag"=>gruppierung_tag}, :update_area=>:hugo }.merge(submit_tag)
            }
            assert_response :success

            if submit_tag[:timeline] == 1                                       # subdialog called only for timelime
              post '/addition/list_object_increase_objects_per_time',  {:params => { :format=>:html, gather_date: @gather_date, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end,
                                                                    Tablespace_Name: tablespace, Owner: schema, gruppierung_tag => 'Hugo', :update_area=>:hugo }.merge(submit_tag)
              }
              assert_response :success
            end
          end
        end
      end
    end

    get '/addition/show_object_increase',  :params => {:format=>:html}    if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    get '/addition/list_object_increase_object_timeline', :params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :owner=>'Hugo', :name=>'Hugo', :update_area=>:hugo  }
    assert_response :success
  end

  test "exec_worksheet_sql with xhr: true" do
    post '/addition/exec_worksheet_sql', params: {format: :html, sql_statement: 'SELECT SYSDATE FROM DUAL', update_area: :hugo }
    assert_response :success
  end

  test "explain_worksheet_sql with xhr: true" do
    post '/addition/explain_worksheet_sql', params: {format: :html, sql_statement: 'SELECT SYSDATE FROM DUAL', update_area: :hugo }
    assert_response :success
  end


end
