# encoding: utf-8
class DbaHistoryController < ApplicationController
  include DbaHelper
  include ActionView::Helpers::SanitizeHelper

  def list_segment_stat_historic_sum
    @instance = prepare_param_instance
    @dbid     = prepare_param_dbid
    @show_partitions = params[:show_partitions]
    @object_name     = params[:ObjectName]
    @object_name     = nil if @object_name == ""
    save_session_time_selection  # werte in session puffern

    @segment_sums = sql_select_iterator ["
      SELECT /* Panorama-Tool Ramm */ s.Instance_Number,
             NVL(o.Owner, '[Unknown]') Owner,
             NVL(o.Object_Name, '[Object-ID = '||MIN(s.Obj#)||']') Object_Name,
             DECODE(o.Object_Name, NULL, MIN(s.Obj#), NULL) NVL_Object_ID,    -- Eindeutige Object-ID, wenn kein Match in DBA_Objects stattfand
             o.Object_Type,
             SUM(po.SQL_IDs) SQL_IDs,
             #{@show_partitions=="1" ? "o.subObject_Name" : "''"} subObject_Name,
             MIN(s.Min_Snap_ID)                 Min_Snap_ID,
             MAX(s.Max_Snap_ID)                 Max_Snap_ID,
             SUM(w.Time_Waited_Secs)            Time_Waited_Secs,
             AVG(w.Time_Waited_Avg_ms)          Time_Waited_Avg_ms,
             MAX(s.Snaps)                       Snaps,
             SUM(Logical_reads_Delta)           Logical_Reads_Delta,
             SUM(Buffer_Busy_waits_Delta)       Buffer_Busy_waits_Delta,
             SUM(DB_Block_Changes_Delta)        DB_Block_Changes_Delta,
             SUM(Physical_Reads_Delta)          Physical_Reads_Delta,
             SUM(Physical_Writes_Delta)         Physical_Writes_Delta,
             SUM(Physical_Reads_Direct_Delta)   Physical_Reads_Direct_Delta,
             SUM(Physical_Writes_Direct_Delta)  Physical_Writes_Direct_Delta,
             SUM(ITL_Waits_Delta)               ITL_waits_Delta,
             SUM(Row_Lock_Waits_Delta)          Row_Lock_Waits_Delta,
             SUM(GC_Buffer_Busy_Delta)          GC_Buffer_Busy_Delta,
             SUM(GC_CR_Blocks_Received_Delta)   GC_CR_Blocks_Received_Delta,
             SUM(GC_CU_Blocks_Received_Delta)   GC_CU_Blocks_Received_Delta,
             SUM(Max_Space_Used_Total_MB)       Max_Space_Used_Total_MB,
             SUM(Max_Space_Allocated_Total_MB)  Max_Space_Allocated_Total_MB,
             SUM(Space_Allocated_Delta)/(1024*1024) Space_Allocated_Delta_MB,
             SUM(Table_Scans_Delta)             Table_Scans_Delta,
             (#{@show_partitions=="1" ?
               "CASE
                WHEN o.Object_Type = 'TABLE' 
                     THEN (SELECT Num_Rows FROM DBA_Tables t
                             WHERE t.Owner      = o.Owner
                             AND   t.Table_Name = o.Object_Name)
                WHEN o.Object_Type = 'TABLE PARTITION'
                     THEN (SELECT Num_Rows FROM DBA_Tab_Partitions t
                             WHERE t.Table_Owner = o.Owner
                             AND   t.Table_Name = o.Object_Name
                             AND   t.Partition_Name = o.SubObject_Name)
                WHEN o.Object_Type = 'TABLE SUBPARTITION'
                     THEN (SELECT Num_Rows FROM DBA_Tab_SubPartitions t
                             WHERE t.Table_Owner = o.Owner
                             AND   t.Table_Name = o.Object_Name
                             AND   t.SubPartition_Name = o.SubObject_Name)
                WHEN o.Object_Type = 'INDEX'
                     THEN (SELECT Num_Rows FROM DBA_Indexes i
                             WHERE i.Owner      = o.Owner
                             AND   i.Index_Name = o.Object_Name)
                WHEN o.Object_Type = 'INDEX PARTITION'
                     THEN (SELECT Num_Rows FROM DBA_Ind_Partitions i
                             WHERE i.Index_Owner = o.Owner
                             AND   i.Index_Name = o.Object_Name
                             AND   i.Partition_Name = o.SubObject_Name)
                WHEN o.Object_Type = 'INDEX SUBPARTITION'
                     THEN (SELECT Num_Rows FROM DBA_Ind_SubPartitions i
                             WHERE i.Index_Owner = o.Owner
                             AND   i.Index_Name = o.Object_Name
                             AND   i.SubPartition_Name = o.SubObject_Name)
                ELSE NULL END"  :
               "CASE
                  WHEN o.Object_Type IN ('TABLE', 'TABLE PARTITION', 'TABLE SUBPARTITION') THEN
                    (SELECT Num_Rows FROM DBA_Tables t
                    WHERE t.Owner = o.Owner
                    AND   t.Table_Name = o.Object_Name)
                  WHEN o.Object_Type IN ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION') THEN
                    (SELECT Num_Rows FROM DBA_Indexes i
                    WHERE i.Owner = o.Owner
                    AND   i.Index_Name = o.Object_Name)
                ELSE NULL END"
               })                                 Num_Rows,
               SUM(segs.MBytes)                   MBytes
      FROM   (
              SELECT /*+ NO_MERGE */ s.Obj#,
                     s.Instance_Number,
                     MIN(s.Snap_ID)                     Min_Snap_ID,
                     MAX(s.Snap_ID)                     Max_Snap_ID,
                     COUNT(DISTINCT s.Snap_ID)          Snaps,
                     SUM(Logical_reads_Delta)           Logical_Reads_Delta,
                     SUM(Buffer_Busy_waits_Delta)       Buffer_Busy_waits_Delta,
                     SUM(DB_Block_Changes_Delta)        DB_Block_Changes_Delta,
                     SUM(Physical_Reads_Delta)          Physical_Reads_Delta,
                     SUM(Physical_Writes_Delta)         Physical_Writes_Delta,
                     SUM(Physical_Reads_Direct_Delta)   Physical_Reads_Direct_Delta,
                     SUM(Physical_Writes_Direct_Delta)  Physical_Writes_Direct_Delta,
                     SUM(ITL_Waits_Delta)               ITL_Waits_Delta,
                     SUM(Row_Lock_Waits_Delta)          Row_Lock_Waits_Delta,
                     SUM(GC_Buffer_Busy_Delta)          GC_Buffer_Busy_Delta,
                     SUM(GC_CR_Blocks_Received_Delta)   GC_CR_Blocks_Received_Delta,
                     SUM(GC_CU_Blocks_Received_Delta)   GC_CU_Blocks_Received_Delta,
                     MAX(Space_Used_Total)/(1024*1024)  Max_Space_Used_Total_MB,
                     MAX(Space_Allocated_Total)/(1024*1024) Max_Space_Allocated_Total_MB,
                     MAX(Space_Allocated_Total) KEEP (DENSE_RANK LAST ORDER BY s.Snap_ID) -
                     MIN(Space_Allocated_Total) KEEP (DENSE_RANK FIRST ORDER BY s.Snap_ID) Space_Allocated_Delta,
                     SUM(Table_Scans_Delta)             Table_Scans_Delta
              from DBA_HIST_SEG_STAT s
              WHERE  (s.DBID, s.Snap_ID, s.Instance_Number) IN (
                      SELECT /*+ NO_MERGE ORDERED */ ss.DBID, ss.Snap_ID, ss.Instance_Number
                      FROM   DBA_Hist_Snapshot ss
                      LEFT OUTER JOIN (SELECT DBID, Instance_Number, MAX(Snap_ID) Snap_ID FROM dba_hist_snapshot WHERE Begin_Interval_time  < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') GROUP BY DBID, Instance_Number) s1 ON s1.Instance_Number = ss.Instance_Number AND s1.DBID = ss.DBID
                      JOIN            (SELECT DBID, Instance_Number, MIN(Snap_ID) Snap_ID FROM dba_hist_snapshot WHERE Begin_Interval_time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') GROUP BY DBID, Instance_Number) s2 ON s2.Instance_Number = ss.Instance_Number AND s2.DBID = ss.DBID
                      LEFT OUTER JOIN (SELECT DBID, Instance_Number, MIN(Snap_ID) Snap_ID FROM dba_hist_snapshot WHERE End_Interval_time    > TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') GROUP BY DBID, Instance_Number) e1 ON e1.Instance_Number = ss.Instance_Number AND e1.DBID = ss.DBID
                      JOIN            (SELECT DBID, Instance_Number, MAX(Snap_ID) Snap_ID FROM dba_hist_snapshot WHERE End_Interval_time   <= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') GROUP BY DBID, Instance_Number) e2 ON e2.Instance_Number = ss.Instance_Number AND e2.DBID = ss.DBID
                      WHERE  ss.Snap_ID >= NVL(s1.Snap_ID, s2.Snap_ID)
                      AND    ss.Snap_ID <= NVL(e1.Snap_ID, e2.Snap_ID)
                      AND    ss.DBID = ?
                    )
              #{ @instance ? " AND s.Instance_Number =#{@instance}" : ""}
              GROUP BY s.Obj#, s.Instance_Number
             ) s
      LEFT OUTER JOIN   DBA_Objects o ON o.Object_ID = s.Obj#
      LEFT OUTER JOIN   (SELECT /*+ NO_MERGE*/ Instance_Number, Current_Obj#,
                                Count(*)*10 Time_Waited_Secs,
                                AVG(Wait_Time+Time_Waited)/1000 Time_Waited_Avg_ms
                         FROM   DBA_Hist_Active_Sess_History s
                         WHERE  DBID = ?
                         AND    Sample_Time BETWEEN TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') AND TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                         #{ @instance ? " AND s.Instance_Number =#{@instance}" : ""}
                         AND    NVL(s.Event, s.Session_State) != 'PX Deq Credit: send blkd' -- dieser Event wird als Idle-Event gewertet
                         GROUP BY Instance_Number, Current_Obj#
                        ) w ON w.Instance_Number = s.Instance_Number AND w.Current_Obj# = s.Obj#
      LEFT OUTER JOIN   (SELECT /*+ NO_MERGE PARALLEL(po,2) */ Object_Owner, Object_Name, COUNT(DISTINCT SQL_ID) SQL_IDs
                         FROM   DBA_Hist_SQL_Plan po
                         GROUP BY Object_Owner, Object_Name
                        ) po ON po.Object_Owner = o.Owner AND po.Object_Name = o.Object_Name
      LEFT OUTER JOIN   ( SELECT /*+ NO_MERGE */ Owner, Segment_Name, Partition_Name, SUM(Bytes)/(1024*1024) MBytes
                          FROM   DBA_Segments
                          GROUP BY Owner, Segment_Name, Partition_Name
                        ) segs ON segs.Owner = o.Owner AND segs.Segment_Name = o.Object_Name AND NVL(segs.Partition_Name, '1') = NVL(o.SubObject_Name, '1')
      #{@object_name ? " WHERE o.Object_Name LIKE UPPER('%#{@object_name}%') " : "" }
      -- Gruppierung ueber Partitionen hinweg
      GROUP BY s.Instance_Number, o.Object_Type, o.Owner, o.Object_Name#{@show_partitions=="1" ? ", o.subObject_Name" : ""},
               NVL(o.Object_Name, s.Obj#) -- Nicht existierende Objekte nach Object_ID separieren
      ORDER BY SUM(w.Time_Waited_Secs) DESC NULLS LAST
    ", @time_selection_start, @time_selection_start, @time_selection_end, @time_selection_end, @dbid, @dbid, @time_selection_start, @time_selection_end]

    render_partial
  end # list_segment_stat_historic_sum

  # Anzeige einzelner Snaphots
  def list_segment_stat_hist_detail
    @instance       = prepare_param_instance
    @time_selection_start = params[:time_selection_start]
    @time_selection_end   = params[:time_selection_end]
    @owner          = params[:owner]
    @object_name    = params[:object_name]
    @subobject_name = params[:subobject_name]
    @subobject_name = nil if @subobject_name == ''
    min_snap_id     = params[:min_snap_id]
    max_snap_id     = params[:max_snap_id]

    stmt = "SELECT /* Panorama-Tool Ramm */ * FROM (
            Select /*+ NO_MERGE */
                   sn.Begin_Interval_Time,
                   SUM(Logical_reads_Delta)       Logical_reads_Delta,
                   SUM(Buffer_Busy_waits_Delta)   Buffer_Busy_waits_Delta,
                   SUM(DB_Block_Changes_Delta)    DB_Block_Changes_Delta,
                   SUM(Physical_Reads_Delta)      Physical_Reads_Delta,
                   SUM(Physical_Writes_Delta)     Physical_Writes_Delta,
                   SUM(Physical_Reads_Direct_Delta) Physical_Reads_Direct_Delta,
                   SUM(Physical_Writes_Direct_Delta) Physical_Writes_Direct_Delta,
                   SUM(ITL_waits_Delta)           ITL_waits_Delta,
                   SUM(Row_Lock_Waits_Delta)      Row_Lock_Waits_Delta,
                   SUM(GC_Buffer_Busy_Delta)      GC_Buffer_Busy_Delta,
                   SUM(GC_CR_Blocks_Received_Delta) GC_CR_Blocks_Received_Delta,
                   SUM(GC_CU_Blocks_Received_Delta) GC_CU_Blocks_Received_Delta,
                   SUM(Space_Used_Total)/(1024*1024)      Space_Used_Total_MB,
                   SUM(Space_Allocated_Total)/(1024*1024) Space_Allocated_Total_MB,
                   SUM(Table_Scans_Delta)         Table_Scans_Delta
            FROM   DBA_HIST_SEG_STAT s
            JOIN   DBA_hist_snapshot sn ON sn.DBID = s.DBID AND sn.Instance_Number = s.Instance_Number AND sn.Snap_ID = s.Snap_ID
            where  s.Instance_Number = ?
            AND    s.Snap_ID BETWEEN ? AND ?
            AND    s.Obj# IN (
                              SELECT Object_ID FROM DBA_Objects
                              WHERE  Owner=?
                              AND    Object_Name=?
                              #{@subobject_name ? "AND SubObject_Name=?" : "" }
                             )
            GROUP BY sn.Begin_Interval_Time
            )
            ORDER BY 1"
    binds = [stmt, @instance.to_i, min_snap_id, max_snap_id, @owner, @object_name]
    binds << @subobject_name if @subobject_name       # Nur binden wenn gefüllt
    @segment_details = sql_select_iterator binds

    render_partial :list_segment_stat_historic_detail
  end #list_segment_stat_hist_detail

  # Anzeige der im Zeitraum mit dem Objekt ausgefuhrten SQL-Statements
  def list_segment_stat_hist_sql
    @instance       = prepare_param_instance
    @time_selection_start = params[:time_selection_start]
    @time_selection_end   = params[:time_selection_end]
    @owner          = params[:owner]
    @object_name    = params[:object_name]

    @sqls = sql_select_iterator ["
        SELECT /* Panorama-Tool Ramm */ sql.*,
               (SELECT TO_CHAR(SUBSTR(SQL_Text,1,100)) FROM DBA_Hist_SQLText t WHERE t.DBID=sql.DBID AND t.SQL_ID=sql.SQL_ID) SQL_Text
        FROM   (
                SELECT /*+ NO_MERGE ORDERED */ s.DBID, s.SQL_ID, s.Instance_number, s.Parsing_Schema_Name,
                       MAX(s.Plan_Hash_Value) KEEP (DENSE_RANK LAST ORDER BY s.Snap_ID) Last_Plan_Hash_Value,
                       SUM(Executions_Delta)              Executions,
                       SUM(Elapsed_Time_Delta)/1000000    Elapsed_Time_Secs,
                       SUM(ELAPSED_TIME_Delta/1000000) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) ELAPSED_TIME_SECS_PER_EXECUTE,
                       SUM(CPU_Time_Delta)/1000000        CPU_Time_Secs,
                       SUM(Disk_Reads_Delta)              Disk_Reads,
                       SUM(Buffer_Gets_Delta)             Buffer_Gets,
                       SUM(Rows_Processed_Delta)          Rows_Processed,
                       MIN(s.Snap_ID)                     Min_Snap_ID,
                       MAX(s.Snap_ID)                     Max_Snap_ID
                FROM   dba_hist_snapshot snap
                JOIN   DBA_Hist_SQLStat s ON s.DBID=snap.DBID AND s.Instance_Number=snap.Instance_Number AND s.Snap_ID=snap.Snap_ID
                WHERE  snap.Instance_Number= ?
                AND    snap.Begin_Interval_time > TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                AND    snap.Begin_Interval_time < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                GROUP BY s.DBID, s.SQL_ID, s.Instance_number, s.Parsing_Schema_Name
               ) sql,
               DBA_Hist_SQL_Plan p
        WHERE  sql.SQL_ID              = p.SQL_ID
        AND    sql.DBID                = p.DBID
        AND    sql.Last_Plan_Hash_Value = p.Plan_Hash_Value /* Plan des letzten Statements testen */
        AND    p.Object_Owner          = UPPER(?)
        AND    p.Object_Name           = UPPER(?)",
      @instance.to_i, @time_selection_start, @time_selection_end, @owner, @object_name]

    render_partial :list_segment_stat_historic_sql
  end #list_segment_stat_hist_sql

  def list_sql_area_historic
    filter   = params[:filter]  =="" ? nil : params[:filter]
    instance = prepare_param_instance
    @dbid    = prepare_param_dbid
    sql_id   = case params[:sql_id]
                 when nil then nil
                 when "" then nil
                 else params[:sql_id].strip
               end

    topSort          = params[:topSort]
    topSort          = 'ElapsedTimeTotal' if topSort.nil? || topSort == ''
    maxResultCount   = params[:maxResultCount]
    maxResultCount   = nil if  maxResultCount == ''
    groupby_instance = params[:groupby_instance] && params[:groupby_instance] != ''

    save_session_time_selection                   # Werte puffern fuer spaetere Wiederverwendung

    where_string_instance  = ""                         # Filter-Text für nachfolgendes Statement
    where_string_innen  = ""                         # Filter-Text für nachfolgendes Statement
    where_string_aussen = ""                         # Filter-Text für nachfolgendes Statement
    where_values = [@time_selection_start, @time_selection_start, @time_selection_end, @time_selection_end, @dbid]          # Filter-werte für nachfolgendes Statement
    if instance
      where_string_instance << " AND Instance_Number = ?"
      where_values << instance.to_i
    end
    if sql_id
      where_string_innen << " WHERE s.SQL_ID LIKE '%'||?||'%'"
      where_values << sql_id
    end
    if filter
      where_string_aussen << " WHERE UPPER(SQL_TEXT) LIKE UPPER('%'||?||'%')"
      where_values << filter
    end
    where_values << maxResultCount if maxResultCount
    @sqls= sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ *
      FROM (SELECT t.SQL_Text Full_SQL_Text,
                   SUBSTR(t.SQL_Text, 1, 40) SQL_Text, 
                   s.*
      FROM (
          SELECT /*+ NO_MERGE ORDERED */ s.DBID, s.SQL_ID,
                 COUNT(DISTINCT s.Snap_ID)          Sample_Count,
                 CASE WHEN COUNT(DISTINCT s.Instance_number) = 1 THEN MIN(s.Instance_Number) ELSE NULL END Instance_Number,
                 COUNT(DISTINCT s.Instance_number)  Instance_Count,
                 COUNT(DISTINCT CASE WHEN s.Plan_Hash_Value = 0 THEN NULL ELSE s.Plan_Hash_Value END)  Plans,
                 NVL(Parsing_Schema_Name, '[UNKNOWN]')  Parsing_Schema_Name, /* sollte immer gleich sein in Gruppe */
                 SUM(Executions_Delta)              Executions,
                 SUM(Elapsed_Time_Delta)/1000000    Elapsed_Time_Secs,
                 SUM(ELAPSED_TIME_Delta/1000000) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) ELAPSED_TIME_SECS_PER_EXECUTE,
                 SUM(CPU_Time_Delta)/1000000        CPU_Time_Secs,
                 SUM(Disk_Reads_Delta)              Disk_Reads,
                 SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) DISK_READS_PER_EXECUTE,
                 SUM(Executions_Delta) / DECODE(SUM(Disk_Reads_Delta), 0, 1, SUM(Disk_Reads_Delta)) Execs_Per_Disk,
                 SUM(Buffer_Gets_Delta)             Buffer_Gets,
                 SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_delta)) BUFFER_GETS_PER_EXEC,
                 SUM(BUFFER_GETS_delta) / DECODE(SUM(Rows_Processed_Delta), 0, 1, SUM(Rows_Processed_Delta)) BUFFER_GETS_PER_Row,
                 SUM(Rows_Processed_Delta)          Rows_Processed,
                 SUM(Rows_Processed_Delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) Rows_Processed_PER_EXECUTE,
                 SUM(Parse_Calls_Delta)             Parse_Calls,
                 SUM(ClWait_Delta)                  Cluster_Wait_Time,
                 MIN(s.Snap_ID)                     Min_Snap_ID,
                 MAX(s.Snap_ID)                     Max_Snap_ID,
                 MIN(snap.Start_Time)               Start_Time,
                 MAX(snap.End_Time)                 End_Time,
                 MIN(ss.Begin_Interval_Time)        First_Occurrence,
                 MAX(ss.End_Interval_Time)          Last_Occurrence
          FROM   (SELECT  /*+ ORDERED */ s.DBID, s.Instance_Number, NVL(StartMin, StartMax) Start_Snap_ID, NVL(EndMax, EndMin) End_Snap_ID,
                  start_s.Begin_Interval_Time Start_Time, end_s.End_Interval_Time End_Time
                  FROM    (
                           SELECT /*+ NO_MERGE */ DBID, Instance_Number,
                                  MAX(CASE WHEN Begin_Interval_time <= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') THEN Snap_ID ELSE NULL END) StartMin,
                                  MIN(CASE WHEN Begin_Interval_time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') THEN Snap_ID ELSE NULL END) StartMax,
                                  MAX(CASE WHEN End_Interval_time <= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') THEN Snap_ID ELSE NULL END) EndMin,
                                  MIN(CASE WHEN End_Interval_time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') THEN Snap_ID ELSE NULL END) EndMax
                           FROM   DBA_Hist_Snapshot
                           WHERE  DBID=? #{where_string_instance}
                           GROUP BY Instance_Number, DBID
                  ) s
                  JOIN    DBA_Hist_Snapshot start_s ON start_s.DBID=s.DBID AND start_s.Instance_Number=s.Instance_Number AND start_s.Snap_ID = NVL(StartMin, StartMax)
                  JOIN    DBA_Hist_Snapshot end_s   ON end_s.DBID=s.DBID   AND end_s.Instance_Number=s.Instance_Number   AND end_s.Snap_ID = NVL(EndMax, EndMin)
                 ) snap
          JOIN   DBA_Hist_SQLStat s   ON s.DBID=snap.DBID AND s.Instance_Number=snap.Instance_Number AND s.Snap_ID BETWEEN snap.Start_Snap_ID AND snap.End_Snap_ID
          JOIN   DBA_Hist_Snapshot ss ON ss.DBID=s.DBID   AND ss.Instance_Number=s.Instance_Number   AND ss.Snap_ID = s.Snap_ID -- konkreter Snapshot des SQL
          #{where_string_innen}
          GROUP BY s.DBID, s.SQL_ID, s.Parsing_Schema_Name #{', s.Instance_Number' if groupby_instance}
           ) s
      LEFT OUTER JOIN DBA_Hist_SQLText t ON t.DBID = s.DBID AND t.SQL_ID = s.SQL_ID
      #{where_string_aussen}
      ORDER BY
      #{case topSort
              when "ElapsedTimePerExecute" then "ELAPSED_TIME_SECS_PER_EXECUTE DESC"
              when "ElapsedTimeTotal"      then "ELAPSED_TIME_Secs DESC"
              when "ExecutionCount"        then "Executions DESC"
              when 'ParseCalls'            then 'Parse_Calls DESC'
              when "RowsProcessed"         then "Rows_Processed DESC"
              when "ExecsPerDisk"          then "Execs_Per_Disk DESC"
              when "BufferGetsPerRow"      then "Buffer_Gets_Per_Row DESC"
              when "CPUTime"               then "CPU_Time_Secs DESC"
              when "BufferGets"            then "Buffer_gets DESC"
              when "ClusterWaits"          then "Cluster_Wait_Time DESC"
        else  "[Unknown]"
        end } 
      )
      #{'WHERE ROWNUM < ?' if maxResultCount}
      ORDER BY
      #{case topSort
              when "ElapsedTimePerExecute" then "ELAPSED_TIME_SECS_PER_EXECUTE DESC"
              when "ElapsedTimeTotal"      then "ELAPSED_TIME_Secs DESC"
              when "ExecutionCount"        then "Executions DESC"
              when "RowsProcessed"         then "Rows_Processed DESC"
              when 'ParseCalls'            then 'Parse_Calls DESC'
              when "ExecsPerDisk"          then "Execs_Per_Disk DESC"
              when "BufferGetsPerRow"      then "Buffer_Gets_Per_Row DESC"
              when "CPUTime"               then "CPU_Time_Secs DESC"
              when "BufferGets"            then "Buffer_gets DESC"
              when "ClusterWaits"          then "Cluster_Wait_Time DESC"
        else  "[Unknown]"
        end }"
     ].concat(where_values)

    render_partial :list_sql_area_historic
  end #list_sql_area_historic

  def list_sql_detail_historic
    @instance    = prepare_param_instance
    @sql_id      = params[:sql_id]
    @parsing_schema_name = params[:parsing_schema_name]
    @parsing_schema_name = nil if @parsing_schema_name == ''

    params[:time_selection_start] = params[:time_selection_start][0, sql_datetime_minute_mask.length-2]  # evtl. Sekunden abschneiden von Zeitstempel, -2 wegen HH24 bringt nur 2 stellen
    params[:time_selection_end]   = params[:time_selection_end][0, sql_datetime_minute_mask.length-2]

    save_session_time_selection   # werte in session puffern
    @dbid        = prepare_param_dbid

    @sql= sql_select_first_row ["\


         WITH Snaps AS (SELECT /*+ NO_MERGE MATERIALIZE ORDERED USE_NL(s start_s end_s) INDEX(start_s) INDEX(end_s) */
                               s.DBID, s.Instance_Number, s.Start_Snap_ID, s.End_Snap_ID,
                               start_s.Begin_Interval_Time Start_Time, end_s.End_Interval_Time End_Time,
                               (SELECT /* NO_MERGE FIRST_ROWS(10) */ MIN(h.Sample_Time) FROM DBA_Hist_Active_Sess_History h
                                WHERE  h.DBID = s.DBID AND h.Instance_Number = s.Instance_Number AND h.SQL_ID = ? AND h.Snap_ID BETWEEN s.Start_Snap_ID AND s.End_Snap_ID
                               ) Min_Sample_Time,
                               (SELECT /* NO_MERGE FIRST_ROWS(10) */ MAX(h.Sample_Time) FROM DBA_Hist_Active_Sess_History h
                                WHERE  h.DBID = s.DBID AND h.Instance_Number = s.Instance_Number AND h.SQL_ID = ? AND h.Snap_ID BETWEEN s.Start_Snap_ID AND s.End_Snap_ID
                               ) Max_Sample_Time
                       FROM   (
                                SELECT /*+ NO_MERGE */ DBID, Instance_Number,
                                       NVL(MAX(CASE WHEN Begin_Interval_time <= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') THEN Snap_ID ELSE NULL END) /* StartMin */,
                                           MIN(CASE WHEN Begin_Interval_time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') THEN Snap_ID ELSE NULL END) /* StartMax */) Start_Snap_ID,
                                       NVL(MIN(CASE WHEN End_Interval_time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') THEN Snap_ID ELSE NULL END) /* EndMax */,
                                           MAX(CASE WHEN End_Interval_time <= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') THEN Snap_ID ELSE NULL END) /* EndMin */) End_Snap_ID
                                FROM   DBA_Hist_Snapshot
                                WHERE  DBID=? #{'AND Instance_Number=?' if @instance}
                                GROUP BY Instance_Number, DBID
                               ) s
                        JOIN   DBA_Hist_Snapshot start_s ON start_s.DBID=s.DBID AND start_s.Instance_Number=s.Instance_Number AND start_s.Snap_ID = s.Start_Snap_ID
                        JOIN   DBA_Hist_Snapshot end_s   ON end_s.DBID=s.DBID   AND end_s.Instance_Number=s.Instance_Number   AND end_s.Snap_ID = s.End_Snap_ID
                       )
         SELECT /*+ NO_MERGE ORDERED Panorama-Tool Ramm */
                 NVL(MIN(Parsing_Schema_Name), '[UNKNOWN]')  Parsing_Schema_Name,
                 MAX(s.Plan_Hash_Value) KEEP (DENSE_RANK LAST ORDER BY s.Snap_ID) Last_Plan_Hash_Value,
                 COUNT(DISTINCT CASE WHEN s.Plan_Hash_Value = 0 THEN NULL ELSE s.Plan_Hash_Value END)  Plan_Hash_Value_Count,
                 MAX(s.Optimizer_Env_Hash_Value) KEEP (DENSE_RANK LAST ORDER BY s.Snap_ID) Last_Optimizer_Env_Hash_Value,
                 COUNT(DISTINCT s.Optimizer_Env_Hash_Value)  Optimizer_Env_Hash_Value_Count,
                 SUM(Executions_Delta)              Executions,
                 SUM(Fetches_Delta)                 Fetches,
                 SUM(Parse_Calls_Delta)             Parse_Calls,
                 SUM(Sorts_Delta)                   Sorts,
                 SUM(Loads_Delta)                   Loads,
                 100 * (SUM(s.Buffer_Gets_Delta) - SUM(s.Disk_Reads_Delta)) / GREATEST(SUM(s.Buffer_Gets_Delta), 1) Hit_Ratio,
                 SUM(Elapsed_Time_Delta)/1000000    Elapsed_Time_Secs,
                 SUM(ELAPSED_TIME_Delta/1000000) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) ELAPSED_TIME_SECS_PER_EXECUTE,
                 SUM(CPU_Time_Delta)/1000000        CPU_Time_Secs,
                 SUM(Disk_Reads_Delta)              Disk_Reads,
                 SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) DISK_READS_PER_EXECUTE,
                 SUM(Executions_Delta) / DECODE(SUM(Disk_Reads_Delta), 0, 1, SUM(Disk_Reads_Delta)) Execs_Per_Disk,
                 SUM(Buffer_Gets_Delta)             Buffer_Gets,
                 SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_delta)) BUFFER_GETS_PER_EXEC,
                 SUM(BUFFER_GETS_delta) / DECODE(SUM(Rows_Processed_Delta), 0, 1, SUM(Rows_Processed_Delta)) BUFFER_GETS_PER_Row,
                 SUM(Rows_Processed_Delta)          Rows_Processed,
                 SUM(Rows_Processed_Delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) Rows_Processed_PER_EXECUTE,
                 SUM(ClWait_Delta)/1000000          Cluster_Wait_Time_Secs,
                 SUM(ApWait_Delta)/1000000          Application_Wait_Time_secs,
                 SUM(CCWait_Delta)/1000000          Concurrency_Wait_Time_secs,
                 SUM(IOWait_Delta)/1000000          User_IO_Wait_Time_secs,
                 SUM(PLSExec_Time_Delta)/1000000    PLSQL_Exec_Time_secs,
                 MIN(snaps.Start_Time)              First_Occurrence,
                 MAX(snaps.End_Time)                Last_Occurrence,
                 MIN(snaps.Min_Sample_Time)         Min_Sample_Time,
                 MAX(snaps.Max_Sample_Time)         Max_Sample_Time,
                 MAX(s.Module) KEEP (DENSE_RANK LAST ORDER BY s.Snap_ID) Last_Module,
                 MAX(s.Action) KEEP (DENSE_RANK LAST ORDER BY s.Snap_ID) Last_Action,
                 MIN(snaps.Start_Snap_ID)           Min_Snap_ID,                /* evtl. ueber mehrere Instances hinweg */
                 MAX(snaps.End_Snap_ID)             Max_Snap_ID,                /* evtl. ueber mehrere Instances hinweg */
                 MIN(s.Parsing_Schema_Name)         Min_Parsing_Schema_Name,
                 COUNT(DISTINCT Parsing_Schema_Name) Parsing_Schema_Count,      /* muss eindeutig sein */
                 COUNT(*)                           Hit_Count,
                 MAX(s.SQL_Profile)                 SQL_Profile,                /* Eines der evt. benutzten Profiles */
                 MAX(s.Force_Matching_Signature)    Force_Matching_Signature
         FROM   Snaps
          JOIN   DBA_Hist_SQLStat s ON s.DBID = Snaps.DBID AND s.Instance_Number = Snaps.Instance_Number AND s.Snap_ID BETWEEN Snaps.Start_Snap_ID AND Snaps.End_Snap_ID
          WHERE  s.SQL_ID = ?
          #{'AND s.Parsing_Schema_Name = ?' if @parsing_schema_name}
          ",
                                @sql_id, @sql_id, @time_selection_start, @time_selection_start, @time_selection_end, @time_selection_end, @dbid].
              concat(@instance ? [@instance] : []).
              concat([@sql_id]).concat(@parsing_schema_name ? [@parsing_schema_name] : [])

    if @sql.parsing_schema_count > 1
      list_sql_area_historic                                                    # auf Auswahl eines konkreten Parsing Schema verzweigen
      return
    end

    if @sql.hit_count == 0 && @parsing_schema_name                              # Keine SQL-Statistik getroffen
      params[:parsing_schema_name] = nil
      list_sql_detail_historic                                                  # noch einmal über alle parsing schema names versuchen
      return
    end

    if  @sql.hit_count == 0
      @binds_count = 0
    else
      @binds_count = sql_select_one ["\
        SELECT COUNT(*)
        FROM   DBA_Hist_SQLBind b
        WHERE  DBID            = ?
        AND    SQL_ID          = ?
        AND    (Snap_ID, Instance_Number) IN (SELECT MAX(Snap_ID), MAX(Instance_Number) KEEP (DENSE_RANK LAST ORDER BY Snap_ID)
                                              FROM   DBA_Hist_SQLBind
                                              WHERE  DBID   = ?
                                              AND    SQL_ID = ?
                                              AND    Snap_ID BETWEEN ? AND ?
                                              #{'AND Instance_Number=?' if @instance}
                                             )
        ", @dbid, @sql_id, @dbid, @sql_id, @sql.min_snap_id, @sql.max_snap_id].concat(@instance ? [@instance] : [])


    end

    sql_statement = sql_select_first_row(["\
       SELECT /* Panorama-Tool Ramm */ SQL_Text,
                   DBMS_SQLTUNE.SQLTEXT_TO_SIGNATURE(SQL_Text, 0) Exact_Signature,
                   DBMS_SQLTUNE.SQLTEXT_TO_SIGNATURE(SQL_Text, 1) Force_Signature
       FROM DBA_Hist_SQLText
       WHERE dbid = ?
       AND   SQL_ID = ?",
                                          @dbid, @sql_id
                                         ])


    if sql_statement
      @sql_statement      = sql_statement.sql_text
      @exact_matching_signature = sql_statement.exact_signature   # Not available in DBA_Hist_SQLStat
      @sql.force_matching_signature = sql_statement.force_signature if @sql.force_matching_signature.nil?   # Use calculated signature if history did not hit values
      @sql_profiles       = sql_select_all ["SELECT * FROM DBA_SQL_Profiles       WHERE Signature = TO_NUMBER(?) OR Signature = TO_NUMBER(?)", sql_statement.exact_signature.to_s, sql_statement.force_signature.to_s]
      @sql_outlines       = sql_select_all ["SELECT * FROM DBA_Outlines           WHERE Signature = sys.UTL_RAW.Cast_From_Number(TO_NUMBER(?)) OR Signature = sys.UTL_RAW.Cast_From_Number(TO_NUMBER(?))", sql_statement.exact_signature.to_s, sql_statement.force_signature.to_s]
    else
      @sql_statement      = "[No statement found in DBA_Hist_SQLText]"
      @sql_profiles       = []
      @sql_outlines       = []
    end

    unless sql_statement                                                           # No SQL text found in history ?
      sga_exists = sql_select_first_row ["SELECT Inst_ID FROM gv$SQLArea WHERE SQL_ID=? #{" ORDER BY DECODE(Inst_ID, #{@instance}, 0, 1)" if @instance}", @sql_id] # First record in result with current instance if exsists
      if sga_exists
        redirect_to url_for(:controller => :dba_sga,
                            :action     => :list_sql_detail_sql_id,
                            :params     => {instance:           sga_exists.inst_id,
                                            sql_id:             @sql_id,
                                            update_area:        params[:update_area],
                                            browser_tab_id:     @browser_tab_id,
                                            statusbar_message:  "No SQL text found in AWR-history for this SQL_ID and instance between #{@time_selection_start} and #{@time_selection_end}, but found SQL in current SGA"
                                           },
                            :method     => :post)
        return
      end
    end

    render_partial :list_sql_detail_historic
  end #list_sql_detail_historic

  def list_binds_historic
    @sql_id         = params[:sql_id]
    @instance       = prepare_param_instance
    @min_snap_id    = params[:min_snap_id]
    @max_snap_id    = params[:max_snap_id]
    @dbid           = prepare_param_dbid

    @binds = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ Instance_Number, Name, Position, DataType_String, Last_Captured,
             CASE DataType_String
               WHEN 'TIMESTAMP' THEN TO_CHAR(ANYDATA.AccessTimestamp(Value_AnyData), '#{sql_datetime_minute_mask}')
             ELSE Value_String END Value_String,
             NLS_CHARSET_NAME(Character_SID) Character_Set, Precision, Scale, Max_Length,
             (SELECT COUNT(*)
              FROM   DBA_Hist_SQLBind i
              WHERE  i.DBID            = b.DBID
              AND    i.Snap_ID BETWEEN ? AND ?
              AND    i.Instance_Number = b.Instance_Number
              AND    i.SQL_ID          = b.SQL_ID
              AND    i.Position        = b.Position
             ) Samples
      FROM   DBA_Hist_SQLBind b
      WHERE  DBID            = ?
      AND    SQL_ID          = ?
      AND    (Snap_ID, Instance_Number) IN (SELECT MAX(Snap_ID), MAX(Instance_Number) KEEP (DENSE_RANK LAST ORDER BY Snap_ID)
                                            FROM   DBA_Hist_SQLBind
                                            WHERE  DBID   = ?
                                            AND    SQL_ID = ?
                                            AND    Snap_ID BETWEEN ? AND ?
                                            #{'AND Instance_Number=?' if @instance}
                                           )
      ORDER BY Position
      ", @min_snap_id, @max_snap_id, @dbid, @sql_id, @dbid, @sql_id, @min_snap_id, @max_snap_id].concat(@instance ? [@instance] : [])


    render_partial
  end

  def list_bind_samples_historic
    @instance    = prepare_param_instance         # optional
    @sql_id      = params[:sql_id]
    @position    = params[:position]
    @min_snap_id = params[:min_snap_id]
    @max_snap_id = params[:max_snap_id]
    @dbid        = prepare_param_dbid

    @binds = sql_select_iterator ["\
        SELECT /* Panorama-Tool Ramm */ b.Name, b.DataType_String, b.Last_Captured,
               CASE b.DataType_String
                 WHEN 'TIMESTAMP' THEN TO_CHAR(ANYDATA.AccessTimestamp(b.Value_AnyData), '#{sql_datetime_minute_mask}')
               ELSE b.Value_String END Value_String,
               NLS_CHARSET_NAME(b.Character_SID) Character_Set, b.Precision, b.Scale, b.Max_Length,
               ss.End_Interval_Time
        FROM   DBA_Hist_SQLBind b
        JOIN   DBA_Hist_Snapshot ss ON ss.DBID = b.DBID AND ss.Snap_ID = b.Snap_ID AND ss.Instance_Number = b.Instance_Number
        WHERE  b.DBID            = ?
        AND    b.Instance_Number = ?
        AND    b.SQL_ID          = ?
        AND    b.Snap_ID BETWEEN ? AND ?
        AND    b.Position        = ?
        ORDER BY Last_Captured
        ", @dbid, @instance, @sql_id, @min_snap_id, @max_snap_id, @position]

    render_partial
  end



  def list_sql_historic_execution_plan
    @instance    = prepare_param_instance         # optional
    @sql_id      = params[:sql_id]
    @parsing_schema_name = params[:parsing_schema_name]   # optional, Kann '[UNKNOWN]' enthalten, dann kein Match möglich
    save_session_time_selection   # werte in session puffern

    where_stmt       = ""
    ash_where_stmt   = ""
    where_values     = []
    ash_where_values = []
    if @instance
      where_stmt     << " AND s.Instance_Number = ?"
      ash_where_stmt << " AND Instance_Number = ?"
      where_values     << @instance
      ash_where_values << @instance
    end
    if @parsing_schema_name
      where_stmt   << " AND NVL(s.Parsing_Schema_Name, '[UNKNOWN]') = ?"
      where_values << @parsing_schema_name
    end

    # Ermittlung der DISTINCT Pläne
    @multiplans = sql_select_all ["SELECT /*+ ORDERED INDEX(s) Panorama-Tool Ramm */
                                           s.Plan_Hash_Value, s.DBID, s.Parsing_Schema_Name,
                                           MIN(Optimizer_Env_Hash_Value) Optimizer_Env_Hash_Value,
                                           SUM(s.Elapsed_Time_Delta)/1000000 Elapsed_Time_Secs,
                                           SUM(s.Executions_Delta) Executions,
                                           SUM(s.Elapsed_Time_Delta)/DECODE(SUM(s.Executions_Delta), 0, 1, SUM(s.Executions_Delta))/1000000 Secs_Per_Execution,
                                           MIN(ss.Begin_Interval_Time) First_Occurrence,
                                           MAX(ss.End_Interval_Time)   Last_Occurrence,
                                           MIN(ss.Snap_ID)             Min_Snap_ID,
                                           MAX(ss.Snap_ID)             Max_Snap_ID
                                    FROM   DBA_Hist_SQLStat s
                                    JOIN   DBA_Hist_Snapshot ss ON ss.DBID=s.DBID AND ss.Instance_Number=s.Instance_Number AND ss.Snap_ID=s.Snap_ID
                                    WHERE  s.SQL_ID = ?
                                    AND    ss.End_Interval_time   > TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                                    AND    ss.Begin_Interval_time < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                                    AND    s.Plan_Hash_Value != 0 -- count only real execution plans
                                    #{where_stmt}
                                    GROUP BY s.Plan_Hash_Value, s.DBID, s.Parsing_Schema_Name
                                    ORDER BY MIN(ss.Begin_Interval_Time)
                                   ", @sql_id, @time_selection_start, @time_selection_end].concat(where_values)

    all_plans = sql_select_all ["\
                         SELECT /*+ ORDERED USE_NL(p) Panorama-Tool Ramm */
                                ps.DBID, ps.Plan_Hash_Value, ps.Parsing_Schema_Name, p.Timestamp,
                                p.Operation, p.Options, p.Object_Owner, p.Object_Name, p.Object_Type, p.Object_Alias, p.QBlock_Name, p.Optimizer,
                                p.Other_Tag, p.Other_XML, p.Other, p.Search_Columns,
                                DECODE(p.Other_Tag,
                                       'PARALLEL_COMBINED_WITH_PARENT', 'PCWP',
                                       'PARALLEL_COMBINED_WITH_CHILD' , 'PCWC',
                                       'PARALLEL_FROM_SERIAL',          'S > P',
                                       'PARALLEL_TO_PARALLEL',          'P > P',
                                       'PARALLEL_TO_SERIAL',            'P > S',
                                       'SINGLE_COMBINED_WITH_CHILD',    'SCWC',
                                       'SINGLE_COMBINED_WITH_PARENT',   'SCWP',
                                       Other_Tag
                                      ) Parallel_Short,
                                p.Depth, p.Access_Predicates, p.Filter_Predicates, p.Projection, p.temp_Space/(1024*1024) Temp_Space_MB, p.Distribution,
                                p.ID, p.Parent_ID, 0 ExecOrder,
                                p.Cost, p.CPU_Cost, p.IO_Cost, p.Cardinality, p.Bytes, p.Partition_Start, p.Partition_Stop, p.Partition_ID, p.Time,
                                NVL(t.Num_Rows, i.Num_Rows) Num_Rows,
                                NVL(t.Last_Analyzed, i.Last_analyzed) Last_Analyzed,
                                (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments s WHERE s.Owner=p.Object_Owner AND s.Segment_Name=p.Object_Name) MBytes,
                                Count(*) OVER (PARTITION BY p.Parent_ID, p.Operation, p.Options, p.Object_Owner,    -- p.ID nicht abgleichen, damit Verschiebungen im Plan toleriert werden
                                              CASE WHEN p.Object_Name LIKE ':TQ%'
                                                THEN 'Hugo'
                                                ELSE p.Object_Name END,
                                              p.Other_Tag, p.Depth,
                                              p.Access_Predicates, p.Filter_Predicates, p.Distribution
                                ) Version_Orange_Count,
                                  Count(*) OVER (PARTITION BY p.Parent_ID, p.Operation, p.Options, p.Object_Owner,     -- p.ID nicht abgleichen, damit Verschiebungen im Plan toleriert werden
                                              CASE WHEN p.Object_Name LIKE ':TQ%'
                                                THEN 'Hugo'
                                                ELSE p.Object_Name END,
                                             p.Depth
                                ) Version_Red_Count
                         FROM   (SELECT /*+ NO_MERGE ORDERED INDEX(s) */
                                        s.SQL_ID, s.Plan_Hash_Value, s.DBID, s.Parsing_Schema_Name
                                 FROM   DBA_Hist_SQLStat s
                                 JOIN   DBA_Hist_Snapshot ss ON ss.DBID=s.DBID AND ss.Instance_Number=s.Instance_Number AND ss.Snap_ID=s.Snap_ID
                                 WHERE  s.SQL_ID = ?
                                 AND    ss.End_Interval_time   > TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                                 AND    ss.Begin_Interval_time < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                                 #{where_stmt}
                                 GROUP BY s.SQL_ID, s.Plan_Hash_Value, s.DBID, s.Parsing_Schema_Name
                                ) ps
                         JOIN   DBA_Hist_SQL_Plan p ON p.DBID=ps.DBID AND p.SQL_ID=ps.SQL_ID AND p.Plan_Hash_Value=ps.Plan_Hash_Value
                         LEFT OUTER JOIN DBA_Tables t  ON t.Owner=p.Object_Owner AND t.Table_Name=p.Object_Name -- evtl. weiter zu filtern per  NVL(p.Object_Type, 'TABLE') LIKE 'TABLE%'
                         LEFT OUTER JOIN DBA_Indexes i ON i.Owner=p.Object_Owner AND i.Index_Name=p.Object_Name -- evtl. weiter zu filtern per  p.Object_Type LIKE 'INDEX%'
                         ORDER BY p.ID
                       ", @sql_id, @time_selection_start, @time_selection_end].concat(where_values)

    # Iteration über unterschiedliche Ausführungspläne
    @multiplans.each do |mp|
      mp[:plans] = []   # Konkreter Ausführungsplan, aus Gesamtmenge aller Pläne auszufiltern
      all_plans.each do |p|
        if p.dbid == mp.dbid && p.plan_hash_value == mp.plan_hash_value && p.parsing_schema_name == mp.parsing_schema_name
          mp[:plans] << p
          mp[:timestamp] = p.timestamp                                          # Timestamp of parse
        end
      end

      if get_db_version >= "11.2"     # Ab 11.2 sind ASH-Records mit Verweis auf Zeile des Ausführungsplans versehen
        ash = sql_select_all ["\SELECT SQL_PLan_Line_ID,
                                       SUM(DB_Time_Seconds)       DB_Time_Seconds,
                                       SUM(CPU_Seconds)           CPU_Seconds,
                                       SUM(Waiting_Seconds)       Waiting_Seconds,
                                       SUM(Read_IO_Requests)      Read_IO_Requests,
                                       SUM(Write_IO_Requests)     Write_IO_Requests,
                                       SUM(Interconnect_IO_Bytes) Interconnect_IO_Bytes,
                                       MIN(Min_Sample_Time)       Min_Sample_Time,
                                       MAX(Temp)/(1024*1024)      Max_Temp_ASH_MB,
                                       MAX(PGA)/(1024*1024)       Max_PGA_ASH_MB,
                                       MAX(PQ_Sessions)           Max_PQ_Sessions     -- max. Anzahl PQ-Slaves + Koordinator für eine konkrete Koordinator-Session
                                FROM   (
                                        SELECT /*+ PARALLEL(h,2) #{"FULL(h.ash)" if mp.max_snap_id-mp.min_snap_id > 10}*/
                                                NVL(SQL_PLan_Line_ID, 0)                                   SQL_PLan_Line_ID,   -- NULL auf den Knoten 0 des Plans zurückführen (0 wird in 11.2.0.3 nicht mit nach DBA_HAS übernommen
                                                COUNT(*) * 10                                              DB_Time_Seconds,
                                                SUM(CASE WHEN Session_State = 'ON CPU'  THEN 10 ELSE 0 END) CPU_Seconds,
                                                SUM(CASE WHEN Session_State = 'WAITING' THEN 10 ELSE 0 END) Waiting_Seconds,
                                                SUM(Delta_Read_IO_Requests)       Read_IO_Requests,
                                                SUM(Delta_Write_IO_Requests)      Write_IO_Requests,
                                                SUM(NVL(Delta_Read_IO_Requests,0)+NVL(Delta_Write_IO_Requests,0)) IO_Requests,
                                                SUM(Delta_Read_IO_Bytes)          Read_IO_Bytes,
                                                SUM(Delta_Write_IO_Bytes)         Write_IO_Bytes,
                                                SUM(Delta_Interconnect_IO_Bytes)  Interconnect_IO_Bytes,
                                                MIN(Sample_Time)                  Min_Sample_Time,
                                                SUM(Temp_Space_Allocated)         Temp,
                                                SUM(PGA_Allocated)                PGA,
                                                COUNT(DISTINCT CASE WHEN QC_Session_ID IS NULL OR QC_Session_ID = Session_ID THEN NULL ELSE Session_ID END) PQ_Sessions   -- Anzahl unterschiedliche PQ-Slaves + Koordinator für diese Koordiantor-Session
                                         FROM   DBA_Hist_Active_Sess_History h
                                         WHERE  DBID = ?
                                         AND    Snap_ID BETWEEN ? AND ?
                                         AND    SQL_ID  = ?
                                         AND    SQL_Plan_Hash_Value = ? #{ash_where_stmt}
                                         GROUP BY SQL_Plan_Line_ID, NVL(QC_Session_ID, Session_ID), Sample_ID   -- Alle PQ-Werte mit auf Session kumulieren
                                        )
                                GROUP BY SQL_Plan_Line_ID
                              ", mp.dbid, mp.min_snap_id, mp.max_snap_id, @sql_id, mp.plan_hash_value].concat(ash_where_values)
        ash_hash = {} # Umkopieren in Hash um eindeutige Zugriffe zu landen
        ash.each do |a|
          ash_hash[a.sql_plan_line_id] = a
        end

        # Zuordnen der ASH-Zeilen zu den korrespondierenden Plan-Zeilen
        mp[:plans].each do |p|
          a = ash_hash[p.id]
          if a
            a.each do |key, value|
              p[key] = value
            end
          end
          p.extend TolerantSelectHashHelper   # Erlaibt Methoden-Aufrufe auf nicht deklarierte Element mit return nil
        end

      end


      # Vergabe der exec-Order im Explain
      # iteratives neu durchsuchen der Liste nach folgenden erfuellten Kriterien
      # - ID tritt nicht als Parent auf
      # - alle Children als Parent sind bereits mit ExecOrder versehen
      # gefundene Records werden mit aufteigender Folge versehen und im folgenden nicht mehr betrachtet

      # Array mit den Positionen der Objekte in plans anlegen
      pos_array = []
      0.upto(mp[:plans].length-1) {|i|  pos_array << i }
      curr_execorder = 1                                             # Startwert
      last_parent_id = 0                                             # Reihenfolge-ID des Parents des zuletzt gelöschten Child (Parent-ID is immer kleiner als Child-ID)
      while pos_array.length > 0                                     # Bis alle Records im PosArray mit Folge versehen sind
        pos_array.each {|i|                                          # Iteration ueber Verbliebene Records
          if mp[:plans][i].id >= last_parent_id                           # Knoten vor der letzten Parent-ID kommen noch nicht in Frage für Ohne Child
            is_parent = false                                        # Default-Annahme, wenn kein Child gefunden
            pos_array.each {|x|                                      # Suchen, ob noch ein Child zum Parent existiert in verbliebener Menge
              if mp[:plans][i].id == mp[:plans][x].parent_id                   # Doch noch ein Child zum Parent gefunden
                is_parent = true
                mp[:plans][i][:is_parent] = true                     # Merken Status als Knoten
                break                                                # Braucht nicht weiter gesucht werden
              end
            }
            unless is_parent
              mp[:plans][i].execorder = curr_execorder                    # Vergabe Folge
              curr_execorder = curr_execorder + 1
              last_parent_id = mp[:plans][i].parent_id                    # Parent-ID als Startwert der nächsten Suche (Treffer liegen darunter)
              pos_array.delete(i)                                    # entwerten der verarbeiten Zeile fuer Folgebetrachtung
              pos_array = pos_array.compact                          # Entfernen der gelöschten Einträge
              break                                                  # Neue Suche vom Beginn an
            end
          end
        }
      end
    end

    # Identität der einzelnen Zeilen prüfen und setzen
    max_plan_length = 0
    @multiplans.each do |mp|
      max_plan_length = mp[:plans].count if max_plan_length < mp[:plans].count
    end

    def plan_line_hash(line)  # Kriterium für Vergleich zweier Zeilen
      return 0 unless line
      line.id.hash + line.parent_id.hash + line.operation.hash + line.options.hash + line.object_owner.hash +
          (line.object_name && line.object_name[':TQ%'] ? "Hugo" : line.object_name).hash +
      line.other_tag.hash + line.depth.hash + line.access_predicates.hash + line.filter_predicates.hash + line.distribution.hash
    end

    (0..max_plan_length - 1).each {|row_index|
      @multiplans.each do |mp|
        mp[:plans][row_index][:plan_different] = false if mp[:plans][row_index] # Default, fall später nichts abweichendes festgestellt
      end

      test_hash = plan_line_hash(@multiplans[0][:plans][row_index])
      (1..@multiplans.count - 1).each {|mp_index|
        if plan_line_hash(@multiplans[mp_index][:plans][row_index]) != test_hash
          @multiplans.each do |mp|
            mp[:plans][row_index][:plan_different] = true if mp[:plans][row_index] # Merken differenz auf Zeilenebene
          end
        end
      }
    }

    render_partial :list_sql_detail_historic_execution_plan
  end

  # Anzeige aller gespeicherter Werte eines konkreten SQL
  def list_sql_history_snapshots
    @prev_update_area    = params[:update_area]
    @instance            = prepare_param_instance
    @dbid                = prepare_param_dbid
    @sql_id              = params[:sql_id]
    @parsing_schema_name = params[:parsing_schema_name]
    @parsing_schema_name = nil if @parsing_schema_name == ''
    @time_selection_start = params[:time_selection_start]
    @time_selection_end   = params[:time_selection_end]
    @groupby              = params[:groupby]

    @groupby = 'snap' if @groupby.nil? || @groupby == ''  # Default
    case @groupby.to_s
      when "snap" then        # Direkte Anzeige der Snapshots
        @begin_interval_sql = "snap.Begin_Interval_Time"
        @end_interval_sql   = "snap.End_Interval_Time"
      when "hour" then
        @begin_interval_sql = "TRUNC(snap.Begin_Interval_Time, 'HH24')"
        @end_interval_sql   = "TRUNC(snap.Begin_Interval_Time, 'HH24') + INTERVAL '1' HOUR"
      when "day" then
        @begin_interval_sql = "TRUNC(snap.Begin_Interval_Time)"
        @end_interval_sql   = "TRUNC(snap.Begin_Interval_Time) + INTERVAL '1' DAY"
      when "week" then
        @begin_interval_sql = "TRUNC(snap.Begin_Interval_Time, 'IW')"
        @end_interval_sql   = "TRUNC(snap.Begin_Interval_Time, 'IW') + INTERVAL '7' DAY"
      when "month" then
        @begin_interval_sql = "TRUNC(snap.Begin_Interval_Time, 'MM')"
        @end_interval_sql   = "TRUNC(snap.Begin_Interval_Time, 'MM') + INTERVAL '1' MONTH"
      else
        raise "Unsupported value for parameter :groupby (#{@groupby})"
    end

    if @time_selection_start == nil || @time_selection_end == nil
      alter =sql_select_first_row ["SELECT TO_CHAR(MIN(Begin_Interval_Time), '#{sql_datetime_minute_mask}') Time_Selection_Start,
                                           TO_CHAR(MAX(End_Interval_Time), '#{sql_datetime_minute_mask}') Time_Selection_End
                                    FROM    DBA_Hist_Snapshot
                                    WHERE   DBID            = ?
                                    #{' AND     Instance_Number = ?' if @instance}
                                   ", @dbid].concat(@instance ? [@instance] : [])
      @time_selection_start =alter.time_selection_start
      @time_selection_end =alter.time_selection_end
    end

    if @time_selection_start == nil || @time_selection_end == nil
      show_popup_message "No AWR snapshots found for DBID = #{@dbid} #{" and Instance = #{@instance}" if @instance}"
      return
    end


    @hist = sql_select_iterator(["\
      SELECT /* Panorama-Tool Ramm */
             #{@begin_interval_sql}             Begin_Interval_Time,
             #{@end_interval_sql}               End_Interval_Time,
             MIN(snap.Begin_Interval_Time)      First_Occurrence,
             MAX(snap.End_Interval_Time)        Last_Occurrence,
             COUNT(DISTINCT s.Plan_Hash_Value)  Execution_Plans,
             MIN(Plan_Hash_Value)               First_Plan_Hash_Value,
             COUNT(DISTINCT s.Optimizer_Env_Hash_Value) Optimizer_Envs,
             MIN(Optimizer_Env_Hash_Value)      First_Opt_Env_Hash_Value,
             SUM(Executions_Delta)              Executions,
             SUM(Fetches_Delta)                 Fetches,
             SUM(Parse_Calls_Delta)             Parse_Calls,
             SUM(Sorts_Delta)                   Sorts,
             SUM(Loads_Delta)                   Loads,
             SUM(Elapsed_Time_Delta)/1000000    Elapsed_Time_Secs,
             SUM(ELAPSED_TIME_Delta/1000000) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) ELAPSED_TIME_SECS_PER_EXECUTE,
             SUM(Disk_Reads_Delta)              Disk_Reads,
             SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) DISK_READS_PER_EXECUTE,
             SUM(Executions_Delta) / DECODE(SUM(Disk_Reads_Delta), 0, 1, SUM(Disk_Reads_Delta)) Execs_Per_Disk,
             SUM(Buffer_Gets_Delta)             Buffer_Gets,
             SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_delta)) BUFFER_GETS_PER_Exec,
             SUM(BUFFER_GETS_delta) / DECODE(SUM(Rows_Processed_Delta), 0, 1, SUM(Rows_Processed_Delta)) BUFFER_GETS_PER_Row,
             SUM(Rows_Processed_Delta)          Rows_Processed,
             SUM(Rows_Processed_Delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) Rows_Processed_PER_EXECUTE,
             SUM(CPU_Time_Delta)/1000000        CPU_Time_Secs,
             SUM(ClWait_Delta)      /1000000    Cluster_Wait_Time_Secs,
             SUM(ApWait_Delta)      /1000000    Application_Wait_Time_secs,
             SUM(CCWait_Delta)      /1000000    Concurrency_Wait_Time_secs,
             SUM(IOWait_Delta)      /1000000    User_IO_Wait_Time_secs,
             SUM(PLSExec_Time_Delta)/1000000    PLSQL_Exec_Time_secs,
             100 * (SUM(s.Buffer_Gets_Delta) - SUM(s.Disk_Reads_Delta)) / GREATEST(SUM(s.Buffer_Gets_Delta), 1) Hit_Ratio,
             MIN(s.Snap_ID)                     Min_Snap_ID,
             MAX(s.Snap_ID)                     Max_Snap_ID
      FROM   DBA_Hist_SQLStat s
      JOIN   dba_hist_snapshot snap ON snap.DBID = s.DBID AND snap.Instance_Number= s.instance_number AND snap.Snap_ID = s.Snap_ID
      WHERE  s.DBID            = ?
      AND    s.SQL_ID          = ?
      AND    snap.End_Interval_time    > TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
      AND    snap.Begin_Interval_time  < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
      #{@parsing_schema_name ? "AND    s.Parsing_Schema_Name = ?" : ""  }
      #{@instance            ? "AND    s.Instance_Number     = ?" : ""  }
      GROUP BY #{@begin_interval_sql}, #{@end_interval_sql}
      ORDER BY #{@begin_interval_sql} DESC
      ", @dbid, @sql_id, @time_selection_start, @time_selection_end].
                               concat(@parsing_schema_name ? [@parsing_schema_name] : []).
                               concat(@instance            ? [@instance]            : [])
    )

    render_partial :list_sql_history_snapshots
  end #list_sql_history_snapshots

  # Ermittlung der Treffer
  def show_using_sqls_historic
    save_session_time_selection     # Werte puffern fuer spaetere Wiederverwendung
    @instance     = prepare_param_instance
    @dbid         = prepare_param_dbid
    @object_owner = params[:ObjectOwner]
    @object_owner = nil if @object_owner == ""
    @object_name = params[:ObjectName]

    where_filter = ""
    where_values = []
    if @instance
      where_filter << " AND s.Instance_Number = ?"
      where_values << @instance
    end
    if @object_owner
      where_filter << " AND p.Object_Owner=UPPER(?)"
      where_values << @object_owner
    end

    @sqls = sql_select_all ["
SELECT /* Panorama-Tool Ramm */
       (SELECT TO_CHAR(SUBSTR(SQL_Text,1,100)) FROM DBA_Hist_SQLText t WHERE t.DBID=sql.DBID AND t.SQL_ID=sql.SQL_ID) SQL_Text,
       sql.*
FROM (
        SELECT p.DBID, p.SQL_ID, s.Instance_Number, Parsing_Schema_Name, p.Operation, p.Options, p.Other_Tag,
               COUNT(DISTINCT s.Snap_ID)          Sample_Count,
               COUNT(DISTINCT CASE WHEN s.Plan_Hash_Value = 0 THEN NULL ELSE s.Plan_Hash_Value END) Plans,
               COUNT(DISTINCT s.Instance_number)  Instance_Count,
               MIN(snap.Begin_Interval_Time)      First_Occurrence,
               MAX(snap.End_Interval_Time)        Last_Occurrence,
               SUM(Executions_Delta)              Executions,
               SUM(Fetches_Delta)                 Fetches,
               SUM(Elapsed_Time_Delta)/1000000    Elapsed_Time_Secs,
               (SUM(ELAPSED_TIME_Delta)/1000000) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) ELAPSED_TIME_SECS_PER_EXECUTE,
               SUM(CPU_Time_Delta)/1000000        CPU_Time_Secs,
               SUM(Disk_Reads_Delta)              Disk_Reads,
                 SUM(DISK_READS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) DISK_READS_PER_EXECUTE,
               SUM(Buffer_Gets_Delta)             Buffer_Gets,
               SUM(BUFFER_GETS_delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_delta)) BUFFER_GETS_PER_EXEC,
               SUM(Rows_Processed_Delta)          Rows_Processed,
               SUM(Rows_Processed_Delta) / DECODE(SUM(EXECUTIONS_Delta), 0, 1, SUM(EXECUTIONS_Delta)) Rows_Processed_PER_EXECUTE,
               SUM(Parse_Calls_Delta)             Parse_Calls,
               MIN(s.Snap_ID)                     Min_Snap_ID,
               MAX(s.Snap_ID)                     Max_Snap_ID
        FROM   DBA_Hist_SQL_Plan p
        JOIN   DBA_Hist_SQLStat s ON s.DBID = p.DBID AND s.SQL_ID = p.SQL_ID AND s.Plan_Hash_Value = p.Plan_Hash_Value
        JOIN   DBA_Hist_Snapshot snap ON snap.DBID = s.DBID AND snap.Instance_Number = s.Instance_Number AND snap.Snap_ID = s.Snap_ID
        JOIN   (
                SELECT /*+ NO_MERGE*/ DBID, Instance_Number,
                       MAX(CASE WHEN Begin_Interval_time <= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') THEN Snap_ID ELSE NULL END) StartMin,      -- Normaler Start-Schnappschuss
                       MIN(CASE WHEN Begin_Interval_time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') THEN Snap_ID ELSE NULL END) StartMax,      -- alternativer Start-Schnappschuss wenn StartMin=NULL
                       MAX(CASE WHEN End_Interval_time <= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') THEN Snap_ID ELSE NULL END) EndMin,          -- alternativer End-Schnappschuss, wenn EndMin=NULL
                       MIN(CASE WHEN End_Interval_time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') THEN Snap_ID ELSE NULL END) EndMax           -- Normaler End-Schnappschuss
                FROM   DBA_Hist_Snapshot
                WHERE  DBID = ?
                GROUP BY Instance_Number, DBID
               ) snap_limit ON snap_limit.DBID = s.DBID AND snap_limit.Instance_Number = s.Instance_Number
        WHERE  p.Object_Name  LIKE UPPER(?) #{where_filter}
        AND    s.Snap_ID >= NVL(snap_limit.StartMin, snap_limit.StartMax)
        AND    s.Snap_ID <= NVL(snap_limit.EndMax,   snap_limit.EndMin)
        GROUP BY p.DBID, p.SQL_ID, s.Instance_Number, s.Parsing_Schema_Name, p.Operation, p.Options, p.Other_Tag
      ) sql
      ORDER BY sql.Elapsed_Time_Secs DESC",
    @time_selection_start, @time_selection_start, @time_selection_end, @time_selection_end, @dbid, @object_name].concat(where_values)

    render_partial :list_sql_area_historic

  end

  # Anzeigen der gefundenen Events
  def list_system_events_historic
    @instance  = prepare_param_instance
    @dbid      = prepare_param_dbid
    save_session_time_selection                  # Werte puffern fuer spaetere Wiederverwendung

    additional_where1 = ""
    additional_where2 = ""
    binds = [@dbid]  # 1. Bindevariable
    if @instance && @instance != 0
      additional_where1 << " AND Instance_Number = ? "
      binds << @instance
    end
    binds.concat [@time_selection_start, @time_selection_end]
    if params[:suppress_idle_waits]=='1'
      additional_where2 << " WHERE Wait_Class != 'Idle'"
    end

    @events = sql_select_iterator ["
      SELECT /* Panorama-Tool Ramm */ *
      FROM   (
              SELECT DBID, Instance_Number, Event_ID, MIN(Event_Name) Event_Name, MIN(Wait_Class) Wait_Class,
                     COUNT(*)                           Snapshots,
                     SUM(Waits)                         Waits,
                     SUM(Timeouts)                      Timeouts,
                     SUM(Time_Waited_Micro)/1000000     Time_Waited_Secs,
                     #{"\
                     SUM(Waits_FG)                      Waits_FG,
                     SUM(Timeouts_FG)                   Timeouts_FG,
                     SUM(Time_Waited_Micro_FG)/1000000  Time_Waited_Secs_FG,
                     " if get_db_version >= "11.1"}
                     MIN(Min_Snap_ID) Min_Snap_ID, MAX(Max_Snap_ID) Max_Snap_ID
              FROM   (
                      SELECT ev.DBID, ev.Instance_Number, ev.Snap_ID, ev.Event_Id, ss.Min_Snap_ID, ss.Max_Snap_ID,
                             ev.Event_Name, ev.Wait_Class,
                             Total_Waits        - LAG(Total_Waits,        1, Total_Waits)       OVER (PARTITION BY ev.Instance_Number, Event_ID ORDER BY Snap_ID) Waits,
                             Total_Timeouts     - LAG(Total_Timeouts,     1, Total_Timeouts)    OVER (PARTITION BY ev.Instance_Number, Event_ID ORDER BY Snap_ID) Timeouts,
                             Time_Waited_Micro  - LAG(Time_Waited_Micro,  1, Time_Waited_Micro) OVER (PARTITION BY ev.Instance_Number, Event_ID ORDER BY Snap_ID) Time_Waited_Micro
                             #{ "\
                             ,Total_Waits_FG        - LAG(Total_Waits_FG,        1, Total_Waits_FG)       OVER (PARTITION BY ev.Instance_Number, Event_ID ORDER BY Snap_ID) Waits_FG
                             ,Total_Timeouts_FG     - LAG(Total_Timeouts_FG,     1, Total_Timeouts_FG)    OVER (PARTITION BY ev.Instance_Number, Event_ID ORDER BY Snap_ID) Timeouts_FG
                             ,Time_Waited_Micro_FG  - LAG(Time_Waited_Micro_FG,  1, Time_Waited_Micro_FG) OVER (PARTITION BY ev.Instance_Number, Event_ID ORDER BY Snap_ID) Time_Waited_Micro_FG
                             " if get_db_version >= "11.1"
                             }
                      FROM   (SELECT DBID, Instance_Number, Min(Snap_ID) Min_Snap_ID, MAX(Snap_ID) Max_Snap_ID
                              FROM   DBA_Hist_Snapshot ss
                              WHERE  DBID = ? #{additional_where1}
                              AND    Begin_Interval_Time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                              AND    Begin_Interval_Time <= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                              GROUP BY DBID, Instance_Number
                             ) ss
                      JOIN   DBA_Hist_System_Event ev ON ev.DBID = ss.DBID AND ev.Instance_Number = ss.Instance_Number
                      WHERE  ev.Snap_ID BETWEEN ss.Min_Snap_ID-1 AND ss.Max_Snap_ID /* Vorgänger des ersten mit auswerten für Differenz per LAG */
                    ) hist
              WHERE  hist.Waits >= 0    /* Ersten Snap nach Reboot ausblenden */
              AND    hist.Snap_ID >= hist.Min_Snap_ID  /* Vorgaenger des ersten Snap fuer LAG wieder ausblenden */
              GROUP BY DBID, Instance_Number, Event_ID
             ) hist
      #{additional_where2}
      ORDER BY Time_waited_Secs DESC"].concat(binds)

    render_partial
  end

  # Anzeigen der Snapshots zum Event
  def list_system_events_historic_detail
    @instance  = prepare_param_instance
    @dbid      = prepare_param_dbid
    @event_id  = params[:event_id].to_i
    @event_name= params[:event_name]
    save_session_time_selection
    @min_snap_id = params[:min_snap_id].to_i
    @max_snap_id = params[:max_snap_id].to_i

    @snaps = sql_select_iterator ["
      SELECT /* Panorama-Tool Ramm */ snap.Begin_Interval_Time,
             Waits,
             Timeouts,
             Time_Waited_Micro/1000000 Time_Waited_Secs
             #{ "\
             , Waits_FG
             , Timeouts_FG
             , Time_Waited_Micro_FG/1000000 Time_Waited_Secs_FG" if get_db_version >= "11.1"}
      FROM   (
              SELECT Snap_ID,
                     Total_Waits        - LAG(Total_Waits,        1, Total_Waits)       OVER (PARTITION BY Event_ID ORDER BY Snap_ID) Waits,
                     Total_Timeouts     - LAG(Total_Timeouts,     1, Total_Timeouts)    OVER (PARTITION BY Event_ID ORDER BY Snap_ID) Timeouts,
                     Time_Waited_Micro  - LAG(Time_Waited_Micro,  1, Time_Waited_Micro) OVER (PARTITION BY Event_ID ORDER BY Snap_ID) Time_Waited_Micro
                     #{ "\
                     ,Total_Waits_FG        - LAG(Total_Waits_FG,        1, Total_Waits_FG)       OVER (PARTITION BY Event_ID ORDER BY Snap_ID) Waits_FG
                     ,Total_Timeouts_FG     - LAG(Total_Timeouts_FG,     1, Total_Timeouts_FG)    OVER (PARTITION BY Event_ID ORDER BY Snap_ID) Timeouts_FG
                     ,Time_Waited_Micro_FG  - LAG(Time_Waited_Micro_FG,  1, Time_Waited_Micro_FG) OVER (PARTITION BY Event_ID ORDER BY Snap_ID) Time_Waited_Micro_FG
                     " if get_db_version >= "11.1"
                     }
              FROM   DBA_Hist_System_Event
              WHERE DBID = ?
              AND   Instance_Number = ?
              AND   Event_ID = ?
              AND   Snap_ID BETWEEN ?-1 AND ? /* Vorgänger des ersten mit auswerten für Differenz per LAG */
             ) hist
      JOIN   DBA_Hist_Snapshot snap ON (snap.DBID = ? AND snap.Instance_Number = ? AND snap.Snap_ID = hist.Snap_ID)
      WHERE  hist.Waits >= 0    /* Ersten Snap nach Reboot ausblenden */
      AND    hist.Snap_ID BETWEEN ? AND ?
      ORDER BY hist.Snap_ID",
      @dbid, @instance, @event_id, @min_snap_id, @max_snap_id,
      @dbid, @instance, @min_snap_id, @max_snap_id ]

    render_partial
  end


  # Auswahl-Dialog
  def show_system_statistics_historic
    @statclasses = [{:bit=> nil, :name => "[All classes]"}]
    statistic_classes.each do |s|
      @statclasses << s
    end

    @statclasses.each do |s|
      s.extend SelectHashHelper
    end

    render_partial
  end

  # Anzeige Snaphots aus DBA_Hist_Sysstat
  def list_system_statistics_historic
    @instance  = prepare_param_instance
    @stat_class_bit = params[:stat_class][:bit]    # Bit-wert fuer Test auf Statistic-Klasse
    @stat_class_bit = nil if @stat_class_bit == ""

    save_session_time_selection                   # Werte puffern fuer spaetere Wiederverwendung

    list_system_statistics_historic_sum if params[:sum]
    list_system_statistics_historic_full if params[:full]
  end

  def list_system_statistics_historic_full
    trunc_tag = params[:verdichtung][:tag]

    additional_where = ""
    binds = [prepare_param_dbid]  # 1. Bindevariablen
    if @instance
      additional_where << " AND   Instance_Number = ? "
      binds << @instance
    end
    binds.concat [@time_selection_start, @time_selection_end]

    single_stats = sql_select_iterator ["
              SELECT /* Panorama-Tool Ramm */ TRUNC(so.Begin_Interval_Time, '#{trunc_tag}') Begin_Interval_Time, hist.Stat_ID, SUM(hist.Value) Value
              FROM   (
                      SELECT /*+ NO_MERGE */ ss.DBID, st.Instance_Number, st.Snap_ID, st.Stat_Id, ss.Min_Snap_ID,
                             Value - LAG(Value, 1, Value) OVER (PARTITION BY st.Instance_Number, st.Stat_ID ORDER BY Snap_ID) Value
                      FROM   (SELECT /*+ NO_MERGE */ DBID, Instance_Number, MIN(Snap_ID) Min_Snap_ID, MAX(Snap_ID) Max_Snap_ID
                              FROM   DBA_Hist_Snapshot ss
                              WHERE  DBID = ? #{additional_where}
                              AND    Begin_Interval_Time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                              AND    Begin_Interval_Time <= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                              GROUP BY DBID, Instance_Number
                             ) ss
                      JOIN   DBA_Hist_SysStat st ON st.DBID=ss.DBID AND st.Instance_Number=ss.Instance_Number
                      #{"JOIN v$StatName sn ON sn.Stat_ID = st.Stat_ID AND BITAND(sn.Class, #{@stat_class_bit.to_i}) = #{@stat_class_bit.to_i}" if @stat_class_bit}
                      WHERE  st.Snap_ID BETWEEN ss.Min_Snap_ID-1 AND ss.Max_Snap_ID /* Vorgänger des ersten mit auswerten für Differenz per LAG */
                    ) hist
              JOIN DBA_Hist_Snapshot so ON so.DBID = hist.DBID AND so.Instance_Number=hist.Instance_Number AND so.Snap_ID=hist.Snap_ID
              WHERE  hist.Value >= 0    /* Ersten Snap nach Reboot ausblenden */
              AND    hist.Snap_ID >= hist.Min_Snap_ID /* Vorgaenger des ersten Snap fuer LAG wieder ausblenden */
              GROUP BY TRUNC(so.Begin_Interval_Time, '#{trunc_tag}'), hist.Stat_ID
              ORDER BY 1, Stat_ID"].concat(binds)


    statnames = sql_select_all ["
              SELECT /* Panorama-Tool Ramm */ h.Stat_ID, h.Stat_Name, n.Class Class_ID
              FROM   DBA_Hist_Stat_Name h
              LEFT OUTER JOIN v$Statname n ON n.Name=h.Stat_Name
              WHERE  h.DBID=?
              ORDER BY n.Class, n.Statistic#", prepare_param_dbid ]


    @stats = []      # Komplettes Result
    rec = {}        # einzelner Record des Results
    columns = {}    # Verwendete Statistiken mit Value != 0
    ts = nil
    empty = true
    single_stats.each do |s|
      empty = false
      if ts != s.begin_interval_time
        @stats << rec if ts    # Wegschreiben des gebauten Records (ausser bei erstem Durchlauf)
        rec = {:begin_interval_time => s.begin_interval_time }              # Neuer Record
        ts = s.begin_interval_time                                          # Vergleichswert fur naechsten Record
      end
      rec[s.stat_id] = s.value if s.value != 0      # 0-Values nicht speichern
      columns[s.stat_id] = true if s.value != 0     # Statistik als verwendet kennzeichnen
    end
    @stats << rec  unless empty         # letzten Record wegschreiben, wenn Result exitierte

    column_options =
    [
      {:caption=>"Intervall",   :data=>"localeDateTime(rec[:begin_interval_time])", :title=>"Beginn des Zeitintervalls", :plot_master_time=>true }
    ]
    statnames.each do |sn|
      if columns[sn.stat_id]              # Statisik kommt auch im Result vor
        column_options << {:caption=>sn.stat_name, :data=>"formattedNumber(rec[#{sn.stat_id}] ? rec[#{sn.stat_id}] : 0)", :title=>"#{sn.stat_name} : class=\"#{statistic_class(sn.class_id)}\"", :align=>"right" }
      end
    end


    output = gen_slickgrid(@stats, column_options,
                     {:plot_area_id => "list_system_statistics_historic_plot_area",
                      :caption      => "System-Statistic from #{@time_selection_start} until #{@time_selection_end}",
                      :max_height   => 450,
                      #:div_style => "float:left; width:100%; max-height:450px; overflow:scroll;"
                     }
      )
    output << "<div id='list_system_statistics_historic_plot_area' style='float:left; width:100%;'></div>".html_safe

    respond_to do |format|
      format.html {render :html => output }
    end
  end

  def list_system_statistics_historic_sum
    additional_where = ""
    binds = [prepare_param_dbid]  # 1. Bindevariable
    if @instance 
      additional_where << " AND   Instance_Number = ? "
      binds << @instance
    end
    binds.concat [@time_selection_start, @time_selection_end]

    @statistics = sql_select_iterator ["
      SELECT /* Panorama-Tool Ramm */ name.Stat_Name, hist.Instance_Number, hist.Stat_ID, hist.Value, Min_Snap_ID, Max_Snap_ID, sn.Class Class_ID, hist.Snapshots
      FROM   (
              SELECT /*+ NO_MERGE*/ DBID, Instance_Number, Stat_ID,
                     SUM(Value) Value, MIN(Min_Snap_ID) Min_Snap_ID, MAX(Max_Snap_ID) Max_Snap_ID, COUNT(DISTINCT hist.Snap_ID) Snapshots
              FROM   (
                      SELECT /*+ NO_MERGE*/ st.DBID, st.Instance_Number, st.Snap_ID, st.Stat_Id, ss.Min_Snap_ID, ss.Max_Snap_ID,
                             Value - LAG(Value, 1, Value) OVER (PARTITION BY st.Instance_Number, st.Stat_ID ORDER BY Snap_ID) Value
                      FROM   (SELECT /*+ NO_MERGE*/ DBID, Instance_Number, Min(Snap_ID) Min_Snap_ID, MAX(Snap_ID) Max_Snap_ID
                              FROM   DBA_Hist_Snapshot ss
                              WHERE  DBID = ? #{additional_where}
                              AND    Begin_Interval_Time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                              AND    Begin_Interval_Time <= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                              GROUP BY DBID, Instance_Number
                             ) ss
                      JOIN   DBA_Hist_SysStat st ON st.DBID=ss.DBID AND st.Instance_Number=ss.Instance_Number
                      #{"JOIN v$StatName sn ON sn.Stat_ID = st.Stat_ID AND BITAND(sn.Class, #{@stat_class_bit.to_i}) = #{@stat_class_bit.to_i}" if @stat_class_bit}
                      WHERE  st.Snap_ID BETWEEN ss.Min_Snap_ID-1 AND ss.Max_Snap_ID /* Vorgänger des ersten mit auswerten für Differenz per LAG */
                    ) hist
              WHERE  hist.Value >= 0    /* Ersten Snap nach Reboot ausblenden */
              AND    hist.Snap_ID >= hist.Min_Snap_ID /* Vorgaenger des ersten Snap fuer LAG wieder ausblenden */
              GROUP BY DBID, Instance_Number, Stat_ID
             ) hist
      JOIN   DBA_Hist_Stat_Name name ON name.DBID=hist.DBID AND name.Stat_ID = hist.Stat_ID
      LEFT OUTER JOIN v$StatName sn ON sn.Stat_ID = hist.Stat_ID
      ORDER BY Value DESC"].concat(binds)

    render_partial :list_system_statistics_historic_sum
  end

  def list_system_statistics_historic_detail
    @instance  = prepare_param_instance
    @dbid      = prepare_param_dbid
    @stat_id   = params[:stat_id].to_i
    @stat_name = params[:stat_name]
    save_session_time_selection
    @min_snap_id = params[:min_snap_id].to_i
    @max_snap_id = params[:max_snap_id].to_i

    @snaps = sql_select_iterator ["
      SELECT /* Panorama-Tool Ramm */ snap.Begin_Interval_Time, snap.End_Interval_Time, Value
      FROM   (
              SELECT Snap_ID,
                     Value - LAG(Value, 1, Value) OVER (PARTITION BY Stat_ID ORDER BY Snap_ID) Value
              FROM   DBA_Hist_SysStat
              WHERE DBID = ?
              AND   Instance_Number = ?
              AND   Stat_ID = ?
              AND   Snap_ID BETWEEN ?-1 AND ? /* Vorgänger des ersten mit auswerten für Differenz per LAG */
             ) hist
      JOIN   DBA_Hist_Snapshot snap ON (snap.DBID = ? AND snap.Instance_Number = ? AND snap.Snap_ID = hist.Snap_ID)
      WHERE  hist.Value >= 0    /* Ersten Snap nach Reboot ausblenden */
      AND    hist.Snap_ID BETWEEN ? AND ?
      ORDER BY hist.Snap_ID",
      @dbid, @instance, @stat_id, @min_snap_id, @max_snap_id,
      @dbid, @instance, @min_snap_id, @max_snap_id ]

    column_options =
    [
      {:caption=>"Interval start",  :data=>proc{|rec| localeDateTime(rec.begin_interval_time)}, :title=>"Begin of interval", :plot_master_time=>true },
      {:caption=>"Interval end",    :data=>proc{|rec| localeDateTime(rec.end_interval_time)},   :title=>"End of interval" },
      {:caption=>"Value",           :data=>proc{|rec| formattedNumber(rec.value)},              :title=>"Value of statistic between start and end of considered period", :align=>"right"},
    ]

    output = gen_slickgrid(@snaps, column_options,
                     {:plot_area_id => "list_system_statistics_historic_detail_plot_area",
                      :caption      =>"System statistic \"#{@stat_name}\" instance=#{@instance} from #{@time_selection_start} until #{@time_selection_end}",
                      :max_height   => 450
                     }
      )
    output << "<div id='list_system_statistics_historic_detail_plot_area' style='float:left; width:100%;'></div>".html_safe

    respond_to do |format|
      format.html {render :html => output }
    end
  end


  def list_sysmetric_historic
    @instance  = prepare_param_instance
    @dbid      = prepare_param_dbid
    trunc_tag = params[:grouping][:tag]
    save_session_time_selection                   # Werte puffern fuer spaetere Wiederverwendung

    time_expression = "TRUNC(Begin_Time, '#{trunc_tag}')"   # Default- TRUNC
    time_expression = "Begin_Time" if trunc_tag == "SS"     # Bei Sekunden nicht weiter verdichten, sondern kleinstes Korn nehmen

    additional_where = ""
    binds = [@dbid]  # 1. Bindevariablen
    binds.concat [@time_selection_start, @time_selection_end, @time_selection_end]
    if @instance
      additional_where << " AND   Instance_Number = ? "
      binds << @instance
    end

    case
      when params["detail"] then
        caption_add = "SysMetric_History"
        stmt = "      WITH MinTS AS (SELECT /*+ MATERIALIZE */ Inst_ID, MIN(Begin_Time) Min_Begin_Time
                                     FROM   gv$SysMetric_History
                                     GROUP BY Inst_ID)
                      SELECT /* Panorama-Tool Ramm */
                             #{time_expression} Begin_Time,
                             Metric_ID, Metric_Name, Metric_Unit,
                             AVG(Value)                        Value,
                             MIN(Value)                        MinValue,
                             MAX(Value)                        MaxValue
                      FROM   (SELECT Begin_Time, End_Time, Instance_Number,
                                     Metric_ID, Metric_Name, Metric_Unit, Value
                              FROM   DBA_Hist_SysMetric_History h
                              JOIN   MinTS t ON t.Inst_ID = h.Instance_Number
                              WHERE  h.Begin_Time < t.Min_Begin_Time
                              AND    DBID = ?
                              AND    Group_ID = 2 -- System Metrics Long Duration
                              UNION ALL
                              SELECT Begin_Time, End_Time, Inst_ID Instance_Number,
                                     Metric_ID, Metric_Name, Metric_Unit, Value
                              FROM   gv$SysMetric_History
                              WHERE  Group_ID = 2 -- System Metrics Long Duration
                             )
                      WHERE  Begin_Time >= TO_DATE(?, '#{sql_datetime_minute_mask}')
                      AND    Begin_Time  < TO_DATE(?, '#{sql_datetime_minute_mask}') -- Hilfe fuer Index-Zugriff, größter beginn auf alle Faelle vor groesstem Ende
                      AND    End_Time   <= TO_DATE(?, '#{sql_datetime_minute_mask}')
                      #{additional_where}
                      GROUP BY #{time_expression} , Metric_ID, Metric_Name, Metric_Unit
                      ORDER BY 1, Metric_ID"
      when params["summary"] then
        caption_add = "SysMetric_Summary"
        stmt = "      WITH MinTS AS (SELECT Inst_ID, MIN(Begin_Time) Min_Begin_Time
                                     FROM   gv$SysMetric_Summary
                                     GROUP BY Inst_ID)
                      SELECT /* Panorama-Tool Ramm */
                             #{time_expression} Begin_Time,
                             Metric_ID, Metric_Name, Metric_Unit,
                             AVG(Average)                      Value,
                             MIN(MinVal)                       MinValue,
                             MAX(MaxVal)                       MaxValue
                      FROM   (SELECT Begin_Time, End_Time, Instance_Number,
                                     Metric_ID, Metric_Name, Metric_Unit, Average, MinVal, MaxVal
                              FROM   DBA_Hist_SysMetric_Summary h
                              JOIN   MinTS t ON t.Inst_ID = h.Instance_Number
                              WHERE  h.Begin_Time < t.Min_Begin_Time
                              AND    DBID = ?
                              AND    Group_ID = 2 -- System Metrics Long Duration
                              UNION ALL
                              SELECT Begin_Time, End_Time, Inst_ID Instance_Number,
                                     Metric_ID, Metric_Name, Metric_Unit, Average, MinVal, MaxVal
                              FROM   gv$SysMetric_Summary
                              WHERE  Group_ID = 2 -- System Metrics Long Duration
                             )
                      WHERE  Begin_Time >= TO_DATE(?, '#{sql_datetime_minute_mask}')
                      AND    Begin_Time  < TO_DATE(?, '#{sql_datetime_minute_mask}') -- Hilfe fuer Index-Zugriff, größter beginn auf alle Faelle vor groesstem Ende
                      AND    End_Time   <= TO_DATE(?, '#{sql_datetime_minute_mask}')
                      #{additional_where}
                      GROUP BY #{time_expression} , Metric_ID, Metric_Name, Metric_Unit
                      ORDER BY 1, Metric_ID"
      else
        raise "Wrong button pressed"
    end


    single_stats = sql_select_iterator [stmt].concat(binds)

    @stats = []                                                                 # Komplettes Result
    record = {}                                                                 # einzelner Record des Results
    columns = {}                                                                # Verwendete Statistiken mit Value != 0
    ts = nil
    empty = true
    single_stats.each do |s|
      empty = false
      if ts != s.begin_time
        @stats << record if ts                                                  # Wegschreiben des gebauten Records (ausser bei erstem Durchlauf)
        record = {:begin_time => s.begin_time }                                 # Neuer Record
        ts = s.begin_time                                                       # Vergleichswert fur naechsten Record
      end
      record[s.metric_id] = {:value=>s.value, :minvalue=>s.minvalue, :maxvalue=>s.maxvalue } if s.value != 0    # 0-Values nicht speichern
      columns[s.metric_id] = {:metric_name=>s.metric_name, :metric_unit=>s.metric_unit} if s.value != 0   # Statistik als verwendet kennzeichnen
    end
    @stats << record  unless empty                                              # letzten Record wegschreiben, wenn Result exitierte

    column_options =
    [
      {:caption=>"Intervall",   :data=>proc{|rec| localeDateTime(rec[:begin_time]) }, :title=>"Beginn des Zeitintervalls", :plot_master_time=>true }
    ]
    columns.each do |key, value|
      column_options << {:caption=>value[:metric_name], :data=>proc{|rec| formattedNumber(rec[key] ? rec[key][:value] : 0, 2) }, :title=>"#{value[:metric_name]}: #{value[:metric_unit]}", :data_title=>proc{|rec| rec[key] ? "#{value[:metric_name]}: #{value[:metric_unit]}: min.value=#{formattedNumber(rec[key][:minvalue],2)}, max.value=#{formattedNumber(rec[key][:maxvalue],2)}" : ""}, :align=>"right" }
    end

    output = gen_slickgrid(@stats, column_options,
                     {:plot_area_id => "list_sysmetric_historic_plot_area",
                      :caption      => "SysMetric von #{@time_selection_start} bis #{@time_selection_end} aus #{caption_add}",
                      :max_height   => 450
                     }
      )
    output << "<div id='list_sysmetric_historic_plot_area' style='float:left; width:100%;'></div>".html_safe

    respond_to do |format|
      format.html {render :html => output }
    end
  end

  def list_latch_statistics_historic
    @instance  = prepare_param_instance
    @dbid      = prepare_param_dbid
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung


    where_string  = ""                         # Filter-Text für nachfolgendes Statement
    where_values = [@dbid, @time_selection_start, @time_selection_end, @dbid]    # Filter-werte für nachfolgendes Statement
    if @instance
      where_string << " AND l.Instance_Number = ?"
      where_values << @instance
    end

    @latches = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
             x.*,
             x.Misses*100/DECODE(x.GetsNo, 0, 1, x.GetsNo) Pct_Misses,
             x.Immediate_Misses*100/DECODE(x.Immediate_Gets, 0, 1, x.Immediate_Gets) Pct_Immediate_Misses
      FROM   (SELECT
                     l.Instance_Number,
                     l.Latch_Hash,
                     l.Latch_Name,
                     l.Level# LevelNo,
                     COUNT(*)-1                 Anzahl_Samples,         -- mitgelesenen Vorgänger-Sample der Selektion wieder abziehen
                     MIN(snap.First_Occurrence) First_Occurrence,       -- Pseudo-Group-Funktion, Werte in Gruppe sind alle identisch
                     MAX(snap.Last_Occurrence)  Last_Occurrence,        -- Pseudo-Group-Funktion, Werte in Gruppe sind alle identisch
                     MAX(l.Gets)             KEEP (DENSE_RANK LAST ORDER BY l.Snap_ID) - MIN(l.Gets)             KEEP (DENSE_RANK FIRST ORDER BY l.Snap_ID) GetsNo,
                     MAX(l.Misses)           KEEP (DENSE_RANK LAST ORDER BY l.Snap_ID) - MIN(l.Misses)           KEEP (DENSE_RANK FIRST ORDER BY l.Snap_ID) Misses,
                     MAX(l.Sleeps)           KEEP (DENSE_RANK LAST ORDER BY l.Snap_ID) - MIN(l.Sleeps)           KEEP (DENSE_RANK FIRST ORDER BY l.Snap_ID) Sleeps,
                     MAX(l.Immediate_Gets)   KEEP (DENSE_RANK LAST ORDER BY l.Snap_ID) - MIN(l.Immediate_Gets)   KEEP (DENSE_RANK FIRST ORDER BY l.Snap_ID) Immediate_Gets,
                     MAX(l.Immediate_Misses) KEEP (DENSE_RANK LAST ORDER BY l.Snap_ID) - MIN(l.Immediate_Misses) KEEP (DENSE_RANK FIRST ORDER BY l.Snap_ID) Immediate_Misses,
                     MAX(l.Spin_Gets)        KEEP (DENSE_RANK LAST ORDER BY l.Snap_ID) - MIN(l.Spin_Gets)        KEEP (DENSE_RANK FIRST ORDER BY l.Snap_ID) Spin_Gets,
                     MAX(l.Sleep1)           KEEP (DENSE_RANK LAST ORDER BY l.Snap_ID) - MIN(l.Sleep1)           KEEP (DENSE_RANK FIRST ORDER BY l.Snap_ID) Sleep1,
                     MAX(l.Sleep2)           KEEP (DENSE_RANK LAST ORDER BY l.Snap_ID) - MIN(l.Sleep2)           KEEP (DENSE_RANK FIRST ORDER BY l.Snap_ID) Sleep2,
                     MAX(l.Sleep3)           KEEP (DENSE_RANK LAST ORDER BY l.Snap_ID) - MIN(l.Sleep3)           KEEP (DENSE_RANK FIRST ORDER BY l.Snap_ID) Sleep3,
                     MAX(l.Sleep4)           KEEP (DENSE_RANK LAST ORDER BY l.Snap_ID) - MIN(l.Sleep4)           KEEP (DENSE_RANK FIRST ORDER BY l.Snap_ID) Sleep4,
                     (MAX(l.Wait_Time)       KEEP (DENSE_RANK LAST ORDER BY l.Snap_ID) - MIN(l.Wait_Time)        KEEP (DENSE_RANK FIRST ORDER BY l.Snap_ID) )/1000000 Wait_Time,
                     MIN(snap.Min_Snap_ID)      Min_Snap_ID,            -- Pseudo-Group-Funktion, Werte in Gruppe sind alle identisch
                     MAX(snap.Max_Snap_ID)      Max_Snap_ID             -- Pseudo-Group-Funktion, Werte in Gruppe sind alle identisch
              FROM   DBA_Hist_Latch l
              JOIN   (SELECT Instance_Number,
                             MIN(Snap_ID) Min_Snap_ID,
                             MAX(Snap_ID) Max_Snap_ID,
                             MIN(Begin_Interval_Time) First_Occurrence,
                             MAX(Begin_Interval_Time) Last_Occurrence
                      FROM   DBA_Hist_Snapshot
                      WHERE  DBID = ?
                      AND    Begin_Interval_time > TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                      AND    Begin_Interval_time < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                      GROUP BY Instance_Number
                     ) snap ON snap.Instance_Number = l.Instance_Number
              WHERE  l.DBID = ?
              AND    l.Snap_ID+1 >= snap.Min_Snap_ID
              AND    l.Snap_ID   <= snap.Max_Snap_ID #{where_string}
              GROUP BY l.Latch_Name, l.Latch_Hash, l.Level#, l.Instance_Number
             ) x
      ORDER BY x.Wait_time DESC
     "
     ].concat(where_values)

    render_partial
  end # list_latch_statistics_historic

  def list_latch_statistics_historic_details
    @instance   = prepare_param_instance
    @dbid       = prepare_param_dbid
    latch_hash  = params[:latch_hash]
    @latch_name = params[:latch_name]
    min_snap_id = params[:min_snap_id].to_i
    max_snap_id = params[:max_snap_id].to_i


    @latches = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
             x.*,
             x.Misses*100/DECODE(x.GetsNo, 0, 1, x.GetsNo) Pct_Misses,
             x.Immediate_Misses*100/DECODE(x.Immediate_Gets, 0, 1, x.Immediate_Gets) Pct_Immediate_Misses
      FROM   (SELECT
                     snap.Begin_Interval_Time,
                     l.Snap_ID,
                     l.gets             - LAG(l.gets,             1, l.gets            ) OVER (ORDER BY l.Snap_ID) GetsNo,
                     l.misses           - LAG(l.misses,           1, l.misses          ) OVER (ORDER BY l.Snap_ID) Misses,
                     l.sleeps           - LAG(l.sleeps,           1, l.sleeps          ) OVER (ORDER BY l.Snap_ID) Sleeps,
                     l.Immediate_Gets   - LAG(l.Immediate_Gets,   1, l.Immediate_Gets  ) OVER (ORDER BY l.Snap_ID) Immediate_Gets,
                     l.Immediate_Misses - LAG(l.Immediate_Misses, 1, l.Immediate_Misses) OVER (ORDER BY l.Snap_ID) Immediate_Misses,
                     l.Spin_Gets        - LAG(l.Spin_Gets,        1, l.Spin_Gets       ) OVER (ORDER BY l.Snap_ID) Spin_Gets,
                     l.Sleep1           - LAG(l.Sleep1,           1, l.Sleep1          ) OVER (ORDER BY l.Snap_ID) Sleep1,
                     l.Sleep2           - LAG(l.Sleep2,           1, l.Sleep2          ) OVER (ORDER BY l.Snap_ID) Sleep2,
                     l.Sleep3           - LAG(l.Sleep3,           1, l.Sleep3          ) OVER (ORDER BY l.Snap_ID) Sleep3,
                     l.Sleep4           - LAG(l.Sleep4,           1, l.Sleep4          ) OVER (ORDER BY l.Snap_ID) Sleep4,
                     (l.Wait_Time       - LAG(l.Wait_Time,        1, l.Wait_Time       ) OVER (ORDER BY l.Snap_ID) )/1000000Wait_Time
              FROM   DBA_Hist_Latch l
              JOIN   DBA_Hist_Snapshot snap ON snap.DBID=l.DBID AND snap.Instance_Number=l.Instance_Number AND snap.Snap_ID=l.Snap_ID
              WHERE  l.dbid = ?
              AND    l.Instance_Number = ?
              AND    l.Snap_ID+1 >= ?         -- Letzten Sample vor Selektion mit holen, um Differenz zu erstem Sample der Selektion zu bilden
              AND    l.Snap_ID <= ?
              AND    l.Latch_Hash = ?
             ) x
      WHERE Snap_ID >= ?
      ORDER BY Snap_ID
     ", @dbid, @instance, min_snap_id, max_snap_id, latch_hash, min_snap_id
     ]

    render_partial :list_latch_statistics_historic_detail
  end # list_latch_statistics_historic_details


  def list_mutex_statistics_historic
    @instance  = prepare_param_instance
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung
    list_mutex_statistics_historic_blocker_waiter(:Blocking_Session)      if params[:Blocker]
    list_mutex_statistics_historic_blocker_waiter(:Requesting_Session)    if params[:Waiter]
    list_mutex_statistics_historic_Timeline                               if params[:Timeline]
  end

  def list_mutex_statistics_historic_blocker_waiter(groupby)
    @groupby = groupby
    @mutexes = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */ *
      FROM   (
              SELECT Inst_ID, Mutex_Type,  #{@groupby},
                     MIN(Sleep_Timestamp)  First_Occurrence,
                     MAX(Sleep_Timestamp)  Last_Occurrence,
                     SUM(Gets)             Gets,
                     SUM(Sleeps)           Sleeps,
                     SUM(Sleeps)/SUM(Gets) Sleep_Ratio,
                     COUNT(*)              Samples
              FROM   GV$Mutex_Sleep_History
              WHERE  Sleep_Timestamp >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
              AND    Sleep_Timestamp  < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
              #{@instance ? "AND Inst_ID=#{@instance}" : ""}
              GROUP BY Inst_ID, Mutex_Type, #{@groupby}
             )
      ORDER BY Sleeps DESC", @time_selection_start, @time_selection_end]

    render_partial :list_mutex_statistics_historic_blocker_waiter
  end

  def list_mutex_statistics_historic_Timeline
    @mutexes = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */ TRUNC(Sleep_Timestamp, 'MI') ts,
             MIN(CAST (Sleep_Timestamp AS DATE))  MinSleepTimestamp,
             MAX(CAST (Sleep_Timestamp AS DATE))  MaxSleepTimestamp,
             SUM(Gets)             Gets,
             SUM(Sleeps)           Sleeps,
             SUM(Sleeps)/SUM(Gets) Sleep_Ratio,
             COUNT(*)              Samples
      FROM   GV$Mutex_Sleep_History
              WHERE  Sleep_Timestamp >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
              AND    Sleep_Timestamp  < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
              #{@instance ? "AND Inst_ID=#{@instance}" : ""}
      GROUP BY TRUNC(Sleep_Timestamp, 'MI')
      ORDER BY TRUNC(Sleep_Timestamp, 'MI')", @time_selection_start, @time_selection_end]

    render_partial :list_mutex_statistics_historic_timeline
  end


  # Anzeige der Einzel-Records
  def list_mutex_statistics_historic_samples
    @instance  = prepare_param_instance
    @time_selection_start = params[:time_selection_start]
    @time_selection_end   = params[:time_selection_end]
    #save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung

    where_string  = ""                         # Filter-Text für nachfolgendes Statement
    where_values = [@time_selection_start, @time_selection_end]    # Filter-werte für nachfolgendes Statement
    if @instance
      where_string << " AND Inst_ID = ?"
      where_values << @instance
    end
    if params[:mutex_type]
      where_string << " AND Mutex_Type = ?"
      where_values << params[:mutex_type]
    end
    if params[:filter_value]
      where_string << " AND #{params[:filter]} = ?"
      where_values << params[:filter_value]
    end

    @res = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ Inst_ID, Mutex_Identifier, Sleep_Timestamp,
             Mutex_Type, Gets, Sleeps, Requesting_Session, Blocking_Session, Location, RawToHex(Mutex_Value) Mutex_Value,
             P1, RawToHex(P1Raw) P1Raw, P2, P3, P4, P5
      FROM   GV$Mutex_Sleep_History
      WHERE  CAST(Sleep_Timestamp AS DATE) >= TO_DATE(?, '#{sql_datetime_second_mask}')
      AND    CAST(Sleep_Timestamp AS DATE) <= TO_DATE(?, '#{sql_datetime_second_mask}')
      #{where_string}
      ORDER BY Sleep_Timestamp"].concat(where_values)

    respond_to do |format|
      format.html {render :partial=>"dragnet/list_dragnet_sql_result" }
    end
  end

  def list_enqueue_statistics_historic
    @instance  = prepare_param_instance
    @dbid      = prepare_param_dbid
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung


    where_string  = ""                         # Filter-Text für nachfolgendes Statement
    where_values = [@dbid, @time_selection_start, @time_selection_end, @dbid]    # Filter-werte für nachfolgendes Statement
    if @instance
      where_string << " AND h.Instance_Number = ?"
      where_values << @instance
    end

    @enqueues = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
             x.*,
             s.Req_Description
      FROM   (SELECT
                     h.Instance_Number,
                     h.Event#                   EventNo,
                     COUNT(*)-1                 Anzahl_Samples,         -- mitgelesenen Vorgänger-Sample der Selektion wieder abziehen
                     MIN(snap.First_Occurrence) First_Occurrence,       -- Pseudo-Group-Funktion, Werte in Gruppe sind alle identisch
                     MAX(snap.Last_Occurrence)  Last_Occurrence,        -- Pseudo-Group-Funktion, Werte in Gruppe sind alle identisch
                     MIN(h.EQ_Type)             EQ_Type,
                     MIN(h.Req_Reason)          Req_Reason,
                     MAX(h.Total_Req#)       KEEP (DENSE_RANK LAST ORDER BY h.Snap_ID) - MIN(h.Total_Req#)       KEEP (DENSE_RANK FIRST ORDER BY h.Snap_ID) Total_Req,
                     MAX(h.Total_Wait#)      KEEP (DENSE_RANK LAST ORDER BY h.Snap_ID) - MIN(h.Total_Wait#)      KEEP (DENSE_RANK FIRST ORDER BY h.Snap_ID) Total_Wait,
                     MAX(h.Succ_Req#)        KEEP (DENSE_RANK LAST ORDER BY h.Snap_ID) - MIN(h.Succ_Req#)        KEEP (DENSE_RANK FIRST ORDER BY h.Snap_ID) Succ_Req,
                     MAX(h.Failed_Req#)      KEEP (DENSE_RANK LAST ORDER BY h.Snap_ID) - MIN(h.Failed_Req#)      KEEP (DENSE_RANK FIRST ORDER BY h.Snap_ID) Failed_Req,
                     MAX(h.Cum_Wait_Time)    KEEP (DENSE_RANK LAST ORDER BY h.Snap_ID) - MIN(h.Cum_Wait_Time)    KEEP (DENSE_RANK FIRST ORDER BY h.Snap_ID) Cum_Wait_Time,
                     MIN(snap.Min_Snap_ID)      Min_Snap_ID,            -- Pseudo-Group-Funktion, Werte in Gruppe sind alle identisch
                     MAX(snap.Max_Snap_ID)      Max_Snap_ID             -- Pseudo-Group-Funktion, Werte in Gruppe sind alle identisch
              FROM   DBA_Hist_Enqueue_Stat h
              JOIN   (SELECT Instance_Number,
                             MIN(Snap_ID) Min_Snap_ID,
                             MAX(Snap_ID) Max_Snap_ID,
                             MIN(Begin_Interval_Time) First_Occurrence,
                             MAX(Begin_Interval_Time) Last_Occurrence
                      FROM   DBA_Hist_Snapshot
                      WHERE  DBID = ?
                      AND    Begin_Interval_time > TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                      AND    Begin_Interval_time < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                      GROUP BY Instance_Number
                     ) snap ON snap.Instance_Number = h.Instance_Number
              WHERE  h.DBID = ?
              AND    h.Snap_ID+1 >= snap.Min_Snap_ID
              AND    h.Snap_ID   <= snap.Max_Snap_ID #{where_string}
              GROUP BY h.Event#, h.Instance_Number
             ) x
      LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Event#, Req_Description FROM v$Enqueue_statistics) s ON s.Event# = x.EventNo
      ORDER BY x.Cum_Wait_Time DESC
     "
     ].concat(where_values)

    render_partial
  end # list_enqueue_statistics_historic

  def list_enqueue_statistics_historic_details
    @instance   = prepare_param_instance
    @dbid       = prepare_param_dbid
    @eventno    = params[:eventno]
    @reason     = params[:reason]
    @description= params[:description]
    min_snap_id = params[:min_snap_id].to_i
    max_snap_id = params[:max_snap_id].to_i


    @enqueues = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
             x.*
      FROM   (SELECT
                     snap.Begin_Interval_Time,
                     h.Snap_ID,
                     h.total_req#       - LAG(h.total_req#,       1, h.total_req#      ) OVER (ORDER BY h.Snap_ID) Total_Req,
                     h.total_wait#      - LAG(h.total_wait#,      1, h.total_wait#     ) OVER (ORDER BY h.Snap_ID) total_wait,
                     h.Succ_Req#        - LAG(h.Succ_Req#,        1, h.Succ_Req#       ) OVER (ORDER BY h.Snap_ID) Succ_Req,
                     h.Failed_Req#      - LAG(h.Failed_Req#,      1, h.Failed_Req#     ) OVER (ORDER BY h.Snap_ID) Failed_Req,
                     h.Cum_Wait_Time    - LAG(h.Cum_Wait_Time,    1, h.Cum_Wait_Time   ) OVER (ORDER BY h.Snap_ID) Cum_Wait_Time
              FROM   DBA_Hist_Enqueue_Stat h
              JOIN   DBA_Hist_Snapshot snap ON snap.DBID=h.DBID AND snap.Instance_Number=h.Instance_Number AND snap.Snap_ID=h.Snap_ID
              WHERE  h.dbid = ?
              AND    h.Instance_Number = ?
              AND    h.Snap_ID+1 >= ?         -- Letzten Sample vor Selektion mit holen, um Differenz zu erstem Sample der Selektion zu bilden
              AND    h.Snap_ID <= ?
              AND    h.Event# = ?
             ) x
      WHERE Snap_ID >= ?
      ORDER BY Snap_ID
     ", @dbid, @instance, min_snap_id, max_snap_id, @eventno, min_snap_id
     ]

    render_partial :list_enqueue_statistics_historic_detail
  end # list_enqueue_statistics_historic_details


  # Vergleich der SQL-Statements zweier Tage
  def list_compare_sql_area_historic
    @minProzDiff= params[:minProzDiff].to_i
    @tag1       = params[:tag1]
    @tag2       = params[:tag2]
    @instance   = prepare_param_instance
    @filter     = params[:filter]
    @filter = nil if @filter == ""
    @sql_id     = params[:sql_id]
    @sql_id = nil if @sql_id == ""

    # !!! Kein Filter auf DBID in diesem SQL, damit nach Abzug und Neuaufbau einer DB die Historien miteinander verglichen werden können
    where_string = " WHERE TRUNC(ss.Begin_Interval_Time) = TO_TIMESTAMP(?, '#{sql_datetime_date_mask}') "
    where_string_global = ""
    where_values1 = [@tag1]
    where_values2 = [@tag2]
    where_values_global = []

    if @instance
      where_string << " AND s.Instance_Number = ? "
      where_values1 << @instance
      where_values2 << @instance
    end

    if @sql_id
      where_string << " AND s.SQL_ID = ? "
      where_values1 << @sql_id
      where_values2 << @sql_id
    end

    if @filter
      where_string_global << " AND UPPER(t.SQL_Text) LIKE '%'||UPPER(?)||'%' "
      where_values_global << @filter
    end


    @diffs = sql_select_all ["\
             SELECT /*+ Panorama-Tool Ramm */
                    GREATEST(t1.Instance_Count,t2.Instance_Count) Instance_Count,
                    LEAST(t1.Min_Instance_Number, t2.Min_Instance_Number) Min_Instance_Number,
                    t1.Min_Instance_Number Min_Instance_Number_t1,
                    t2.Min_Instance_Number Min_Instance_Number_t2,
                    t1.SQL_ID, t1.Parsing_Schema_Name,
                    t.SQL_text,
                    -- Anzahl Plaene, gleiche Plaene an beiden Tagen nur als einen zaehlen, daher -1
                    t1.Execution_Plan_Count + t2.Execution_Plan_Count -
                        CASE WHEN t1.Max_Plan_Hash_Value = t2.Max_Plan_Hash_Value
                              AND t1.Execution_Plan_Count != 0
                              AND t2.Execution_Plan_Count != 0
                        THEN 1 ELSE 0 END Execution_Plan_Count,
                    t1.DBID         DBID_t1,
                    t2.DBID         DBID_t2,
                    t1.Elapsed_Time Elapsed_Time_t1,
                    t2.Elapsed_Time Elapsed_Time_t2,
                    t1.Executions   Executions_t1,
                    t2.Executions   Executions_t2,
                    t1.Elapsed_Time/t1.Executions Elapsed_Per_Exec_t1,
                    t2.Elapsed_Time/t2.Executions Elapsed_Per_Exec_t2,
                    t1.Rows_Processed Rows_Processed_t1,
                    t2.Rows_Processed Rows_Processed_t2,
                    t1.Min_Snap_ID  Min_Snap_ID_t1,
                    t1.Max_Snap_ID  Max_Snap_ID_t1,
                    t2.Min_Snap_ID  Min_Snap_ID_t2,
                    t2.Max_Snap_ID  Max_Snap_ID_t2
             FROM   (
                     SELECT COUNT(DISTINCT s.Instance_Number) Instance_Count,
                            MIN(s.Instance_Number) Min_Instance_Number,
                            s.SQL_ID, s.DBID, s.Parsing_Schema_Name,
                            MAX(s.Plan_Hash_Value) Max_Plan_Hash_Value,
                            COUNT(DISTINCT CASE WHEN s.Plan_Hash_Value = 0 THEN NULL ELSE s.Plan_Hash_Value END) Execution_Plan_Count,
                            SUM(s.Elapsed_Time_Delta) Elapsed_Time,
                            SUM(Executions_Delta)     Executions,
                            SUM(Rows_Processed_Delta) Rows_Processed,
                            MIN(ss.Snap_ID)           Min_Snap_ID,
                            MAX(ss.Snap_ID)           Max_Snap_ID
                     FROM   DBA_Hist_Snapshot ss 
                     JOIN   DBA_Hist_SQLStat s ON s.DBID = ss.DBID AND s.Instance_Number = ss.Instance_Number AND s.Snap_ID = ss.Snap_ID
                     #{where_string}
                     GROUP BY s.SQL_ID, s.DBID, s.Parsing_Schema_Name
                     HAVING SUM(Executions_Delta) > 0
                    ) t1
             JOIN   (
                     SELECT COUNT(DISTINCT s.Instance_Number) Instance_Count,
                            MIN(s.Instance_Number) Min_Instance_Number,
                            s.SQL_ID, s.DBID, s.Parsing_Schema_Name,
                            MAX(s.Plan_Hash_Value) Max_Plan_Hash_Value,
                            COUNT(DISTINCT CASE WHEN s.Plan_Hash_Value = 0 THEN NULL ELSE s.Plan_Hash_Value END) Execution_Plan_Count,
                            SUM(s.Elapsed_Time_Delta) Elapsed_Time,
                            SUM(Executions_Delta)     Executions,
                            SUM(Rows_Processed_Delta) Rows_Processed,
                            MIN(ss.Snap_ID)           Min_Snap_ID,
                            MAX(ss.Snap_ID)           Max_Snap_ID
                     FROM   DBA_Hist_Snapshot ss
                     JOIN   DBA_Hist_SQLStat s ON s.DBID = ss.DBID AND s.Instance_Number = ss.Instance_Number AND s.Snap_ID = ss.Snap_ID
                     #{where_string}
                     GROUP BY s.SQL_ID, s.DBID, s.Parsing_Schema_Name
                     HAVING SUM(Executions_Delta) > 0
                    ) t2 ON t1.SQL_ID = t2.SQL_ID AND t1.Parsing_Schema_Name = t2.Parsing_Schema_Name
             JOIN   DBA_Hist_SQLText t ON t.DBID = t1.dbID AND t.SQL_ID = t1.SQL_ID
             WHERE  (   (t2.Elapsed_time/t2.Executions)  / (t1.Elapsed_Time/t1.Executions) <  (100-?)/100
                     OR (t2.Elapsed_time/t2.Executions)  / (t1.Elapsed_Time/t1.Executions) >  100/(100-?)
                    )
             #{where_string_global}
             ORDER BY ABS(t2.Elapsed_Time/t2.Executions - t1.Elapsed_Time/t1.Executions) * t2.Executions DESC
             "].concat(where_values1).concat(where_values2).concat([@minProzDiff, @minProzDiff]).concat(where_values_global)

    render_partial
  end

  # SQL Short-Text als JSON liefern, Action wird ohne DB-Connection gestartet !!!
  def getSQL_ShortText
    if params && params[:sql_id]
      response = {:sql_short_text => get_cached_sql_shorttext_by_sql_id(params[:sql_id])}
    else
      response = {:sql_short_text => 'params[:sql_id] missing in request! Cannot read SQL details.'}
    end
    response = response.to_json
    render :json => response, :status => 200
  end


  def show_resource_limits_historic
    @names = sql_select_all 'SELECT /* Panorama-Tool Ramm */ DISTINCT Resource_Name FROM DBA_Hist_Resource_Limit'
    if @names.length == 0
      show_popup_message("No content available in DBA_Hist_Resource_Limit for your connection!
For PDB please connect to database with CDB-user instead of PDB-user.")
    else
      render_partial
    end
  end

  def list_resource_limits_historic
    @instance  = prepare_param_instance
    @dbid      = prepare_param_dbid
    @resource_name = params[:resource][:name]
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung

    @limits = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
             ROUND(ss.End_Interval_Time, 'MI')    End_Interval,
             SUM(rl.Current_Utilization)          Current_Utilization,
             SUM(rl.Max_Utilization)              Max_Utilization,
             SUM(rl.Initial_Allocation)           Initial_Allocation,
             SUM(rl.Limit_Value)                  Limit_Value
      FROM   DBA_Hist_Snapshot ss
      JOIN   (SELECT DBID, Snap_ID, Instance_Number, Current_Utilization, Max_Utilization,
                     CASE WHEN TRIM(Initial_Allocation) = 'UNLIMITED' THEN -1 ELSE TO_NUMBER(Initial_Allocation) END Initial_Allocation,
                     CASE WHEN TRIM(Limit_Value)        = 'UNLIMITED' THEN -1 ELSE TO_NUMBER(Limit_Value)        END Limit_Value
              FROM   DBA_Hist_Resource_Limit
              WHERE  Resource_Name = ?
             ) rl ON rl.DBID=ss.DBID AND rl.Snap_ID=ss.Snap_ID AND rl.Instance_Number=ss.Instance_Number
      WHERE  ss.End_Interval_time > TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
      AND    ss.End_Interval_time < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
      #{ @instance ? " AND ss.Instance_Number=#{@instance}" : ''}
      GROUP BY ROUND(ss.End_Interval_Time, 'MI')
      ORDER BY ROUND(ss.End_Interval_Time, 'MI') DESC
     ", @resource_name, @time_selection_start, @time_selection_end ]

    render_partial
  end

  private
  # min und max. Snap_ID für gegebenen Zeitraum und Instance (nullable)
  # belegt Instanzvariablen
  def get_min_max_snapshot(instance, time_selection_start, time_selection_end)
    @min_snap_id = sql_select_one ["SELECT MAX(Snap_ID)
                                   FROM   DBA_Hist_Snapshot
                                   WHERE  DBID = ?
                                   AND    Begin_Interval_Time < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                                   #{' AND Instance_Number = ?' if instance}
                                  ", get_dbid, time_selection_start].concat(instance ? [instance] : [])
    if @min_snap_id.nil?                                                      # Ersten Snap nehmen wenn keiner zum start gefunden
      @min_snap_id = sql_select_one ["SELECT MIN(Snap_ID)
                                      FROM   DBA_Hist_Snapshot
                                      WHERE  DBID = ?
                                      #{' AND Instance_Number = ?' if instance}
                                     ", get_dbid].concat(instance ? [instance] : [])
    end

    @max_snap_id = sql_select_one ["SELECT MIN(Snap_ID)
                                   FROM   DBA_Hist_Snapshot
                                   WHERE  DBID = ?
                                   AND    End_Interval_Time > TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                                   #{' AND Instance_Number = ?' if instance}
                                   ", get_dbid, time_selection_end].concat(instance ? [instance] : [])

    if @max_snap_id.nil?                                                        # Letzten Snap nehmen wenn keiner zum Endezeitpunkt gefunden
      @max_snap_id = sql_select_one ["SELECT MAX(Snap_ID)
                                     FROM   DBA_Hist_Snapshot
                                     WHERE  DBID = ?
                                    #{' AND Instance_Number = ?' if instance}
                                     ", get_dbid].concat(instance ? [instance] : [])

    end

    raise PopupMessageException.new("No AWR snapshots are found for your database / instance!") if @min_snap_id.nil? || @max_snap_id.nil?
    raise PopupMessageException.new("Only one or less AWR snapshots found for time period '#{time_selection_start}' until '#{time_selection_end}' and instance=#{instance}.") if @min_snap_id >= @max_snap_id
  end

  public

  def list_awr_report_html
    save_session_time_selection   # werte in session puffern
    @instance  = prepare_param_instance

    get_min_max_snapshot(@instance, @time_selection_start, @time_selection_end)

    @report = sql_select_iterator ["SELECT output FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(?, ?, ?, ?))",
                                   get_dbid, @instance, @min_snap_id, @max_snap_id]
    res_array = []
    @report.each do |r|
      res_array << r.output
    end
    render :html => res_array.join.html_safe
  end

  def list_awr_global_report_html
    save_session_time_selection   # werte in session puffern
    @instance  = prepare_param_instance

    get_min_max_snapshot(@instance, @time_selection_start, @time_selection_end)

    @report = sql_select_iterator ["SELECT output FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_GLOBAL_REPORT_HTML(?, #{@instance ? '?' : 'CAST(NULL AS VARCHAR2(20))'}, ?, ?))",
                                   get_dbid].concat(@instance ? [@instance] : []).concat([@min_snap_id, @max_snap_id])
    res_array = []
    @report.each do |r|
      res_array << r.output
    end
    render :html => res_array.join.html_safe
  end

  def list_ash_report_html
    save_session_time_selection   # werte in session puffern
    @instance  = prepare_param_instance

    @report = sql_select_iterator ["SELECT output FROM TABLE(DBMS_WORKLOAD_REPOSITORY.ASH_REPORT_HTML(?, ?,
                                                                TO_DATE(?, '#{sql_datetime_minute_mask}'),
                                                                TO_DATE(?, '#{sql_datetime_minute_mask}')
                                                            ))",
                                   get_dbid, @instance, @time_selection_start, @time_selection_end]
    res_array = []
    @report.each do |r|
      res_array << r.output
    end
    render :html => res_array.join.html_safe
  end

  def list_ash_global_report_html
    save_session_time_selection   # werte in session puffern
    @instance  = prepare_param_instance

    @report = sql_select_iterator ["SELECT output FROM TABLE(DBMS_WORKLOAD_REPOSITORY.ASH_GLOBAL_REPORT_HTML(?, #{@instance ? '?' : 'NULL'},
                                                                TO_DATE(?, '#{sql_datetime_minute_mask}'),
                                                                TO_DATE(?, '#{sql_datetime_minute_mask}')
                                                            ))",
                                   get_dbid].concat(@instance ? [@instance] : []).concat([@time_selection_start, @time_selection_end])
    res_array = []
    @report.each do |r|
      res_array << r.output
    end
    render :html => res_array.join.html_safe
  end


  def list_awr_sql_report_html
    save_session_time_selection   # werte in session puffern
    @instance  = prepare_param_instance
    @sql_id    = params[:sql_id]

    get_min_max_snapshot(@instance, @time_selection_start, @time_selection_end)

    @report = sql_select_iterator ["SELECT output FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_SQL_REPORT_HTML(?, ?, ?, ?, ?))",
                                   get_dbid, @instance, @min_snap_id, @max_snap_id, @sql_id]
    res_array = []
    @report.each do |r|
      res_array << r.output
    end
    render :html => res_array.join.html_safe
  end

  def select_plan_hash_value_for_baseline
    @sql_id                     = params[:sql_id]
    @min_snap_id                = params[:min_snap_id]
    @max_snap_id                = params[:max_snap_id]
    @force_matching_signature   = params[:force_matching_signature]
    @exact_matching_signature   = params[:exact_matching_signature]

    @plans = sql_select_all ["SELECT s.Plan_Hash_Value,
                                    MIN(ss.Begin_Interval_Time) First_Occurrence,
                                    MAX(ss.End_Interval_Time) Last_Occurrence,
                                    SUM(s.Executions_Delta) Executions,
                                    SUM(s.Elapsed_Time_Delta)/1000000 Elapsed_Secs,
                                    SUM(s.Rows_Processed_Delta) Rows_Processed
                             FROM   DBA_Hist_SQLStat s
                             JOIN   DBA_Hist_Snapshot ss ON ss.DBID = s.DBID AND ss.Instance_Number = s.Instance_Number AND ss.Snap_ID = s.Snap_ID
                             WHERE  s.DBID   = ?
                             AND    S.SQL_ID = ?
                             AND    s.Snap_ID BETWEEN ? AND ?
                             GROUP BY s.Plan_Hash_Value
                            ", get_dbid, @sql_id, @min_snap_id, @max_snap_id]
      render_partial
  end

  def generate_baseline_creation
    sql_id                      = params[:sql_id]
    min_snap_id                 = params[:min_snap_id].to_i
    max_snap_id                 = params[:max_snap_id].to_i
    plan_hash_value             = params[:plan_hash_value]
    force_matching_signature    = params[:force_matching_signature]
    exact_matching_signature    = params[:exact_matching_signature]


    sts_name = 'PANORAMA_STS'

    snap_corrected_warning = ''
    if min_snap_id == max_snap_id
      min_snap_id -= 1
      snap_corrected_warning = "\n-- End snapshot ID (#{max_snap_id}) must be greater than begin snapshot ID ((#{max_snap_id}).\nTherfore begin snapshot ID has been adjusted to #{min_snap_id}!\n\n"
    end

    result = "
-- Build SQL plan baseline for SQL-ID = '#{sql_id}', plan hash value = #{plan_hash_value}
-- Generated with Panorama at #{Time.now}
-- based on idea from rmoff (https://rnm1978.wordpress.com/?s=baseline)

-- to create a SQL-baseline execute this PL/SQL snippet as SYSDBA in SQL*Plus
#{snap_corrected_warning}

SET SERVEROUTPUT ON;

DECLARE
  cur           sys_refcursor;
  hit_count     PLS_INTEGER;
  sql_handle    VARCHAR2(30);
  plan_name     VARCHAR2(30);
BEGIN
  -- Drop eventually existing SQL Tuning Set (STS)
  BEGIN
    DBMS_SQLTUNE.DROP_SQLSET(sqlset_name => '#{sts_name}');
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  -- Drop eventually existing previous baselines for this statement
  FOR Rec IN (SELECT SQL_Handle, Plan_Name FROM DBA_SQL_Plan_Baselines WHERE Signature = #{force_matching_signature})
  LOOP
    hit_count := DBMS_SPM.DROP_SQL_PLAN_BASELINE (SQL_Handle => Rec.SQL_Handle, Plan_Name => Rec.Plan_Name);
  END LOOP;

  -- Create new SQL Tuning Set (STS)
  DBMS_SQLTUNE.CREATE_SQLSET(sqlset_name => '#{sts_name}', description => 'Panorama: SQL Tuning Set for loading plan into SQL Plan Baseline');

  -- Populate STS from AWR, using a time duration when the desired plan was used
  --  Specify the sql_id in the basic_filter (other predicates are available, see documentation)
  OPEN cur FOR
    SELECT VALUE(P)
    FROM TABLE(
       DBMS_SQLTUNE.Select_Workload_Repository(Begin_Snap=>#{min_snap_id}, End_Snap=>#{max_snap_id}, Basic_Filter=>'sql_id = ''#{sql_id}''',attribute_list=>'ALL')
              ) p;
     DBMS_SQLTUNE.LOAD_SQLSET( sqlset_name=> '#{sts_name}', populate_cursor=>cur);
  CLOSE cur;

  -- Load desired plan from STS as SQL Plan Baseline
  -- Filter explicitly for the plan_hash_value here
  hit_count := DBMS_SPM.LOAD_PLANS_FROM_SQLSET(sqlset_name => '#{sts_name}', Basic_Filter=>'plan_hash_value = ''#{plan_hash_value}''');

  -- Drop SQL Tuning Set (STS) which is not needed no more
  DBMS_SQLTUNE.DROP_SQLSET(sqlset_name => '#{sts_name}');
  -- if you want to check the result of the tunning set than comment out DBMS_SQLTUNE.DROP_SQLSET and execute
  -- SELECT * FROM TABLE(DBMS_SQLTUNE.SELECT_SQLSET(sqlset_name => '#{sts_name}'));

  -- Get access criteria for the new created baseline based on exact- or force-signature
  SELECT SQL_Handle, Plan_Name INTO sql_handle, plan_name FROM DBA_SQL_Plan_Baselines
  WHERE  (Signature = #{force_matching_signature} OR Signature = #{exact_matching_signature})
  AND    Created > SYSDATE-0.1;

  -- Set this baseline as fixed
  hit_count := DBMS_SPM.ALTER_SQL_PLAN_BASELINE(SQL_Handle => sql_handle, Plan_Name => plan_name, Attribute_Name => 'fixed', Attribute_Value => 'YES');

  -- Set the description according to your choice (max. 500 chars)
  hit_count := DBMS_SPM.ALTER_SQL_PLAN_BASELINE(SQL_Handle => sql_handle, Plan_Name => plan_name, Attribute_Name => 'description', Attribute_Value => 'Baseline generated by Panorama ...');
END;
/

-- You can check the existence of the baseline now by executing:
-- SELECT * FROM dba_sql_plan_baselines;
-- or by looking at SQL details page for your SQL with Panorama
"
    cursors = sql_select_all(["SELECT Inst_ID, RAWTOHEX(Address) Address, Hash_Value FROM gv$SQLArea WHERE SQL_ID=?", sql_id])
    if cursors.count > 0
      result << "
-- Next commands remove the current existing cursors of this SQL from SGA to ensure hard parse with SQL plan baseline at next execution
-- If you are working on a RAC system you should execute this 'DBMS_SHARED_POOL.PURGE'-commands once again connected on the appropriate RAC-instance
      "
    end
    cursors.each do |r|
      result << "-- For instance = #{r.inst_id}:
exec DBMS_SHARED_POOL.PURGE ('#{r.address}, #{r.hash_value}', 'C');
"
    end

    result << "
-- ######### to remove an existing SQL plan baseline execute the following:
-- Get the SQL-Handle of your baseline from Panorama's selections or by
-- SELECT * FROM dba_sql_plan_baselines WHERE SQL_Text LIKE '%<your SQL>%';

-- Drop all baselines of the SQL with the given SQL-Handle
-- DECLARE
--   v_dropped_plans number;
-- BEGIN
--   v_dropped_plans := DBMS_SPM.DROP_SQL_PLAN_BASELINE (sql_handle => 'SQL_b6b0d1c71cd1807b');
--   DBMS_OUTPUT.PUT_LINE('dropped ' || v_dropped_plans || ' plans');
-- END;
-- /

"

    respond_to do |format|
      format.html {render :html => "<pre class='yellow-panel' style='white-space: pre-wrap; padding: 10px;'>#{my_html_escape(result)}</pre>".html_safe }
    end
  end

end #DbaHistoryController
