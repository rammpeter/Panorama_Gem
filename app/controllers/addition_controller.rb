# encoding: utf-8
# Zusatzfunktionen, die auf speziellen Tabellen und Prozessen aufsetzen, die nicht prinzipiell in DB vorhanden sind
class AdditionController < ApplicationController
  include AdditionHelper

  def list_db_cache_historic
    max_result_count = params[:maxResultCount]
    @instance = prepare_param_instance
    @show_partitions = params[:show_partitions]
    save_session_time_selection                  # Werte puffern fuer spaetere Wiederverwendung

    if @show_partitions == '1'
      partition_expression = "Partition_Name"
    else
      partition_expression = "NULL"
    end

    @entries= sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */ *
      FROM   (SELECT Instance_Number, Owner, Name, Partition_Name,
                     AVG(Blocks_Total) AvgBlocksTotal,
                     MIN(Blocks_Total) MinBlocksTotal,
                     Max(Blocks_Total) MaxBlocksTotal,
                     SUM(Blocks_Total) SumBlocksTotal,
                     AVG(Blocks_Dirty) AvgBlocksDirty,
                     MIN(Blocks_Dirty) MinBlocksDirty,
                     MAX(Blocks_Dirty) MaxBlocksDirty,
                     COUNT(*)         Samples,
                     AVG(Sum_Total_per_Snapshot) Sum_Total_per_Snapshot
              FROM   (SELECT Instance_Number, Owner, Name, #{partition_expression} Partition_Name,
                             SUM(Blocks_Total)            Blocks_Total,
                             SUM(Blocks_Dirty)            Blocks_Dirty,
                             MIN(Sum_Total_per_Snapshot)  Sum_Total_per_Snapshot /* Always the same per group condition */
                      FROM   (SELECT o.*,
                                     SUM(Blocks_Total) OVER (PARTITION BY Snapshot_Timestamp) Sum_Total_per_Snapshot
                              FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Cache_Objects o
                              WHERE  Snapshot_Timestamp BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
                              #{" AND Instance_Number=#{@instance}" if @instance}
                             )
                      -- Verdichten je Schnappschuss auf Gruppierung, um saubere Min/Max/Avg-Werte zu erhalten
                      GROUP BY Snapshot_Timestamp, Instance_Number, Owner, Name, #{partition_expression}
                     )
              GROUP BY Instance_Number, Owner, Name, Partition_Name
              ORDER BY SUM(Blocks_Total) DESC
             )
      WHERE RowNum <= ?",
                              @time_selection_start, @time_selection_end, max_result_count
                             ]

    render_partial
  end

  def list_db_cache_historic_detail
    @instance = prepare_param_instance
    @time_selection_start     = params[:time_selection_start]
    @time_selection_end       = params[:time_selection_end]
    @owner           = params[:owner]
    @name            = params[:name]
    @partitionname   = params[:partitionname]
    @partitionname   = nil if @partitionname == ''
    @show_partitions = params[:show_partitions]

    @entries= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ Snapshot_Timestamp,
             SUM(Blocks_Total) Blocks_Total,
             SUM(Blocks_Dirty) Blocks_Dirty,
             MIN(Sum_Total_per_Snapshot) Sum_Total_per_Snapshot
      FROM   (
              SELECT o.*,
                     SUM(Blocks_Total) OVER (PARTITION BY Snapshot_Timestamp) Sum_Total_per_Snapshot
              FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Cache_Objects o
              WHERE  Snapshot_Timestamp BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
              AND    Instance_Number  = ?
             )
      WHERE  Owner            = ?
      AND    Name             = ?
      #{" AND Partition_Name = ?" if @partitionname}
      GROUP BY Snapshot_Timestamp
      ORDER BY Snapshot_Timestamp
      "].concat([@time_selection_start, @time_selection_end, @instance, @owner, @name].concat(@partitionname ? [@partitionname] : [])
                             )

    render_partial
  end


  def list_db_cache_historic_snap
    @instance           = prepare_param_instance
    @snapshot_timestamp = params[:snapshot_timestamp]
    @show_partitions    = params[:show_partitions]

    if @show_partitions == '1'
      partition_expression = "Partition_Name"
    else
      partition_expression = "NULL"
    end

    @entries= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ Owner, Name, #{partition_expression} Partition_Name,
             SUM(Blocks_Total) Blocks_Total,
             SUM(Blocks_Dirty) Blocks_Dirty,
             MIN(Sum_Total_per_Snapshot) Sum_Total_per_Snapshot
      FROM   (SELECT o.*,
                     SUM(Blocks_Total) OVER (PARTITION BY Snapshot_Timestamp) Sum_Total_per_Snapshot
              FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Cache_Objects o
              WHERE  Snapshot_Timestamp = TO_DATE(?, '#{sql_datetime_second_mask}')
              AND    Instance_Number   = ?
             )
      GROUP BY Snapshot_Timestamp, Instance_Number, Owner, Name, #{partition_expression}
      ORDER BY Blocks_Total DESC
      ", @snapshot_timestamp, @instance]

    render_partial
  end

  def list_db_cache_historic_timeline
    @instance = prepare_param_instance
    @show_partitions = params[:show_partitions]
    @time_selection_start     = params[:time_selection_start]
    @time_selection_end       = params[:time_selection_end]

    if @show_partitions == '1'
      partition_expression = "c.Partition_Name"
    else
      partition_expression = "NULL"
    end

    singles = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             c.Instance_Number, c.Snapshot_Timestamp, c.Owner, c.Name, #{partition_expression} Partition_Name, SUM(c.Blocks_Total) Blocks_Total
      FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Cache_Objects c
      JOIN   (
              SELECT Instance_Number, Owner, Name, Partition_Name, SumBlocksTotal
              FROM   (SELECT Instance_Number, Owner, Name, Partition_Name,
                             Max(Blocks_Total) MaxBlocksTotal,
                             SUM(Blocks_Total) SumBlocksTotal
                      FROM   (SELECT Instance_Number, Owner, Name, #{partition_expression} Partition_Name,
                                     SUM(Blocks_Total) Blocks_Total
                              FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Cache_Objects c
                              WHERE  Snapshot_Timestamp BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
                              #{" AND Instance_Number=#{@instance}" if @instance}
                              -- Verdichten je Schnappschuss auf Gruppierung, um saubere Min/Max/Avg-Werte zu erhalten
                              GROUP BY Snapshot_Timestamp, Instance_Number, Owner, Name, #{partition_expression}
                             )
                      GROUP BY Instance_Number, Owner, Name, Partition_Name
                      ORDER BY Max(Blocks_Total) DESC
                     )
              WHERE RowNum <= 10
             ) s ON s.Instance_Number = c.Instance_Number AND s.Owner = c.Owner AND s.Name||s.Partition_Name = c.Name||#{partition_expression}
      WHERE  c.Snapshot_Timestamp BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
      #{" AND c.Instance_Number=#{@instance}" if @instance}
      GROUP BY c.Instance_Number, c.SnapShot_Timestamp, c.Owner, c.Name, #{partition_expression}
      ORDER BY c.Snapshot_Timestamp, MIN(s.SumBlocksTotal) DESC
      ",
                              @time_selection_start, @time_selection_end, @time_selection_start, @time_selection_end,
                             ]

    @snapshots = []           # Result-Array
    headers={}               # Spalten
    record = {}
    singles.each do |s|     # Iteration über einzelwerte
      record[:snapshot_timestamp] = s.snapshot_timestamp unless record[:snapshot_timestamp] # Gruppenwechsel-Kriterium mit erstem Record initialisisieren
      if record[:snapshot_timestamp] != s.snapshot_timestamp
        @snapshots << record
        record = {}
        record[:snapshot_timestamp] = s.snapshot_timestamp
      end
      colname = "#{"(#{s.instance_number}) " unless @instance}#{s.owner}.#{s.name} #{"(#{s.partition_name})" if s.partition_name}"
      record[colname] = s.blocks_total
      headers[colname] = true    # Merken, dass Spalte verwendet
    end
    @snapshots << record if singles.length > 0    # Letzten Record in Array schreiben wenn Daten vorhanden

    # Alle nicht belegten Werte mit 0 initialisieren
    @snapshots.each do |s|
      headers.each do |key, value|              # Initialisieren aller Werte zum Zeitpunkt mit 0, falls kein Sample existiert
        s[key] = 0 unless s[key]
      end
    end



    # JavaScript-Array aufbauen mit Daten
    output = ""
    output << "jQuery(function($){"
    output << "var data_array = ["
    headers.each do |key, value|
      output << "  { label: '#{key}',"
      output << "    data: ["
      @snapshots.each do |s|
        output << "[#{milliSec1970(s[:snapshot_timestamp])}, #{s[key]}],"
      end
      output << "    ]"
      output << "  },"
    end
    output << "];"

    diagram_caption = "Top 10 Objekte im DB-Cache von #{@time_selection_start} bis #{@time_selection_end} #{"Instance=#{@instance}" if @instance}"

    unique_id = get_unique_area_id
    plot_area_id = "plot_area_#{unique_id}"
    output << "plot_diagram('#{unique_id}', '#{plot_area_id}', '#{diagram_caption}', data_array, {plot_diagram: {locale: '#{get_locale}'}, yaxis: { min: 0 } });"
    output << "});"

    html="
      <div id='#{plot_area_id}'></div>
      <script type='test/javascript'>
        #{ output}
      </script>
      ".html_safe

    respond_to do |format|
      format.html {render :html => html }
    end
  end # list_db_cache_historic_timeline



  private

  def blocking_locks_groupfilter_values(key)

    retval = {
        "Snapshot_Timestamp" => {:sql => "l.Snapshot_Timestamp =TO_DATE(?, '#{sql_datetime_second_mask}')", :already_bound => true },
        "Min_Zeitstempel"   => {:sql => "l.Snapshot_Timestamp>=TO_DATE(?, '#{sql_datetime_second_mask}')", :already_bound => true  },
        "Max_Zeitstempel"   => {:sql => "l.Snapshot_Timestamp<=TO_DATE(?, '#{sql_datetime_second_mask}')", :already_bound => true  },
        "Instance"          => {:sql => "l.Instance_Number" },
        "SID"               => {:sql => "l.SID"},
        "SerialNo"          => {:sql => "l.SerialNo"},
        "Hide_Non_Blocking" => {:sql => "NVL(l.Blocking_SID, '0') != ?", :already_bound => true },
        "Blocking Object"   => {:sql => "LOWER(l.Blocking_Object_Owner)||'.'||l.Blocking_Object_Name" },
        "SQL-ID"            => {:sql => "l.SQL_ID"},
        "Module"            => {:sql => "l.Module"},
        "Objectname"        => {:sql => "l.Object_Name"},
        "Locktype"          => {:sql => "l.Lock_Type"},
        "Request"           => {:sql => "l.Request"},
        "LockMode"          => {:sql => "l.Lock_Mode"},
        "RowID"             => {:sql => "CAST(l.blocking_rowid AS VARCHAR2(18))"},
        "B.Instance"        => {:sql => 'l.blocking_Instance_Number'},
        "B.SID"             => {:sql => 'l.blocking_SID'},
        "B.SQL-ID"          => {:sql => 'l.blocking_SQL_ID'},
    }[key.to_s]
    raise "blocking_locks_groupfilter_values: unknown key '#{key}' of class #{key.class}" unless retval
    retval
  end


  # Belegen des WHERE-Statements aus Hash mit Filter-Bedingungen und setzen Variablen
  def where_from_blocking_locks_groupfilter (groupfilter, groupkey)
    @groupfilter = groupfilter
    @groupfilter = @groupfilter.to_unsafe_h.to_h.symbolize_keys  if @groupfilter.class == ActionController::Parameters
    raise "Parameter groupfilter should be of class Hash or ActionController::Parameters" if @groupfilter.class != Hash
    @groupkey    = groupkey
    @where_string  = ""                    # Filter-Text für nachfolgendes Statement mit AND-Erweiterung
    @where_values = []    # Filter-werte für nachfolgendes Statement

    @groupfilter.each {|key,value|
      sql = blocking_locks_groupfilter_values(key)[:sql].clone

      unless blocking_locks_groupfilter_values(key)[:already_bound]
        if value && value != ''
          sql << " = ?"
        else
          sql << " IS NULL"
        end
      end

      @where_string << " AND #{sql}"
      # Wert nur binden wenn nicht im :sql auf NULL getestet wird
      @where_values << value if value && value != ''
    }

  end

  public


  def list_blocking_locks_history
    save_session_time_selection                   # Werte puffern fuer spaetere Wiederverwendung
    @timeslice = params[:timeslice]

    # Sprungverteiler nach diversen commit-Buttons
    list_blocking_locks_history_sum       if params[:commit_table]
    list_blocking_locks_history_hierarchy if params[:commit_hierarchy]

  end

  def list_blocking_locks_history_sum
    # Initiale Belegung des Groupfilters, wird dann immer weiter gegeben
    groupfilter = {}

    unless params[:show_non_blocking]     # non-Blocking filtern
      groupfilter = {"Hide_Non_Blocking" => '0' }
    end

    where_from_blocking_locks_groupfilter(groupfilter, nil)


    @locks= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             MIN(Snapshot_Timestamp)      Min_Snapshot_Timestamp,
             MAX(Snapshot_Timestamp)      Max_Snapshot_Timestamp,
             SUM(Seconds_In_Wait) Seconds_in_Wait,
             COUNT(*)             Samples,
             CASE WHEN COUNT(DISTINCT Instance_Number) = 1 THEN TO_CHAR(MIN(Instance_Number)) ELSE '< '||COUNT(DISTINCT Instance_Number)||' >' END Instance_Number,
             CASE WHEN COUNT(DISTINCT SID)             = 1 THEN TO_CHAR(MIN(SID))             ELSE '< '||COUNT(DISTINCT SID)            ||' >' END SID,
             CASE WHEN COUNT(DISTINCT SQL_ID)          = 1 THEN TO_CHAR(MIN(SQL_ID))          ELSE '< '||COUNT(DISTINCT SQL_ID)         ||' >' END SQL_ID,
             CASE WHEN COUNT(DISTINCT SerialNo)        = 1 THEN TO_CHAR(MIN(SerialNo))        ELSE '< '||COUNT(DISTINCT SerialNo)       ||' >' END SerialNo,
             CASE WHEN COUNT(DISTINCT Module)          = 1 THEN TO_CHAR(MIN(Module))          ELSE '< '||COUNT(DISTINCT Module)         ||' >' END Module,
             CASE WHEN COUNT(DISTINCT Object_name)     = 1 THEN TO_CHAR(MIN(Object_Name))     ELSE '< '||COUNT(DISTINCT Object_Name)    ||' >' END Object_Name,
             CASE WHEN COUNT(DISTINCT Lock_Type)       = 1 THEN TO_CHAR(MIN(Lock_Type))       ELSE '< '||COUNT(DISTINCT Lock_Type)      ||' >' END Lock_Type,
             CASE WHEN COUNT(DISTINCT Request)         = 1 THEN TO_CHAR(MIN(Request))         ELSE '< '||COUNT(DISTINCT Request)        ||' >' END Request,
             CASE WHEN COUNT(DISTINCT Lock_Mode)       = 1 THEN TO_CHAR(MIN(Lock_Mode))       ELSE '< '||COUNT(DISTINCT Lock_Mode)      ||' >' END Lock_Mode,
             CASE WHEN COUNT(DISTINCT Blocking_Object_Owner||'.'||Blocking_Object_Name) = 1 THEN TO_CHAR(MIN(LOWER(Blocking_Object_Owner)||'.'||Blocking_Object_Name))        ELSE '< '||COUNT(DISTINCT Blocking_Object_Owner||'.'||Blocking_Object_Name)||' >' END Blocking_Object,
             CASE WHEN COUNT(DISTINCT Blocking_RowID)  = 1 THEN CAST(MIN(Blocking_RowID) AS VARCHAR2(18)) ELSE '< '||COUNT(DISTINCT Blocking_RowID) ||' >' END Blocking_RowID,
             CASE WHEN COUNT(DISTINCT Blocking_Instance_Number) = 1 THEN TO_CHAR(MIN(Blocking_Instance_Number)) ELSE '< '||COUNT(DISTINCT Blocking_Instance_Number)||' >' END Blocking_Instance_Number,
             CASE WHEN COUNT(DISTINCT Blocking_SID)    = 1 THEN TO_CHAR(MIN(Blocking_SID))    ELSE '< '||COUNT(DISTINCT Blocking_SID)   ||' >' END Blocking_SID,
             CASE WHEN COUNT(DISTINCT Blocking_SerialNo)=1 THEN TO_CHAR(MIN(Blocking_SerialNo))ELSE '< '||COUNT(DISTINCT Blocking_SerialNo)||' >' END Blocking_SerialNo,
             CASE WHEN COUNT(DISTINCT Blocking_SQL_ID) = 1 THEN TO_CHAR(MIN(Blocking_SQL_ID)) ELSE '< '||COUNT(DISTINCT Blocking_SQL_ID)||' >' END Blocking_SQL_ID
      FROM   (SELECT l.*,
                     (TO_CHAR(Snapshot_Timestamp,'J') * 24 + TO_CHAR(Snapshot_Timestamp, 'HH24')) * 60 + TO_CHAR(Snapshot_Timestamp, 'MI') Minutes
              FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Blocking_Locks l
              WHERE  Snapshot_Timestamp BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
              #{@where_string}
             )
      GROUP BY TRUNC(Minutes/ #{@timeslice})
      ORDER BY 1",
                            @time_selection_start, @time_selection_end].concat(@where_values)

    render_partial :list_blocking_locks_history_sum
  end

  # Anzeige Blocker/Blocking Kaskaden, Einstiegsschirm / 1. Seite mit Root-Blockern
  def list_blocking_locks_history_hierarchy
    @locks= sql_select_all ["\
     WITH /* Panorama-Tool Ramm */
           TSSel AS (SELECT /*+ NO_MERGE */ *
                      FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Blocking_Locks l
                      WHERE  l.Snapshot_Timestamp BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
                      AND    l.Blocking_SID IS NOT NULL  -- keine langdauernden Locks beruecksichtigen
                      AND    l.Request != 0              -- nur Records beruecksichtigen, die wirklich auf Lock warten
                    )
      SELECT Root_Snapshot_Timestamp, Root_Blocking_Instance_Number, Root_Blocking_SID, Root_Blocking_SerialNo,
             COUNT(DISTINCT SID) Blocked_Sessions_Total,
             COUNT(DISTINCT CASE WHEN cLevel=1 THEN SID ELSE NULL END) Blocked_Sessions_Direct,
             SUM(Seconds_In_Wait)                                      Seconds_in_wait_Total,
             CASE WHEN COUNT(DISTINCT Root_Blocking_Object_Owner||Root_Blocking_Object_Name) > 1 THEN   -- Nur anzeigen wenn eindeutig
               '< '||COUNT(DISTINCT Root_Blocking_Object_Owner||Root_Blocking_Object_Name)||' >'
             ELSE
               MIN(Root_Blocking_Object_Owner||'.'||
                 CASE
                   WHEN Root_Blocking_Object_Name LIKE 'SYS_LOB%%' THEN
                     Root_Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Root_Blocking_Object_Name, 8, 10)) )||')'
                   WHEN Root_Blocking_Object_Name LIKE 'SYS_IL%%' THEN
                    Root_Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Root_Blocking_Object_Name, 7, 10)) )||')'
                   ELSE Root_Blocking_Object_Name
                 END)
             END Root_Blocking_Object,
             CASE WHEN COUNT(DISTINCT Root_Blocking_RowID) > 1 THEN   -- Nur anzeigen wenn eindeutig
               '< '||COUNT(DISTINCT Root_Blocking_ROWID)||' >'
             ELSE
               MIN(CAST(Root_Blocking_RowID AS VARCHAR2(18)))
             END Root_Blocking_RowID,
             Root_Blocking_SQL_ID, Root_Blocking_SQL_Child_Number, Root_Blocking_Prev_SQL_ID, Root_Block_Prev_Child_Number,
             CASE WHEN COUNT(DISTINCT Root_Wait_For_PK_Column_Name) > 1 THEN   -- Nur anzeigen wenn eindeutig
               '< '||COUNT(DISTINCT Root_Wait_For_PK_Column_Name)||' >'
             ELSE
               MIN(Root_Wait_For_PK_Column_Name)
             END Root_Wait_For_PK_Column_Name,
             CASE WHEN COUNT(DISTINCT Root_Waiting_For_PK_Value) > 1 THEN   -- Nur anzeigen wenn eindeutig
               '< '||COUNT(DISTINCT Root_Waiting_For_PK_Value)||' >'
             ELSE
               MIN(Root_Waiting_For_PK_Value)
             END Root_Waiting_For_PK_Value,
             Root_Blocking_Status, Root_Blocking_Client_Info,
             Root_Blocking_Module, Root_Blocking_Action, Root_Blocking_User_Name, Root_Blocking_Machine, Root_Blocking_OS_User,
             Root_Blocking_Process, Root_Blocking_Program,
             NULL Blocking_App_Desc
      FROM   (
              SELECT CONNECT_BY_ROOT Snapshot_Timestamp       Root_Snapshot_Timestamp,
                     CONNECT_BY_ROOT Blocking_Instance_Number Root_Blocking_Instance_Number,
                     CONNECT_BY_ROOT Blocking_SID             Root_Blocking_SID,
                     CONNECT_BY_ROOT Blocking_SerialNo        Root_Blocking_SerialNo,
                     CONNECT_BY_ROOT Blocking_Object_Owner    Root_Blocking_Object_Owner,
                     CONNECT_BY_ROOT Blocking_Object_Name     Root_Blocking_Object_Name,
                     CONNECT_BY_ROOT Blocking_RowID           Root_Blocking_RowID,
                     CONNECT_BY_ROOT Blocking_SQL_ID          Root_Blocking_SQL_ID,
                     CONNECT_BY_ROOT Blocking_SQL_Child_Number Root_Blocking_SQL_Child_Number,
                     CONNECT_BY_ROOT Blocking_Prev_SQL_ID     Root_Blocking_Prev_SQL_ID,
                     CONNECT_BY_ROOT Blocking_Prev_Child_Number Root_Block_Prev_Child_Number,
                     CONNECT_BY_ROOT Waiting_For_PK_Column_Name Root_Wait_For_PK_Column_Name,
                     CONNECT_BY_ROOT Waiting_For_PK_Value     Root_Waiting_For_PK_Value,
                     CONNECT_BY_ROOT Blocking_Status          Root_Blocking_Status,
                     CONNECT_BY_ROOT Blocking_Client_Info     Root_Blocking_Client_Info,
                     CONNECT_BY_ROOT Blocking_Module          Root_Blocking_Module,
                     CONNECT_BY_ROOT Blocking_Action          Root_Blocking_Action,
                     CONNECT_BY_ROOT Blocking_User_Name       Root_Blocking_User_Name,
                     CONNECT_BY_ROOT Blocking_Machine         Root_Blocking_Machine,
                     CONNECT_BY_ROOT Blocking_OS_User         Root_Blocking_OS_User,
                     CONNECT_BY_ROOT Blocking_Process         Root_Blocking_Process,
                     CONNECT_BY_ROOT Blocking_Program         Root_Blocking_Program,
                     l.*,
                     Level cLevel
              FROM   TSSel l
              CONNECT BY NOCYCLE PRIOR Snapshot_Timestamp   = Snapshot_Timestamp
                     AND PRIOR sid                          = blocking_sid
                     AND PRIOR instance_number              = blocking_instance_number
                     AND PRIOR serialno                     = blocking_serialNo
             ) l

      WHERE NOT EXISTS (SELECT 1 FROM TSSel i -- Nur die Knoten ohne Parent-Blocker darstellen
                        WHERE  i.Snapshot_Timestamp = l.Snapshot_Timestamp
                        AND    i.Instance_Number    = l.Root_Blocking_Instance_Number
                        AND    i.SID                = l.Root_Blocking_SID
                        AND    i.SerialNo           = l.Root_Blocking_SerialNo
                       )
      GROUP BY Root_Snapshot_Timestamp, Root_Blocking_Instance_Number, Root_Blocking_SID, Root_Blocking_SerialNo,
               Root_Blocking_SQL_ID, Root_Blocking_SQL_Child_Number, Root_Blocking_Prev_SQL_ID, Root_Block_Prev_Child_Number,
               Root_Blocking_Status, Root_Blocking_Client_Info,
               Root_Blocking_Module, Root_Blocking_Action, Root_Blocking_User_Name, Root_Blocking_Machine, Root_Blocking_OS_User,
             Root_Blocking_Process, Root_Blocking_Program
      ORDER BY SUM(Seconds_In_Wait) DESC",
                            @time_selection_start, @time_selection_end]

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.blocking_app_desc =  explain_application_info(l.root_blocking_module)
    }

    render_partial :list_blocking_locks_history_hierarchy
  end

  # Anzeige durch Blocking Locks gelockter Sessions in 2. und weiteren Hierarchie-Ebene
  def list_blocking_locks_history_hierarchy_detail
    @snapshot_timestamp = params[:snapshot_timestamp]
    @blocking_instance  = params[:blocking_instance]
    @blocking_sid       = params[:blocking_sid]
    @blocking_serialno  = params[:blocking_serialno]

    @locks= sql_select_all ["\
      WITH TSel AS (SELECT /*+ NO_MERGE */ *
                    FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Blocking_Locks l
                    WHERE  l.Snapshot_Timestamp = TO_DATE(?, '#{sql_datetime_second_mask}')
                   )
      SELECT o.Instance_Number, o.Sid, o.SerialNo, o.Seconds_In_Wait, o.SQL_ID, o.SQL_Child_Number,
             o.Prev_SQL_ID, o.Prev_Child_Number, o.Status, o.Client_Info, o.Module, o.Action, o.user_name, o.program,
             o.machine, o.os_user, o.process,
             CASE
               WHEN Object_Name LIKE 'SYS_LOB%%' THEN
                 Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Object_Name, 8, 10)) )||')'
               WHEN Object_Name LIKE 'SYS_IL%%' THEN
                Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Object_Name, 7, 10)) )||')'
               ELSE Object_Name
             END Object_Name,
             o.Lock_Type, o.ID1, o.ID2, o.request, o.lock_mode, o.Blocking_Object_Owner, o.Blocking_Object_Name,
             CAST(o.Blocking_RowID AS VARCHAR2(18)) Blocking_RowID, o.Waiting_For_PK_Column_Name, o.Waiting_For_PK_Value,
             NULL Waiting_App_Desc,
             cs.*,
             (SELECT COUNT(*) FROM TSel li
              WHERE li.Instance_Number=o.Instance_Number AND li.SID=o.SID AND li.SerialNo=o.SerialNo
             ) Samples
      FROM   TSel o
      JOIN   (-- Alle gelockten Sessions incl. mittelbare
              SELECT Root_Instance_Number, Root_SID, Root_SerialNo,
                     COUNT(DISTINCT CASE WHEN cLevel>1 THEN SID ELSE NULL END) Blocked_Sessions_Total,
                     COUNT(DISTINCT CASE WHEN cLevel=2 THEN SID ELSE NULL END) Blocked_Sessions_Direct,
                     SUM(CASE WHEN CLevel>1 THEN Seconds_In_Wait ELSE 0 END ) Seconds_in_Wait_Blocked_Total
              FROM   (SELECT CONNECT_BY_ROOT Instance_Number Root_Instance_Number,
                             CONNECT_BY_ROOT SID             Root_SID,
                             CONNECT_BY_ROOT SerialNo        Root_SerialNo,
                             LEVEL cLevel,
                             l.*
                      FROM   tSel l
                      WHERE  l.Request != 0              -- nur Records beruecksichtigen, die wirklich auf Lock warten
                      CONNECT BY NOCYCLE PRIOR Snapshot_Timestamp = Snapshot_Timestamp
                                     AND PRIOR sid                = blocking_sid
                                     AND PRIOR instance_number    = blocking_instance_number
                                     AND PRIOR serialno           = blocking_serialNo
                      START WITH Blocking_Instance_Number=? AND Blocking_SID=? AND Blocking_SerialNo=?
                     )
              GROUP BY Root_Instance_Number, Root_SID, Root_SerialNo
             ) cs ON cs.Root_Instance_Number = o.Instance_Number AND cs.Root_SID = o.SID AND cs.Root_SerialNo = o.SerialNo
      WHERE  o.Blocking_Instance_Number = ?
      AND    o.Blocking_SID             = ?
      AND    o.Blocking_SerialNo        = ?
      AND    o.Request != 0              -- nur Records beruecksichtigen, die wirklich auf Lock warten
      ORDER BY o.Seconds_In_Wait+cs.Seconds_In_Wait_Blocked_Total DESC",
                            @snapshot_timestamp, @blocking_instance, @blocking_sid, @blocking_serialno, @blocking_instance, @blocking_sid, @blocking_serialno]

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.waiting_app_desc = explain_application_info(l.module)
    }

    render_partial
  end

  def list_blocking_locks_history_single_record
    where_from_blocking_locks_groupfilter(params[:groupfilter], nil)

    @locks= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             Snapshot_Timestamp,
             Instance_Number,
             SID,         SerialNo,
             SQL_ID,      SQL_Child_Number,
             Prev_SQL_ID, Prev_Child_Number,
             Status,
             Client_Info, Module, Action,
             CASE
               WHEN Object_Name LIKE 'SYS_LOB%%' THEN
                 Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Object_Name, 8, 10)) )||')'
               WHEN Object_Name LIKE 'SYS_IL%%' THEN
                Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Object_Name, 7, 10)) )||')'
               ELSE Object_Name
             END Object_Name,
             User_Name, Machine, OS_User, Process, Program,
             Lock_Type, Seconds_In_Wait, ID1, ID2, Request, Lock_Mode,
             LOWER(Blocking_Object_Owner) Blocking_Object_Owner,
             CASE
               WHEN Blocking_Object_Name LIKE 'SYS_LOB%%' THEN
                 Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Blocking_Object_Name, 8, 10)) )||')'
               WHEN Blocking_Object_Name LIKE 'SYS_IL%%' THEN
                Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Blocking_Object_Name, 7, 10)) )||')'
               ELSE Blocking_Object_Name
             END Blocking_Object_Name,
             CAST(Blocking_RowID AS VARCHAR2(18)) Blocking_RowID,
             Waiting_For_PK_Column_Name, Waiting_For_PK_Value,
             Blocking_Instance_Number, Blocking_SID, Blocking_SerialNo,
             Blocking_SQL_ID, Blocking_SQL_Child_Number,
             Blocking_Prev_SQL_ID, Blocking_Prev_Child_Number,
             Blocking_Status,
             Blocking_Client_Info, Blocking_Module, Blocking_Action,
             Blocking_User_Name, Blocking_Machine, Blocking_OS_User, Blocking_Process, Blocking_Program,
             NULL Waiting_App_Desc,
             NULL Blocking_App_Desc
      FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Blocking_Locks l
      WHERE  1 = 1 -- Dummy um nachfolgend mit AND fortzusetzen
      #{@where_string}
      ORDER BY Snapshot_Timestamp"].concat(@where_values)

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.waiting_app_desc = explain_application_info(l.module)
      l.blocking_app_desc = explain_application_info(l.blocking_module)
    }


    render_partial
  end

  def list_blocking_locks_history_grouping
    where_from_blocking_locks_groupfilter(params[:groupfilter], params[:groupkey])

    @locks= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             #{blocking_locks_groupfilter_values(@groupkey)[:sql]}   Group_Value,
             MIN(Snapshot_Timestamp)      Min_Snapshot_Timestamp,
             MAX(Snapshot_Timestamp)      Max_Snapshot_Timestamp,
             SUM(Seconds_In_Wait) Seconds_in_Wait,
             COUNT(*)             Samples,
             CASE WHEN COUNT(DISTINCT Instance_Number) = 1 THEN TO_CHAR(MIN(Instance_Number)) ELSE '< '||COUNT(DISTINCT Instance_Number)||' >' END Instance_Number,
             CASE WHEN COUNT(DISTINCT SID)             = 1 THEN TO_CHAR(MIN(SID))             ELSE '< '||COUNT(DISTINCT SID)            ||' >' END SID,
             CASE WHEN COUNT(DISTINCT SerialNo)        = 1 THEN TO_CHAR(MIN(SerialNo))        ELSE '< '||COUNT(DISTINCT SerialNo)       ||' >' END SerialNo,
             CASE WHEN COUNT(DISTINCT SQL_ID)          = 1 THEN TO_CHAR(MIN(SQL_ID))          ELSE '< '||COUNT(DISTINCT SQL_ID)         ||' >' END SQL_ID,
             CASE WHEN COUNT(DISTINCT SQL_Child_Number)= 1 THEN TO_CHAR(MIN(SQL_Child_Number))ELSE '< '||COUNT(DISTINCT SQL_Child_Number)||' >' END SQL_Child_Number,
             CASE WHEN COUNT(DISTINCT Module)          = 1 THEN TO_CHAR(MIN(Module))          ELSE '< '||COUNT(DISTINCT Module)         ||' >' END Module,
             CASE WHEN COUNT(DISTINCT Object_Name)     = 1 THEN TO_CHAR(MIN(Object_Name))     ELSE '< '||COUNT(DISTINCT Object_Name)    ||' >' END Object_Name,
             CASE WHEN COUNT(DISTINCT Lock_Type)       = 1 THEN TO_CHAR(MIN(Lock_Type))       ELSE '< '||COUNT(DISTINCT Lock_Type)      ||' >' END Lock_Type,
             CASE WHEN COUNT(DISTINCT Request)         = 1 THEN TO_CHAR(MIN(Request))         ELSE '< '||COUNT(DISTINCT Request)        ||' >' END Request,
             CASE WHEN COUNT(DISTINCT Lock_Mode)       = 1 THEN TO_CHAR(MIN(Lock_Mode))       ELSE '< '||COUNT(DISTINCT Lock_Mode)      ||' >' END Lock_Mode,
             CASE WHEN COUNT(DISTINCT Blocking_Object_Owner||'.'||Blocking_Object_Name) = 1 THEN TO_CHAR(MIN(LOWER(Blocking_Object_Owner)||'.'||Blocking_Object_Name))        ELSE '< '||COUNT(DISTINCT Blocking_Object_Owner||'.'||Blocking_Object_Name)||' >' END Blocking_Object,
             CASE WHEN COUNT(DISTINCT Blocking_RowID)  = 1 THEN CAST(MIN(Blocking_RowID) AS VARCHAR2(18)) ELSE '< '||COUNT(DISTINCT Blocking_RowID) ||' >' END Blocking_RowID,
             CASE WHEN COUNT(DISTINCT Blocking_Instance_Number) = 1 THEN TO_CHAR(MIN(Blocking_Instance_Number)) ELSE '< '||COUNT(DISTINCT Blocking_Instance_Number)||' >' END Blocking_Instance_Number,
             CASE WHEN COUNT(DISTINCT Blocking_SID)    = 1 THEN TO_CHAR(MIN(Blocking_SID))    ELSE '< '||COUNT(DISTINCT Blocking_SID)   ||' >' END Blocking_SID,
             CASE WHEN COUNT(DISTINCT Blocking_SerialNo)=1 THEN TO_CHAR(MIN(Blocking_SerialNo))ELSE '< '||COUNT(DISTINCT Blocking_SerialNo)||' >' END Blocking_SerialNo,
             CASE WHEN COUNT(DISTINCT Blocking_SQL_ID) = 1 THEN TO_CHAR(MIN(Blocking_SQL_ID)) ELSE '< '||COUNT(DISTINCT Blocking_SQL_ID)||' >' END Blocking_SQL_ID,
             CASE WHEN COUNT(DISTINCT Blocking_SQL_Child_Number)= 1 THEN TO_CHAR(MIN(Blocking_SQL_Child_Number))ELSE '< '||COUNT(DISTINCT Blocking_SQL_Child_Number)||' >' END Blocking_SQL_Child_Number
      FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Blocking_Locks l
      WHERE  1 = 1
      #{@where_string}
      GROUP BY #{blocking_locks_groupfilter_values(@groupkey)[:sql]}
      ORDER BY 5 DESC"].concat(@where_values)

    render_partial
  end

  # Anzeige der Kakskade der Verursacher blockender Locks für eine konkrete Session
  def list_blocking_reason_cascade
    @snapshot_timestamp = params[:snapshot_timestamp]
    @instance           = params[:instance]
    @sid                = params[:sid]
    @serialno           = params[:serialno]

    @locks= sql_select_all ["\
      WITH TSel AS (SELECT /*+ NO_MERGE */ *
                    FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Blocking_Locks l
                    WHERE  l.Snapshot_Timestamp = TO_DATE(?, '#{sql_datetime_second_mask}')
                    AND    l.Request != 0  -- nur Records beruecksichtigen, die wirklich auf Lock warten
                   )
      SELECT Level,
             Object_Name, Lock_Type, Seconds_in_Wait, ID1, ID2, Request, Lock_Mode,
             Blocking_Object_Owner||'.'||
             CASE
               WHEN Blocking_Object_Name LIKE 'SYS_LOB%%' THEN
                 Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Blocking_Object_Name, 8, 10)) )||')'
               WHEN Blocking_Object_Name LIKE 'SYS_IL%%' THEN
                 Blocking_Object_Name||' ('||(SELECT Object_Name FROM DBA_Objects WHERE Object_ID=TO_NUMBER(SUBSTR(Blocking_Object_Name, 7, 10)) )||')'
               ELSE Blocking_Object_Name
             END  Blocking_Object, CAST(Blocking_RowID AS VARCHAR2(18)) Blocking_RowID, Blocking_instance_Number, Blocking_SID, Blocking_SerialNo,
             Blocking_SQL_ID, Blocking_SQL_Child_Number, Blocking_Prev_SQL_ID, Blocking_Prev_Child_Number, Blocking_Status,
             Blocking_Client_Info, Blocking_Module, Blocking_Action, Blocking_User_Name, Blocking_Machine, Blocking_OS_User, Blocking_Process, Blocking_Program,
             Waiting_For_PK_Column_Name, Waiting_For_PK_Value,
             NULL Blocking_App_Desc
      FROM   TSel l
      CONNECT BY NOCYCLE PRIOR blocking_sid             = sid
                     AND PRIOR blocking_instance_number = instance_number
                     AND PRIOR blocking_serialno        = serialNo
      START WITH Instance_Number=? AND SID=? AND SerialNo=?",
                            @snapshot_timestamp, @instance, @sid,@serialno]

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.blocking_app_desc = explain_application_info(l.blocking_module)
    }

    render_partial
  end


  def show_object_increase
    @tablespaces = sql_select_all("SELECT Tablespace_Name Name FROM DBA_Tablespaces ORDER BY Name")
    @schemas     = sql_select_all("SELECT UserName Name FROM DBA_Users ORDER BY Name")

    @tablespaces.insert(0,  {:name=>all_dropdown_selector_name}.extend(SelectHashHelper))
    @schemas.insert(0,      {:name=>all_dropdown_selector_name}.extend(SelectHashHelper))

    render_partial
  end


  def list_object_increase
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung

    @wherestr = ""
    @whereval = []

    @schema_name = nil
    if params[:schema][:name] != all_dropdown_selector_name
      @schema_name = params[:schema][:name]
      @wherestr << " AND Owner=? "
      @whereval << @schema_name
    end


    list_object_increase_detail if params[:detail]
    list_object_increase_timeline if params[:timeline]
  end

  def list_object_increase_detail
    if params[:tablespace][:name] != all_dropdown_selector_name
      @tablespace_name = params[:tablespace][:name]
      @wherestr << " AND Tablespace_Name=? "
      @whereval << @tablespace_name
    end

    @min_gather_date = sql_select_one ["SELECT MIN(Gather_Date) FROM #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Object_Sizes WHERE Gather_Date >= TO_DATE(?, '#{sql_datetime_minute_mask}')", @time_selection_start]
    @max_gather_date = sql_select_one ["SELECT MAX(Gather_Date) FROM #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Object_Sizes WHERE Gather_Date <= TO_DATE(?, '#{sql_datetime_minute_mask}')", @time_selection_end]

    raise PopupMessageException.new("No data found after start time #{localeDateTime(@time_selection_start)}") if @min_gather_date.nil?
    raise PopupMessageException.new("No data found before end time #{localeDateTime(@time_selection_end)}")  if @max_gather_date.nil?

    @incs = sql_select_all ["
      SELECT s.*,
             NVL(End_Mbytes, 0) - NVL(Start_MBytes, 0) Aenderung_Abs,
             CASE WHEN Start_MBytes != 0 THEN (End_MBytes/Start_MBytes-1)*100 END Aenderung_Pct
      FROM   (SELECT Owner, Segment_Name, Segment_Type,
                     MAX(Tablespace_Name) KEEP (DENSE_RANK LAST ORDER BY Gather_Date) Last_TS,
                     COUNT(DISTINCT Tablespace_Name) Tablespaces,
                     SUM(CASE WHEN s.Gather_Date = dates.Min_Gather_Date THEN Bytes END)/(1024*1024) Start_Mbytes,
                     SUM(CASE WHEN s.Gather_Date = dates.Max_Gather_Date THEN Bytes END)/(1024*1024) End_Mbytes,
                     REGR_SLOPE(Bytes, Gather_Date-TO_DATE('1900', 'YYYY')) Anstieg,
                     COUNT(Distinct Gather_Date) Samples
              FROM   (SELECT ? Min_Gather_Date, ? Max_Gather_Date FROM DUAL) dates
              CROSS JOIN #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Object_Sizes s
              WHERE  Gather_Date IN (dates.Min_Gather_Date, dates.Max_Gather_Date)
              #{@wherestr}
              GROUP BY Owner, Segment_Name, Segment_Type
             ) s
      WHERE  NVL(Start_MBytes, 0) != NVL(End_MBytes, 0)
      ORDER BY NVL(End_Mbytes, 0) - NVL(Start_MBytes, 0) DESC
    ", @min_gather_date, @max_gather_date].concat(@whereval)

=begin
    @incs = sql_select_all ["
        SELECT s.*, End_Mbytes-Start_MBytes Aenderung_Abs,
        CASE WHEN Start_MBytes != 0 THEN (End_MBytes/Start_MBytes-1)*100 END Aenderung_Pct
        FROM   (SELECT /*+ PARALLEL(s,2) */
                       Owner, Segment_Name, Segment_Type,
                       MAX(Tablespace_Name) KEEP (DENSE_RANK LAST ORDER BY Gather_Date) Last_TS,
                       MIN(Gather_Date) Date_Start,
                       MAX(Gather_Date) Date_End,
                       MIN(MBytes) KEEP (DENSE_RANK FIRST ORDER BY Gather_Date) Start_Mbytes,
                       MAX(MBytes) KEEP (DENSE_RANK LAST ORDER BY Gather_Date) End_Mbytes,
                       REGR_SLOPE(MBytes, Gather_Date-TO_DATE('1900', 'YYYY')) Anstieg,
                       COUNT(*) Samples
                FROM   #{@object_name} s
                WHERE  Gather_Date >= TO_DATE(?, '#{sql_datetime_minute_mask}')
                AND    Gather_Date <= TO_DATE(?, '#{sql_datetime_minute_mask}')
                GROUP BY Owner, Segment_Name, Segment_Type
               ) s
        WHERE  Start_MBytes != End_MBytes
        #{@wherestr}
        ORDER BY End_Mbytes-Start_MBytes DESC",
                            @time_selection_start, @time_selection_end
                           ].concat(@whereval)

=end
    render_partial "list_object_increase_detail"
  end

  def list_object_increase_timeline
    groupby = params[:gruppierung][:tag]

    @tablespace_name = nil                                                      # initialization
    if params[:tablespace][:name] != all_dropdown_selector_name
      @tablespace_name = params[:tablespace][:name]
      @wherestr << " AND Tablespace_Name=? "
      @whereval << @tablespace_name
    end

    sizes = sql_select_all ["
        SELECT /*+ PARALLEL(s,2) */
               Gather_Date,
               #{groupby} GroupBy,
               SUM(Bytes)/(1024*1024) MBytes
        FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Object_Sizes s
        WHERE  Gather_Date >= TO_DATE(?, '#{sql_datetime_minute_mask}')
        AND    Gather_Date <= TO_DATE(?, '#{sql_datetime_minute_mask}')
        #{@wherestr}
        GROUP BY Gather_Date, #{groupby}
        ORDER BY Gather_Date, #{groupby}",
                            @time_selection_start, @time_selection_end
                           ].concat(@whereval)


    column_options =
        [
            {:caption=>"Datum",           :data=>proc{|rec| localeDateTime(rec.gather_date)},   :title=>"Zeitpunkt der Aufzeichnung der Größe"},
        ]

    @sizes = []
    columns = {}
    record = {:gather_date=>sizes[0].gather_date} if sizes.length > 0   # 1. Record mit Vergleichsdatum
    sizes.each do |s|
      if record[:gather_date] != s.gather_date  # Gruppenwechsel Datum
        @sizes << record
        record = {:gather_date=>s.gather_date}  # Neuer Record
      end
      # noinspection RubyScope
      record[:total] = 0 unless record[:total]
      record[:total] += s.mbytes
      record[s.groupby] = s.mbytes
      columns[s.groupby] = 1  if s.mbytes > 0  # Spalten unterdrücken ohne werte
    end
    @sizes << record if sizes.length > 0  # letzten Record sichern

    column_options =
        [
            {:caption=>"Datum",           :data=>proc{|rec| localeDateTime(rec[:gather_date])},   :title=>"Zeitpunkt der Aufzeichnung der Größe", :plot_master_time=>true},
            {:caption=>"Total MB",        :data=>proc{|rec| formattedNumber(rec[:total], 2)},        :title=>"Größe Total in MB", :align=>"right" }
        ]

    columns.each do |key, value|
      column_options << {:caption=>key, :data=>proc{|rec| fn(rec[key], 2)}, :title=>"Size for #{key} in MB", :align=>"right" }
    end

    output = gen_slickgrid(@sizes, column_options, {
        :multiple_y_axes  => false,
        :show_y_axes      => true,
        :plot_area_id     => :list_object_increase_timeline_diagramm,
        :max_height       => 450,
        :caption          => "Size evolution over time grouped by #{groupby} from #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Object_Sizes#{", Tablespace='#{@tablespace_name}'" if @tablespace_name}#{", Schema='#{@schema_name}'" if @schema_name}"
    })
    output << "</div><div id='list_object_increase_timeline_diagramm'></div>".html_safe


    respond_to do |format|
      format.html {render :html => output }
    end
  end

  def list_object_increase_object_timeline
    save_session_time_selection
    owner = params[:owner]
    name  = params[:name]

    @sizes = sql_select_all ["
      SELECT Gather_Date, MBytes,  MBytes - LAG(MBytes, 1, MBytes) OVER (ORDER BY Gather_Date) Increase_MB
      FROM   (
              SELECT Gather_Date,
                     SUM(Bytes)/(1024*1024) MBytes
              FROM   #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Object_Sizes s
              WHERE  Gather_Date >= TO_DATE(?, '#{sql_datetime_minute_mask}')
              AND    Gather_Date <= TO_DATE(?, '#{sql_datetime_minute_mask}')
              AND    Owner        = ?
              AND    Segment_Name = ?
              GROUP BY Gather_Date
             )
      ORDER BY Gather_Date",
                             @time_selection_start, @time_selection_end, owner, name ]

    column_options =
        [
            {:caption=>"Datum",           :data=>proc{|rec| localeDateTime(rec.gather_date)},         :title=>"Timestamp of gathering object size",       :plot_master_time=>true},
            {:caption=>"Größe MB",        :data=>proc{|rec| formattedNumber(rec.mbytes, 2)},          :title=>"Size of object in MB at gather time",      :align=>"right" },
            {:caption=>"Increase (MB)",   :data=>proc{|rec| formattedNumber(rec.increase_mb, 2)},     :title=>"Size increase in MB since last snapshot",  :align=>"right" }
        ]

    output = gen_slickgrid(@sizes,
                           column_options,
                           {
                               :multiple_y_axes => false,
                               :show_y_axes     => true,
                               :plot_area_id    => :list_object_increase_object_timeline_diagramm,
                               :caption         => "Size evolution of object #{owner}.#{name} recorded in #{PanoramaConnection.get_config[:panorama_sampler_schema]}.Panorama_Object_Sizes",
                               :max_height      => 450
                           }
    )
    output << '<div id="list_object_increase_object_timeline_diagramm"></div>'.html_safe

    respond_to do |format|
      format.html {render :html => output }
    end
  end

  # call action given by parameters
  def exec_recall_params
    begin
      parameter_info = eval(params[:parameter_info])
      raise "wrong ruby class '#{parameter_info.class}'! Expression must be of ruby class 'Hash' (comparable to JSON)." if parameter_info.class != Hash
    rescue Exception => e
      show_popup_message("Exception while evaluating expression:\n#{e.message}")
      return
    end

    parameter_info.symbolize_keys!
    parameter_info[:update_area]     = params[:update_area]
    parameter_info[:browser_tab_id]  = @browser_tab_id

    redirect_to url_for(:controller => parameter_info[:controller],:action => parameter_info[:action], :params => parameter_info, :method=>:post)

  end

end
