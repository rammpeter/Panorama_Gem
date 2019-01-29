# encoding: utf-8
class LongtermTrendController < ApplicationController
  include LongtermTrendHelper

  def list_longterm_trend
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung
    @instance = prepare_param_instance
    params[:groupfilter] = {}
    params[:groupfilter][:instance]              =  @instance if @instance
    params[:groupfilter][:time_selection_start]  = @time_selection_start
    params[:groupfilter][:time_selection_end]    = @time_selection_end

    params[:groupfilter][:additional_filter]     = params[:filter]  if params[:filter] && params[:filter] != ''

    list_longterm_trend_grouping      # Weiterleiten Request an Standard-Verarbeitung für weiteres DrillDown
  end

  def list_longterm_trend_grouping
    where_from_groupfilter(params[:groupfilter], params[:groupby])

    panorama_sampler_schema = PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema].downcase

    @sessions= PanoramaConnection.sql_select_iterator(["\
      SELECT /*+ ORDERED USE_HASH(u sv f) Panorama-Tool Ramm */
             #{longterm_trend_key_rule(@groupby)[:sql]} Group_Value,
             SUM(t.Seconds_Active)          Seconds_Active,
             COUNT(1)                       Count_Samples,
             #{include_longterm_trend_default_select_list}
      FROM   #{panorama_sampler_schema}.LongTerm_Trend t
      JOIN   #{panorama_sampler_schema}.LTT_Wait_Event    we ON we.ID = t.LTT_Wait_Event_ID
      JOIN   #{panorama_sampler_schema}.LTT_Wait_Class    wc ON wc.ID = t.LTT_Wait_Class_ID
      JOIN   #{panorama_sampler_schema}.LTT_User          u  ON u.ID  = t.LTT_User_ID
      JOIN   #{panorama_sampler_schema}.LTT_Service       s  ON s.ID  = t.LTT_Service_ID
      JOIN   #{panorama_sampler_schema}.LTT_Machine       ma ON ma.ID = t.LTT_Machine_ID
      JOIN   #{panorama_sampler_schema}.LTT_Module        mo ON mo.ID = t.LTT_Module_ID
      JOIN   #{panorama_sampler_schema}.LTT_Action        a  ON a.ID  = t.LTT_Action_ID
      WHERE  1=1
      #{@where_string}
      GROUP BY #{longterm_trend_key_rule(@groupby)[:sql]}
      ORDER BY SUM(t.Seconds_Active) DESC
     "].concat(@where_values)
    )

    render_partial :list_longterm_trend_grouping
  end

  def list_longterm_trend_historic_timeline
    point_group = params[:point_group].to_sym

    time_group_expr = case point_group
                      when :week then 'DAY'
                      when :day then 'DD'
                      when :hour then 'HH24'
                      else raise "Unknown point_group #{point_group}"
                      end

    period_seconds = case point_group
                     when :week then 7 * 86400
                     when :day then 86400
                     when :hour then 3600
                     else raise "Unknown point_group #{point_group}"
                     end



    where_from_groupfilter(params[:groupfilter], params[:groupby])
    panorama_sampler_schema = PanoramaConnection.get_threadlocal_config[:panorama_sampler_schema].downcase

    singles= sql_select_all ["\
      SELECT /*+ ORDERED USE_HASH(u sv f) Panorama-Tool Ramm */
             TRUNC(Snapshot_Timestamp, '#{time_group_expr}') Snapshot_Start,
             NVL(TO_CHAR(#{longterm_trend_key_rule(@groupby)[:sql]}), 'NULL') Criteria,
             SUM(Seconds_Active) / (COUNT(DISTINCT Snapshot_Timestamp) * MAX(Snapshot_Cycle_Hours) * 3600) Diagram_Value
      FROM   #{panorama_sampler_schema}.LongTerm_Trend t
      JOIN   #{panorama_sampler_schema}.LTT_Wait_Event    we ON we.ID = t.LTT_Wait_Event_ID
      JOIN   #{panorama_sampler_schema}.LTT_Wait_Class    wc ON wc.ID = t.LTT_Wait_Class_ID
      JOIN   #{panorama_sampler_schema}.LTT_User          u  ON u.ID  = t.LTT_User_ID
      JOIN   #{panorama_sampler_schema}.LTT_Service       s  ON s.ID  = t.LTT_Service_ID
      JOIN   #{panorama_sampler_schema}.LTT_Machine       ma ON ma.ID = t.LTT_Machine_ID
      JOIN   #{panorama_sampler_schema}.LTT_Module        mo ON mo.ID = t.LTT_Module_ID
      JOIN   #{panorama_sampler_schema}.LTT_Action        a  ON a.ID  = t.LTT_Action_ID
      WHERE  1=1
      #{@where_string}
      GROUP BY TRUNC(Snapshot_Timestamp, '#{time_group_expr}'), #{longterm_trend_key_rule(@groupby)[:sql]}
      ORDER BY 1
     "].concat(@where_values)


    # Anzeige der Filterbedingungen im Caption des Diagrammes
    @filter = ''
    @groupfilter.each do |key, value|
      @filter << "#{groupfilter_value(key)[:name]}=\"#{value}\", " unless groupfilter_value(key)[:hide_content]
    end

    diagram_caption = "Number of waiting sessions condensed by #{point_group} for top-10 grouped by: <b>#{@groupby}</b>, Filter: #{@filter}"

    plot_top_x_diagramm(:data_array         => singles,
                        :time_key_name      => 'snapshot_start',
                        :curve_key_name     => 'criteria',
                        :value_key_name     => 'diagram_value',
                        :top_x              => 10,
                        :caption            => diagram_caption,
                        #:null_points_cycle  => group_seconds,
                        :update_area        => params[:update_area]
    )
  end


  private
  def include_longterm_trend_default_select_list
    # Add pne cycle to duration because last occurrence points to start of last considered cycle
    retval = " MIN(Snapshot_Timestamp)             First_Occurrence,
               MAX(Snapshot_Timestamp)             Last_Occurrence,
               (MAX(Snapshot_Timestamp) - MIN(Snapshot_Timestamp)) * 24 + MAX(Snapshot_Cycle_Hours) Sample_Duration_Hours"

    longterm_trend_key_rules.each do |key, value|
      retval << ",
        COUNT(DISTINCT NVL(TO_CHAR(#{value[:sql]}), ' ')) #{value[:sql_alias]}_Cnt,
        MIN(#{value[:sql]}) #{value[:sql_alias]}"
    end
    retval
  end

  # Ermitteln des SQL für NOT NULL oder NULL
  def groupfilter_value(key, value=nil)
    retval = case key.to_sym
             when :time_selection_start        then {:name => 'Time selection start',        :sql => "t.Snapshot_Timestamp >= TO_DATE(?, '#{sql_datetime_mask(value)}')", :already_bound => true }
             when :time_selection_end          then {:name => 'Time selection end',          :sql => "t.Snapshot_Timestamp <  TO_DATE(?, '#{sql_datetime_mask(value)}')", :already_bound => true }
             when :additional_filter           then {:name => 'Additional Filter',           :sql => "UPPER(we.Name||wc.Name||u.Name||s.Name||ma.Name||mo.Name||a.Name) LIKE UPPER('%'||?||'%')", :already_bound => true }  # Such-Filter
             else                              { name: key, sql: longterm_trend_key_rule(key.to_s)[:sql] }                              # 2. Versuch aus Liste der Gruppierungskriterien
             end

    raise "groupfilter_value: unknown key '#{key}' of class #{key.class.name}" unless retval
    retval = retval.clone                                                       # Entkoppeln von Quelle so dass Änderungen lokal bleiben
    unless retval[:already_bound]                                               # Muss Bindung noch hinzukommen?
      retval[:sql] = "#{retval[:sql]} = ?"
    end

    retval
  end



  # Belegen des WHERE-Statements aus Hash mit Filter-Bedingungen und setzen Variablen
  def where_from_groupfilter (groupfilter, groupby)
    @groupfilter = groupfilter             # Instanzvariablen zur nachfolgenden Nutzung
    @groupfilter = @groupfilter.to_unsafe_h.to_h.symbolize_keys  if @groupfilter.class == ActionController::Parameters
    raise "Parameter groupfilter should be of class Hash or ActionController::Parameters" if @groupfilter.class != Hash
    @groupby    = groupby                  # Instanzvariablen zur nachfolgenden Nutzung
    @where_string  = ""             # Filter-Text für nachfolgendes Statement mit AND-Erweiterung für alle Union-Tabellen
    @where_values = []              # Filter-werte für nachfolgendes Statement für alle Union-Tabellen

    @groupfilter.each do |key,value|
      @groupfilter[key] = value.strip if key == 'time_selection_start' || key == 'time_selection_end'                   # Whitespaces entfernen vom Rand des Zeitstempels
    end

    @groupfilter.each do |key,value|
      sql = groupfilter_value(key, value)[:sql]
      @where_string << " AND #{sql}"
      @where_values << value
    end
  end # where_from_groupfilter


end
