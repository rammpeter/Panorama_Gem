# encoding: utf-8
require 'test_helper'
require 'active_session_history_helper'

class ActiveSessionHistoryControllerTest < ActionController::TestCase
  include ActiveSessionHistoryHelper

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{

      initialize_min_max_snap_id_and_times

      @groupfilter = {
                :DBID            => get_dbid,
                :time_selection_start => @time_selection_start,
                :time_selection_end   => @time_selection_end,
                :Min_Snap_ID     => @min_snap_id,
                :Max_Snap_ID     => @max_snap_id
        }

      sql_row = sql_select_first_row "SELECT SQL_ID, Child_Number, Parsing_Schema_Name FROM v$sql WHERE SQL_Text LIKE '%OBJ$%' AND Object_Status = 'VALID' ORDER BY Executions DESC"
      @hist_sql_id = sql_row.sql_id
      @sga_child_number = sql_row.child_number
      @hist_parsing_schema_name = sql_row.parsing_schema_name
    }
  end

  # Workaround, da t in Test-Klassen nicht bekannt ist
  def t(hook, translate_hash)
    translate_hash[:default]
  end

  # Ermittlung der zum Typ passenden Werte für Bindevariablen
  def bind_value_from_key_rule(key)
    case key
      when "User"         then 'Hugo'
      when "SQL-ID"       then '123456789'
      when "Session/Sn."  then '1,2'
      when "Operation"    then 'FULL SCAN'
      when "Entry-PL/SQL" then 'Hugo<>%&'
      when "PL/SQL"       then 'Hugo<>%&'
      when "Module"       then 'Module1<>%&'
      when 'Modus'        then 'SQL exec'
      when "Action"       then 'Action1<>%&'
      when "Event"        then 'db file sequential read'
      when "Wait-Class"   then 'IO'
      when "DB-Object"    then 'DUAL'
      when "DB-Sub-Object"  then 'DUAL'
      when "Service"      then 'DEFAULT'
      when 'Tablespace'   then 'SYSTEM'
      when "Program"      then 'sqlplus<>%&'
      when "Machine"      then 'ramm.osp-dd.de<>%&'
      when 'PQ'           then '1:2:3'
      when 'Session-Type' then 'F'
      else 2
    end
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end

  test "list_session_statistics_historic with xhr: true" do
    # Iteration über Gruppierungskriterien
    session_statistics_key_rules.each do |groupby, value|
      post :list_session_statistic_historic, :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby, :update_area=>:hugo }
      assert_response_success_or_management_pack_violation('list_session_statistic_historic')

      post :list_session_statistic_historic, :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :groupby=>groupby, :filter=>'sys', :update_area=>:hugo}
      assert_response_success_or_management_pack_violation('list_session_statistic_historic, sys')
    end
  end

  test "list_session_statistic_historic_grouping with xhr: true" do
    # Iteration über Gruppierungskriterien
    session_statistics_key_rules.each do |groupby, value_inner|
      # Test mit realem Wert
      add_filter = {groupby => bind_value_from_key_rule(groupby)}
      post :list_session_statistic_historic_grouping, :params => {:format=>:html, :groupby=>groupby, :groupfilter => @groupfilter.merge(add_filter), :update_area=>:hugo }
      assert_response_success_or_management_pack_violation('list_session_statistic_historic_grouping groupby => value')

      post :list_session_statistic_historic_grouping, :params => {:format=>:html, :groupby=>groupby, :groupfilter => @groupfilter.merge(add_filter).merge(:Additional_Filter=>'sys'), :update_area=>:hugo }
      assert_response_success_or_management_pack_violation('list_session_statistic_historic_grouping groupby => value, sys')

      # Test mit NULL als Filterkriterium
      add_filter = {groupby => nil}
      post :list_session_statistic_historic_grouping, :params => {:format=>:html, :groupby=>groupby, :groupfilter => @groupfilter.merge(add_filter), :update_area=>:hugo }
      assert_response_success_or_management_pack_violation('list_session_statistic_historic_grouping groupby => nil')

      post :list_session_statistic_historic_grouping, :params => {:format=>:html, :groupby=>groupby, :groupfilter => @groupfilter.merge(add_filter).merge(:Additional_Filter=>'sys'), :update_area=>:hugo }
      assert_response_success_or_management_pack_violation('list_session_statistic_historic_grouping groupby => nil, sys')
    end
  end

  test "refresh_time_selection with xhr: true" do
    session_statistics_key_rules.each do |groupby, value|
      post :refresh_time_selection, :params => {:format=>:html, :groupfilter=>@groupfilter, :groupby=>groupby, :repeat_action => :list_session_statistic_historic_grouping, :update_area=>:hugo }
      assert_response_success_or_management_pack_violation('refresh_time_selection')
    end
  end

  test "list_session_statistic_historic_single_record with xhr: true" do
    session_statistics_key_rules.each do |groupby, value|
      add_filter = {groupby => bind_value_from_key_rule(groupby)}
      post :list_session_statistic_historic_single_record, :params => {:format=>:html, :groupby=>groupby,
           :groupfilter=>@groupfilter.merge(add_filter), :update_area=>:hugo }
      assert_response_success_or_management_pack_violation('list_session_statistic_historic_single_record')
    end
  end

  test "list_session_statistics_historic_timeline with xhr: true" do
    session_statistics_key_rules.each do |groupby, value|
      add_filter = {groupby => bind_value_from_key_rule(groupby)}
      post :list_session_statistic_historic_timeline, :params => {:format=>:html, :groupby=>groupby,
           :groupfilter=>@groupfilter.merge(add_filter),
           :top_values => ["1", "2", "3"], :group_seconds=>60, :update_area=>:hugo }
      assert_response_success_or_management_pack_violation('list_session_statistic_historic_timeline')
    end
  end

  test "list_temp_usage_historic with xhr: true" do
    if get_db_version >= "11.2"
      session_statistics_key_rules.each do |outer_filter, value|
        # Iteration über Gruppierungskriterien
        temp_historic_grouping_options.each do |time_groupby, inner_value|
          add_filter = {outer_filter => bind_value_from_key_rule(outer_filter)}
          post :list_temp_usage_historic, :params => {:format=>:html, :time_groupby=>time_groupby, :groupfilter => @groupfilter.merge(add_filter), :update_area=>:hugo }
          assert_response_success_or_management_pack_violation("list_temp_usage_historic outer_filter=#{outer_filter} time_groupby=#{time_groupby}")
        end
      end
    end
  end

  test "list_pga_usage_historic with xhr: true" do
    if get_db_version >= "11.2"
      session_statistics_key_rules.each do |outer_filter, value|
        # Iteration über Gruppierungskriterien
        temp_historic_grouping_options.each do |time_groupby, inner_value|
          add_filter = {outer_filter => bind_value_from_key_rule(outer_filter)}
          post :list_pga_usage_historic, :params => {:format=>:html, :time_groupby=>time_groupby, :groupfilter => @groupfilter.merge(add_filter), :update_area=>:hugo }
          assert_response_success_or_management_pack_violation("list_pga_usage_historic outer_filter=#{outer_filter} time_groupby=#{time_groupby}")
        end
      end
    end
  end

  test "show_prepared_active_session_history with xhr: true" do
    post :show_prepared_active_session_history, :params => {:format=>:html, :instance=>1, :sql_id=>@hist_sql_id }
    assert_response :success
    post :show_prepared_active_session_history, :params => {:format=>:html, :instance=>1, :sid=>@sid }
    assert_response :success
  end

  test "list_prepared_active_session_history with xhr: true" do
    post :list_prepared_active_session_history, :params => {:format=>:html, :groupby=>"SQL-ID",
         :groupfilter => {
                         :DBID     => get_dbid,
                         :Instance => 1,
                         "SQL-ID"  => @hist_sql_id
         },
         :time_selection_start => @time_selection_start,
         :time_selection_end   => @time_selection_end, :update_area=>:hugo }
    assert_response_success_or_management_pack_violation('list_prepared_active_session_history')
  end

  test "blocking_locks_historic with xhr: true" do
    post :list_blocking_locks_historic, :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end }
    assert_response_success_or_management_pack_violation('list_blocking_locks_historic')

    post :list_ash_dependecy_thread, :params => {format: :html, blocking_inst_id: 1, blocking_session: 7379, blocking_session_serial_no: 55500, max_snap_id: 45113, min_snap_id: 45113, sample_time: @time_selection_start, update_area: 'hugo'}
    assert_response_success_or_management_pack_violation('list_ash_dependecy_thread')
  end


end
