# encoding: utf-8
require 'test_helper'
require 'longterm_trend_helper'

class LongtermTrendControllerTest < ActionDispatch::IntegrationTest
  include LongtermTrendHelper

  setup do
    set_session_test_db_context

    initialize_min_max_snap_id_and_times                                        # Ensure that enough records are in DBA_Hist_Active_Sess_History or Panorama_Active_Sess_History

    EngineConfig.config.panorama_sampler_master_password = 'hugo'

    @sampler_config                                  = get_current_database
    @sampler_config[:name]                           = 'Hugo'
    @sampler_config[:password]                       = Encryption.decrypt_value(@sampler_config[:password], cookies['client_salt'])
    @sampler_config[:owner]                          = @sampler_config[:user] # Default

    set_panorama_sampler_config_defaults!(@sampler_config)

    PanoramaSamplerStructureCheck.do_check(@sampler_config, :LONGTERM_TREND);   # assure existence of DB objects

    min_max = PanoramaConnection.sql_select_first_row "SELECT COUNT(*) Records, MIN(Snapshot_Timestamp) Min_TS, MAX(Snapshot_Timestamp) Max_TS FROM #{@sampler_config[:owner]}.Longterm_Trend"

    if min_max.records < 4
      saved_config = Thread.current[:panorama_connection_connect_info]          # store current config before being reset by WorkerThread.create_snapshot_internal
      WorkerThread.new(@sampler_config, 'test_do_sampling_longterm_trend').create_snapshot_internal(Time.now.round, :LONGTERM_TREND) # Tables must be created before snapshot., first snapshot initialization called
      PanoramaConnection.set_connection_info_for_request(saved_config)          # reconnect because create_snapshot_internal freed the connection
      min_max = PanoramaConnection.sql_select_first_row "SELECT COUNT(*) Records, MIN(Snapshot_Timestamp) Min_TS, MAX(Snapshot_Timestamp) Max_TS FROM #{@sampler_config[:owner]}.Longterm_Trend"

      # put some records into
      if min_max.records > 4
        Rails.logger.error "LongtermTrendControllerTest.setup: Only #{min_max.records} records are in table #{@sampler_config[:owner]}.Longterm_Trend. Producing synthetic records now!"
        4.downto(1) do |num|
          sleep 2                                                               # Ensure unique timestamps
          PanoramaConnection.sql_execute "INSERT INTO #{@sampler_config[:owner]}.Longterm_Trend (
                                            Snapshot_Timestamp, Instance_Number, LTT_Wait_Class_ID, LTT_Wait_Event_ID, LTT_User_ID, LTT_Service_ID,
                                            LTT_Machine_ID, LTT_Module_ID, LTT_Action_ID, Seconds_Active, Snapshot_Cycle_Hours
                                          ) VALUES (SYSDATE, 1, 0, 0, 0, 0, 0, 0, 0, 12, 1)"
        end
      end
    end
    @time_selection_start = min_max.min_ts.strftime("%d.%m.%Y %H:%M")
    @time_selection_end   = min_max.max_ts.strftime("%d.%m.%Y %H:%M")

    @groupfilter = {
          :time_selection_start => @time_selection_start,
          :time_selection_end   => @time_selection_end,
    }
  end

  # Ermittlung der zum Typ passenden Werte für Bindevariablen
  def bind_value_from_key_rule(key)
    case key
    when 'Instance'     then 1
    when 'Wait-Event'   then 'ON CPU'
    when 'Wait-Class'   then 'CPU'
    when 'User-Name'    then 'SYS'
    when 'Service-Name' then 'SYS$USERS'
    when 'Machine'      then 'hugo'
    when 'Module'       then 'NULL'
    when 'Action'       then 'NOT SAMPLED'
    else 2
    end
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end

  test "list_longterm_trend with xhr: true" do
    # Iteration über Gruppierungskriterien
    counter = 0
    longterm_trend_key_rules.each do |groupby, value|
      counter += 1
      if counter % 2 == 0                                                       # use alternating attributes
        instance = 1
        filter = 'sys'
      else
        instance = ''
        filter = ''
      end

      post '/longterm_trend/list_longterm_trend', :params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby, instance: instance, filter: filter, :update_area=>:hugo }
      assert_response(:success, "list_longterm_trend #{groupby}")
    end
  end

  test "list_longterm_trend_grouping with xhr: true" do
    counter = 0
    longterm_trend_key_rules.each do |groupby, value_inner|
      counter += 1
      if counter % 2 == 0                                                       # use alternating attributes
        add_filter = {additional_filter: 'sys', Instance: 1}
      else
        add_filter = {}
      end

      # Test mit realem Wert
      add_filter[groupby] = bind_value_from_key_rule(groupby)
      post '/longterm_trend/list_longterm_trend_grouping', :params => {:format=>:html, :groupby=>groupby, :groupfilter => @groupfilter.merge(add_filter), :update_area=>:hugo }
      assert_response(:success, "list_longterm_trend_grouping #{groupby}")

    end
  end

  test "refresh_time_selection with xhr: true" do
    longterm_trend_key_rules.each do |groupby, value|
      post  '/longterm_trend/refresh_time_selection', :params => {:format=>:html, :groupfilter=>@groupfilter, :groupby=>groupby,
                                                                  :repeat_action => :list_longterm_trend_grouping,
                                                                  :update_area=>:hugo }
      assert_response(:success, "list_longterm_trend_grouping #{groupby}")
    end
  end

  test "list_longterm_trend_historic_timeline with xhr: true" do
    longterm_trend_key_rules.each do |groupby, value|
      [:week, :day, :hour].each do |point_group|
        add_filter = {groupby => bind_value_from_key_rule(groupby)}
        post  '/longterm_trend/list_longterm_trend_historic_timeline', :params => {:format=>:html, :groupby=>groupby,
                                                                                   :groupfilter=>@groupfilter.merge(add_filter),
                                                                                   point_group: point_group, :update_area=>:hugo }
        assert_response(:success, "list_longterm_trend_historic_timeline #{groupby}")
      end
    end
  end

  test "list_longterm_trend_single_record with xhr: true" do
    longterm_trend_key_rules.each do |groupby, value|
      add_filter = {groupby => bind_value_from_key_rule(groupby)}
      post  '/longterm_trend/list_longterm_trend_single_record', :params => {:format=>:html,
                                                                       :groupfilter=>@groupfilter.merge(add_filter), :update_area=>:hugo }
      assert_response(:success, "list_longterm_trend_single_record #{groupby}")
    end

    [:single, :hour, :day, :week, :month].each do |time_groupby|
      post  '/longterm_trend/list_longterm_trend_single_record', :params => {:format=>:html,
                                                                             :groupfilter=>@groupfilter, time_groupby: time_groupby, :update_area=>:hugo }
      assert_response(:success, "list_longterm_trend_single_record #{time_groupby}")
    end
  end

end
