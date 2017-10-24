# encoding: utf-8
require 'test_helper'


class AdditionControllerTest < ActionDispatch::IntegrationTest
  include MenuHelper

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{}

    showBlockingLocksMenu                                                       # Set cache with owner-schema for table
    #connect_oracle_db     # Nutzem Oracle-DB für Selektion
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end

  test "blocking_locks_history with xhr: true" do
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
         :snapshotts =>"01.01.2011 00:00:00",
         :update_area=>:hugo } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success
  end


  test "db_cache_historic with xhr: true" do
    post '/addition/list_db_cache_historic', :params => { :format=>:html,
         :time_selection_start =>"01.01.2011 00:00",
         :time_selection_end =>"01.01.2011 01:00",
         :instance  => "1",
         :maxResultCount => 100,
         :update_area=>:hugo } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    get '/addition/list_db_cache_historic_detail', :params => { :format=>:html,
        :time_selection_start =>"01.01.2011 00:00",
        :time_selection_end =>"01.01.2011 01:00",
        :instance  => 1,
        :owner     => "sysp",
        :name      => "Employee",
        :update_area=>:hugo  } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success

    get '/addition/list_db_cache_historic_snap', :params => { :format=>:html,
        :snapshotts =>"01.01.2011 00:00",
        :instance  => "1",
        :update_area=>:hugo } if ENV['DB_VERSION'] >= '11.2'
    assert_response :success
  end

  test "object_increase with xhr: true" do
    get '/addition/show_object_increase',  :params => {:format=>:html}    if ENV['DB_VERSION'] >= '11.2'
    assert_response :success
  end

  test "list_object_increase with xhr: true" do
    @sampler_config_entry                                  = get_current_database
    @sampler_config_entry[:owner]                          = @sampler_config_entry[:user] # Default

    # Create test data
    PanoramaSamplerSampling.do_object_size_sampling(@sampler_config_entry, @time_selection_start)
    PanoramaSamplerSampling.do_object_size_sampling(@sampler_config_entry, @time_selection_end)

    if showObjectIncrease                                                     # Nur Testen wenn Tabelle(n) auch existieren
      ['Segment_Type', 'Tablespace_Name', 'Owner'].each do |gruppierung_tag|
        [{:detail=>1}, {:timeline=>1}].each do |submit_tag|
          post '/addition/list_object_increase',  {:params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end,
                                        :tablespace=>{"name"=>all_dropdown_selector_name}, "schema"=>{"name"=>all_dropdown_selector_name}, :gruppierung=>{"tag"=>gruppierung_tag}, :update_area=>:hugo }.merge(submit_tag)
          }
          assert_response :success

          post '/addition/list_object_increase',  {:params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end,
                                        :tablespace=>{"name"=>'USERS'}, "schema"=>{"name"=>all_dropdown_selector_name}, :gruppierung=>{"tag"=>gruppierung_tag}, :update_area=>:hugo }.merge(submit_tag)
          }
          assert_response :success

          post '/addition/list_object_increase',  {:params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end,
                                        :tablespace=>{"name"=>all_dropdown_selector_name}, "schema"=>{"name"=>'SYS'}, :gruppierung=>{"tag"=>gruppierung_tag}, :update_area=>:hugo }.merge(submit_tag)
          }
          assert_response :success
        end
      end
    end
  end

  test "object_increase_timeline with xhr: true" do
    get '/addition/list_object_increase_object_timeline', :params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :owner=>'Hugo', :name=>'Hugo', :update_area=>:hugo  }
    assert_response :success
  end


end
