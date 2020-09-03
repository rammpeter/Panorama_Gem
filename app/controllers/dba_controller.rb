# encoding: utf-8
class DbaController < ApplicationController

  include DbaHelper

  def show_locks
    @dml_count = sql_select_first_row "
      SELECT COUNT(*) DML_Count, SUM(CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0 THEN 1 ELSE 0 END) Blocking_DML_Count
      FROM   gv$Lock l
      JOIN   gv$session s ON s.Inst_ID = l.Inst_ID AND s.SID = l.SID
      WHERE  s.type          = 'USER'
      AND    l.Type NOT IN ('AE', 'PS')
    "

    begin
      @ddl_count = sql_select_one "SELECT /* Panorama-Tool Ramm */ COUNT(*)
                                  FROM  dba_kgllock w,
                                        dba_kgllock h
                                  WHERE   (((h.kgllkmod != 0)     and (h.kgllkmod != 1)
                                  and     ((h.kgllkreq = 0) or (h.kgllkreq = 1)))
                                  and     (((w.kgllkmod = 0) or (w.kgllkmod= 1))
                                  and     ((w.kgllkreq != 0) and (w.kgllkreq != 1))))
                                  and     w.kgllktype             = h.kgllktype
                                  and     w.kgllkhdl              = h.kgllkhdl
      "
    rescue Exception => e                                                       # Skip ORA-7445 during select
      @ddl_count = nil
      add_statusbar_message("Error skipped while counting the number of DDL-Locks:\n#{e.message}")
    end

    @pending_2pc_count = sql_select_one "SELECT COUNT(*) FROM DBA_2PC_Pending"

    render_partial
  end

  def list_dml_locks
    show_all_locks = params[:show_all_locks]
    
    @max_result_size = params[:max_result_size].to_i

    where_string =  ''
    where_values = []

    if params[:id1]
      where_string << " AND l.ID1 = ?"
      where_values << params[:id1].to_i
    end

    if params[:id2]
      where_string << " AND l.ID2 = ?"
      where_values << params[:id2].to_i
    end


    @dml_locks = sql_select_all(["\
      WITH RawLock AS (SELECT /*+ MATERIALIZE NO_MERGE */ * FROM gv$Lock)
      SELECT /* Panorama-Tool Ramm */ *
      FROM   (
              SELECT /*+ ORDERED */
                RowNum                                                      ,
                l.Inst_ID                                                   Instance_Number,
                s.SID,
                s.Serial#                                                   SerialNo,
                s.SQL_ID, s.SQL_Child_Number,
                s.Prev_SQL_ID, s.Prev_Child_Number, l.Inst_ID,
                s.Status                                                    Status,
                s.Client_Info, s.Module, s.Action,
                LOWER(lo.Owner)                                             Locked_Object_Owner,
                lo.Object_Name                                              Locked_Object_Name,
                lo.SubObject_Name                                           Locked_SubObject_Name,
                lo.Object_Type                                              Locked_Object_Type,
                x.XIDUSN                                                    Rollback_Segment,
                s.Inst_ID||':'||p.spID||':'||s.UserName                     InstPIDUser,
                s.machine||'('||s.OSUser||'):'||s.Process||':'||s.program   MaschinePIDProgFull,
                SUBSTR(s.machine||'('||s.OSUser||'):'||s.Process||':'||s.program,1,20) MaschinePIDProg,
                l.Type                                                      LockType,
                CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0  THEN   /* Waiting for Lock */
                    o.Owner||'.'||o.Object_Name
                END                                                         WaitingForObject,
                o.Data_Object_ID,
                s.Row_Wait_File#                                            Row_Wait_File_No,
                s.Row_Wait_Block#                                           Row_Wait_Block_No,
                s.Row_Wait_Row#                                             Row_Wait_Row_No,
                #{get_db_version < '11.1' ? "s.Seconds_In_Wait" : "DECODE(s.State, 'WAITING', s.Wait_Time_Micro, s.Time_Since_Last_Wait_Micro)/1000000"} WaitingForTime,
                l.ctime                                                     Lock_Held_Seconds,
                SUBSTR(l.ID1||':'||l.ID2,1,12)                              ID1ID2,
                /* Request!=0 indicates waiting for resource determinded by ID1, ID2 */
                TO_CHAR(l.Request)                                          Request,
                TO_CHAR(l.lmode)                                            LockMode,
                RowNum      /* fuer Ajax-Aktualisierung der Zeile */        Row_Num,
               bs.Inst_ID             Blocking_Instance_Number,
               bs.SID                 Blocking_SID,
               bs.Serial#             Blocking_SerialNo
              FROM    RawLock l
              JOIN    gv$session s              ON s.Inst_ID = l.Inst_ID AND s.SID = l.SID
              JOIN    GV$Process p              ON p.Inst_ID = s.Inst_ID AND p.Addr = s.pAddr
              LEFT OUTER JOIN gv$Session bs     ON bs.Inst_ID = s.Blocking_Instance AND bs.SID = s.Blocking_Session
              LEFT OUTER JOIN DBA_Objects lo    ON lo.Object_ID = l.ID1  -- locked object
              LEFT OUTER JOIN gv$Transaction x  ON x.Inst_ID = s.Inst_ID AND x.Addr = s.TAddr
              -- Join über dem Wait bekanntes Object, alternativ über der session bekanntes Objekt auf das gewartet wird
              -- Bei Request = 3 enthaelt row_wait_obj# zuweilen das vorherige Objekt statt des aktuellen, in dem Falle ist auch die RowID Murks
              LEFT OUTER JOIN DBA_Objects o     ON o.Object_ID = DECODE(s.P2Text, 'object #', s.P2, DECODE(s.Row_Wait_Obj#, -1, NULL, s.Row_Wait_Obj#))  -- Objekt, auf das gewartet wird wenn existiert
              WHERE   s.type          = 'USER'
              #{where_string}
            )
      #{show_all_locks ? "" : " WHERE LockType NOT IN ('AE', 'PS') "  }  -- Type-Filter ausserhalb des Selects weil sonst auf Exadata/11g utopische Laufzeiten wegen Cartesian Join
      ORDER BY Inst_ID, SID, Locked_Object_Name
      "].concat(where_values))
    @result_size = @dml_locks.length       # Tatsaechliche anzahl Zeilen im Result

    # Entfernen der ueberzaehligen Zeilen des Results
    @dml_locks.delete_at(@dml_locks.length-1) while @dml_locks.length > @max_result_size 

    render_partial :list_dml_locks
  end # list_dml_locks

  def list_blocking_dml_locks

    @locks = sql_select_all "\
      WITH RawLock AS (SELECT /*+ MATERIALIZE NO_MERGE */ * FROM gv$Lock),
           Locks AS (
              SELECT /*+ LEADING(l) */ /* Panorama-Tool Ramm */
                     l.Inst_ID,
                     s.SID,
                     s.Serial# SerialNo,
                     s.SQL_ID,
                     s.SQL_Child_Number,
                     s.Status, s.Event,
                     s.Client_Info,
                     s.Module,
                     s.Action,
                     CASE
                     WHEN l.Type='TM' THEN /* Locked Object for TM */
                          (SELECT o.Owner||'.'||o.object_name FROM sys.dba_objects o WHERE l.id1=o.object_id)
                     WHEN l.Type='TX' THEN /* Used Rollback Segment for TX */
                          (SELECT DECODE(Count(*),1,'','Multi:')||MIN(SUBSTR('RBS:'||x.XIDUSN,1,18)) FROM GV$Transaction x WHERE x.Addr=s.TAddr)
                     END ObjectName,
                     s.UserName,
                     s.machine,
                     s.OSUser,
                     s.Process,
                     s.program,
                     l.Type LockType,
                     bo.Owner               Blocking_Object_Schema,
                     bo.Object_Name         Blocking_Object_Name,
                     bo.SubObject_Name      Blocking_SubObject_Name,
                     bo.Data_Object_ID,
                     s.Row_Wait_File#       Row_Wait_File_No,
                     s.Row_Wait_Block#      Row_Wait_Block_No,
                     s.Row_Wait_Row#        Row_Wait_Row_No,
                     #{get_db_version < '11.1' ? "s.Seconds_In_Wait" : "s.Wait_Time_Micro/1000000"} Seconds_Waiting,
                     l.ID1,
                     l.ID2,
                     /* Request!=0 indicates waiting for resource determinded by ID1, ID2 */
                     l.Request Request,
                     l.lmode   LockMode,
                     s.Blocking_Instance    Blocking_Instance_Number,
                     s.Blocking_Session     Blocking_SID,
                     bs.Serial#             Blocking_SerialNo,
                     bs.Status              Blocking_Status,
                     bs.Event               Blocking_Event,
                     bs.Client_Info         Blocking_Client_Info,
                     bs.Module              Blocking_Module,
                     bs.Action              Blocking_Action,
                     bs.UserName            Blocking_UserName,
                     bs.Machine             Blocking_Machine,
                     bs.OSUser              Blocking_OSUser,
                     bs.Process             Blocking_Process,
                     bs.Program             Blocking_Program
               FROM RawLock l
               JOIN gv$session s ON s.Inst_ID = l.Inst_ID AND s.SID = l.SID
               LEFT OUTER JOIN gv$Session bs ON bs.Inst_ID = s.Blocking_Instance AND bs.SID = s.Blocking_Session
               -- Object der blockenden Session
               LEFT OUTER JOIN sys.DBA_Objects bo ON bo.Object_ID = CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0 THEN /* Waiting for Lock */
                                                                         CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Objekt */ s.P2
                                                                         ELSE CASE WHEN s.Row_Wait_Obj# != -1 THEN /* Session kennt Objekt */   s.Row_Wait_Obj#
                                                                              ELSE NULL
                                                                              END
                                                                         END
                                                                    END
               WHERE s.type = 'USER'
               AND   l.Type != 'PS'
               AND   s.LockWait IS NOT NULL
               AND   l.Request  != 0
              ),
      HLocks AS (
              SELECT /*+ NO_MERGE */ RowNum Row_Num, Level HLevel, l.*,
                     CONNECT_BY_ROOT Blocking_Instance_Number Root_Blocking_Instance_Number,
                     CONNECT_BY_ROOT Blocking_SID             Root_Blocking_SID,
                     CONNECT_BY_ROOT Blocking_SerialNo        Root_Blocking_SerialNo
              FROM   Locks l
              CONNECT BY NOCYCLE PRIOR  sid     = blocking_sid
                             AND PRIOR Inst_ID  = blocking_instance_number
                             AND PRIOR serialno = blocking_serialNo
             )
      SELECT l.*, NULL Waiting_App_Desc, NULL Blocking_App_Desc
      FROM   HLocks l
      -- Jede Zeile nur einmal unter der Root-Hierarchie erscheinen lassen, nicht als eigenen Knoten
      WHERE NOT EXISTS (SELECT 1 FROM HLocks t
                        WHERE  t.sid      = l.sid
                        AND    t.Inst_ID  = l.Inst_ID
                        AND    t.SerialNo = l.SerialNo
                        AND    t.HLevel   > l.HLevel
                       )
       ORDER BY Row_Num"

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    @locks.each {|l|
      l.waiting_app_desc = explain_application_info(l.module)
      l.blocking_app_desc = explain_application_info(l.blocking_module)
    }

    render_partial :list_blocking_dml_locks
  end

  def list_pending_two_phase_commits
    @dist_locks = sql_select_all "\
      SELECT /* Panorama-Tool Ramm */
             Local_Tran_ID,
             Global_tran_ID,
             State, Mixed, Advice, Tran_Comment,
             Fail_Time, Force_Time, Retry_Time,
             OS_User, OS_Terminal, Host, DB_User,
             Commit# Commit_No
      FROM   DBA_2PC_Pending"

    render_partial
  end

  def list_2pc_neighbors
    @local_tran_id = prepare_param(:local_tran_id)

    @neighbors = sql_select_iterator ["SELECT * FROM DBA_2PC_Neighbors WHERE Local_Tran_ID = ?", @local_tran_id]
    render_partial
  end

  def convert_to_rowid
    @data_object_id = params[:data_object_id]

    @rowid = sql_select_one ["SELECT RowIDTOChar(DBMS_RowID.RowID_Create(1, ?, ?, ?, ?)) FROM DUAL",
                             params[:data_object_id].to_i,
                             params[:row_wait_file_no].to_i,
                             params[:row_wait_block_no].to_i,
                             params[:row_wait_row_no].to_i
                            ]

    render_partial :list_rowid_link
  end

  # Anzeige der ApplInfo auf Basis der Client_Info aus v$session
  def explain_info
    @info = params[:info]

    res = explain_application_info(@info)
    if res[:short_info]
      res_string = "#{res[:short_info]} : #{res[:long_info]}"
    else
      res_string = "No info available"
    end

    respond_to do |format|
      format.html {render :html => res_string }
    end
  end

  def list_ddl_locks

    #@max_result_size = params[:max_result_size].to_i

    @ddl_locks = sql_select_all("\
      SELECT /*+ ordered */ /* Panorama-Tool Ramm */
        hs.Inst_ID                                                  B_Inst_ID,
        hs.SID                                                      B_SID,
        hs.Serial#                                                  B_SerialNo,
        hs.Status                                                   B_Status,
        hp.spID                                                     B_PID,
        hs.UserName                                                 B_User,
        hs.Machine                                                  B_Machine,
        hs.OSUser                                                   B_OSUser,
        hs.Process                                                  B_Process,
        hs.Program                                                  B_Program,
        ws.Inst_ID                                                  W_Inst_ID,
        ws.SID                                                      W_SID,
        ws.Serial#                                                  W_SerialNo,
        wp.spID                                                     W_PID,
        ws.UserName                                                 W_User,
        ws.Machine                                                  W_Machine,
        ws.OSUser                                                   W_OSUser,
        ws.Process                                                  W_Process,
        ws.Program                                                  W_Program,
        w.kgllktype                                                 LockType,
        od.TO_Owner                                                 Object_Owner,
        od.TO_Name                                                  Object_Name,
        decode(h.kgllkmod,  0, 'None', 1, 'Null', 2, 'Share', 3, 'Exclusive', 'Unknown') mode_held,
        decode(w.kgllkreq,  0, 'None', 1, 'Null', 2, 'Share', 3, 'Exclusive', 'Unknown') mode_requested
      FROM  dba_kgllock w
      JOIN  dba_kgllock h                     ON h.kgllktype = w.kgllktype AND h.kgllkhdl = w.kgllkhdl
      JOIN  GV$session ws                     ON ws.saddr = w.kgllkuse
      JOIN  GV$session hs                     ON hs.saddr = h.kgllkuse
      JOIN  GV$Process wp                     ON wp.Addr = ws.pAddr AND wp.Inst_ID = ws.Inst_ID
      JOIN  GV$Process hp                     ON hp.Addr = hs.pAddr AND hp.Inst_ID = hs.Inst_ID
      LEFT OUTER JOIN (SELECT DISTINCT TO_Address, TO_Owner, TO_Name FROM v$Object_dependency) od  ON od.TO_ADDRESS = w.kgllkhdl /* v$Object_dependency may have multiple redundant entries */
      WHERE   (((h.kgllkmod != 0)     and (h.kgllkmod != 1)
      and     ((h.kgllkreq = 0) or (h.kgllkreq = 1)))
      and     (((w.kgllkmod = 0) or (w.kgllkmod= 1))
      and     ((w.kgllkreq != 0) and (w.kgllkreq != 1))))
      ")

    #@result_size = @ddl_locks.length       # Tatsaechliche anzahl Zeilen im Result

    # Entfernen der ueberzaehligen Zeilen des Results
    #@ddl_locks.delete_at(@ddl_locks.length-1) while @ddl_locks.length > @max_result_size

    render_partial :list_ddl_locks
  end # list_ddl_locks

  # Extrahieren des PKey und seines Wertes für RowID
  def show_rowid_details
    rowid     = params[:waitingforrowid]

    object_rec = sql_select_first_row ["\
                   SELECT Owner, Object_Name, SubObject_Name, Object_Type
                   FROM   DBA_Objects
                   WHERE  Data_Object_ID = ?
                   ",
                   params[:data_object_id]]

    unless object_rec
      show_popup_message "No object found for Data_Object_ID=#{params[:data_object_id]}"
      return
    end

    if object_rec.object_type.match("INDEX")
      table_name = sql_select_first_row(["\
                     SELECT Table_Name
                     FROM   DBA_Indexes
                     WHERE  Owner = ?
                     AND    Index_Name = ?",
                     object_rec.owner, object_rec.object_name]).table_name
    else
      table_name = object_rec.object_name
    end

    pstmt = sql_select_all ["\
             SELECT Column_Name                                              
             FROM   DBA_Ind_Columns
             WHERE  Index_Owner   = ?
             AND    Index_Name =                                             
                    (SELECT Index_Name                                       
                     FROM   DBA_Constraints
                     WHERE  Owner      = ?
                     AND    Table_Name = UPPER(?)
                     AND    Constraint_Type = 'P'                            
                    )", object_rec.owner, object_rec.owner, table_name]
    if pstmt.length == 0
      show_popup_message "No primary key found for object '#{object_rec.owner}.#{object_rec.object_name} / table #{table_name}"
      return
    end

    # Ermittlung der Primary-Key-Spalten der Tabelle
    pkey_cols = ""
    first = true
    pstmt.each do |s| 
      if first
        first = false
      else
        pkey_cols << ", "
      end
      pkey_cols << s.column_name
    end

    begin
      pkey_vals = sql_select_first_row ["SELECT #{pkey_cols} FROM #{object_rec.owner}.#{table_name} WHERE RowID=?", rowid]
    rescue Exception => e
      show_popup_message "Error accessing data for RowID='#{rowid}'\n\n#{e.message}"
      return
    end
    raise PopupMessageException.new("No data found for SQL:\n\n#{pkey_sql}\n\nParameter RowID = '#{rowid}'") if pkey_vals.length == 0

    result = "#{t(:table, :default=>'table')} #{table_name}, PKey (#{pkey_cols}) = "

    pstmt.each_index do |i|
      column_value = pkey_vals[pstmt[i].column_name.downcase]
      delimiter = ''
      delimiter = "'" if [String, DateTime, Date, Time].include? column_value.class
      result << "#{delimiter}#{column_value}#{delimiter}"
      result << ", " if i < pkey_vals.count-1
    end

    respond_to do |format|
      format.html {render :html => result }
    end
  end # show_lock_details

  def show_redologs
    @instance = prepare_param_instance

    @redologs = sql_select_iterator("\
      SELECT /* Panorama-Tool Ramm */
        Inst_ID,
        TO_CHAR(Group#) GroupNo,                                
        Bytes/(1024*1024) MByte,
        Status,                                                 
        First_Time,
        #{"(Next_Time - First_Time) * 86400 Log_Switch_Interval_Secs," if get_db_version >= '11.1'}
        Members, Archived
      FROM gV$LOG
      WHERE Inst_ID = Thread#  -- im gv$-View werden jeweils die Logs der anderen Instanzen noch einmal in jeder Instance mit Thread# getzeigt, dies verhindert die Dopplung
      #{"AND Inst_ID = #{@instance}" if @instance}
    ORDER BY First_Time DESC")

    render_partial
  end # show_redologs

  def list_redolog_members
    @instance = params[:instance]
    @group    = params[:group]

    @members = sql_select_iterator ["
      SELECT *
      FROM   gv$LogFile
      WHERE  Inst_ID = ?
      AND    Group#  = ?
    ", @instance, @group]

    render_partial
  end

  def list_redologs_log_history
    @instance = prepare_param_instance
    save_session_time_selection  # werte in session puffern
    @time_groupby = prepare_param(:time_groupby).to_sym

    wherestr = ""
    whereval = []

    if @instance
      wherestr << " AND l.Inst_ID = ?"
      whereval << @instance
    end

    if @time_groupby == :single
      @switches = sql_select_iterator ["\
        SELECT l.*
        FROM   (SELECT l.*, (LEAD(l.First_Time, 1) OVER (PARTITION BY Thread# ORDER BY l.Sequence#) - l.First_Time) * 86400 Current_Duration_Secs
                FROM   gv$Log_History l
                WHERE  Inst_ID = Thread#  /* All instances know about all logs from other instances named by thread#, assuming thread# is equal to inst_id for duplicate entries */
                #{wherestr}
               ) l
        WHERE  First_Time >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND First_Time < TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
        ORDER BY First_Time
      "].concat(whereval).concat([@time_selection_start, @time_selection_end])
    else
      case @time_groupby
      when :second    then group_by_value = "TO_NUMBER(TO_CHAR(l.First_Time, 'DDD')) * 86400 + TO_NUMBER(TO_CHAR(l.First_Time, 'SSSSS'))"
      when :second_10 then group_by_value = "TO_NUMBER(TO_CHAR(l.First_Time, 'DDD')) * 8640 + TRUNC(TO_NUMBER(TO_CHAR(l.First_Time, 'SSSSS'))/10)"
      when :minute    then group_by_value = "TRUNC(l.First_Time, 'MI')"
      when :minute_10 then group_by_value = "TO_NUMBER(TO_CHAR(l.First_Time, 'DDD')) * 8640 + TRUNC(TO_NUMBER(TO_CHAR(l.First_Time, 'SSSSS'))/600)"
      when :hour      then group_by_value = "TRUNC(l.First_Time, 'HH24')"
      when :day       then group_by_value = "TRUNC(l.First_Time)"
      when :week      then group_by_value = "TRUNC(l.First_Time) + INTERVAL '7' DAY"
      else
        raise "Unsupported value for parameter :time_groupby (#{@time_groupby})"
      end

      @switches = sql_select_iterator ["\
        SELECT l.*, LEAD(l.Min_First_Time, 1) OVER (ORDER BY l.Min_First_Time) Next_time
        FROM   (SELECT MIN(First_Time) Min_First_Time, COUNT(DISTINCT Inst_ID) Instances, COUNT(*) Log_Switches,
                       AVG(Next_Time-First_Time) * 86400    Avg_Current_Duration_Secs,
                       MIN(Next_Time-First_Time) * 86400    Min_Current_Duration_Secs,
                       MAX(Next_Time-First_Time) * 86400    Max_Current_Duration_Secs,
                       SUM(Next_Change# - First_Change#)    SCN_Increments
                FROM   (SELECT l.*, LEAD(l.First_Time, 1) OVER (PARTITION BY Thread# ORDER BY l.Sequence#) Next_time
                        FROM   gv$Log_History l
                        WHERE  Inst_ID = Thread#  /* All instances know about all logs from other instances named by thread#, assuming thread# is equal to inst_id for duplicate entries */
                        #{wherestr}
                       ) l
                WHERE  First_Time >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}') AND First_Time < TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
                GROUP BY #{group_by_value}
               ) l
        ORDER BY 1
      "].concat(whereval).concat([@time_selection_start, @time_selection_end])
    end

    render_partial
  end

  def list_redologs_historic
    @instance = prepare_param_instance
    @dbid     = prepare_param_dbid
    save_session_time_selection  # werte in session puffern

    wherestr = ""
    whereval = []

    if @instance
      wherestr << " AND l.Instance_Number = ?"
      whereval << @instance
    end

    @redologs = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */ x.*,
             x.LogSwitches * x.Members * x.Avg_Size_MB LogWrites_MB,
             CASE WHEN x.Snapshot_Secs > 0 AND x.LogSwitches IS NOT NULL AND x.LogSwitches > 0 THEN x.Snapshot_Secs / x.LogSwitches END Avg_Secs_Between_LogSwitches
      FROM   (SELECT ss.Begin_Interval_Time, ss.End_Interval_Time, l.*,
                     (CAST(ss.End_Interval_Time AS DATE)-CAST(ss.Begin_interval_Time AS DATE))*86400 Snapshot_Secs,
                     l.MaxSequenceNo - LAG(l.MaxSequenceNo, 1, l.MaxSequenceNo) OVER (PARTITION BY l.Instance_Number ORDER BY ss.Begin_Interval_Time) LogSwitches
              FROM   (
                      SELECT DBID, Snap_ID, Instance_Number, COUNT(*) Log_Number,
                             SUM(CASE WHEN Archived='NO' THEN 1 ELSE 0 END)     Not_Archived,
                             SUM(CASE WHEN Status='CURRENT' THEN 1 ELSE 0 END)  Current_No,
                             SUM(CASE WHEN Status='ACTIVE' THEN 1 ELSE 0 END)   Active_no,
                             Avg(Members)                                       Members,
                             AVG(Bytes)/ (1024*1024)                            Avg_Size_MB,
                             MAX(Sequence#)                                     MaxSequenceNo
                      FROM   DBA_Hist_Log
                      WHERE  DBID = ?
                      AND Instance_Number = Thread#  -- im gv$-View werden jeweils die Logs der anderen Instanzen noch einmal in jeder Instance mit Thread# gezeigt, dies verhindert die Dopplung
                      GROUP BY DBID, Snap_ID, Instance_Number
                     ) l
              JOIN   DBA_Hist_Snapshot ss ON ss.DBID=l.DBID AND ss.Snap_ID=l.Snap_ID AND ss.Instance_Number=l.Instance_Number
              WHERE  ss.Begin_Interval_time > TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
              AND    ss.Begin_Interval_time < TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}') #{wherestr}
            ) x
      ORDER BY x.Begin_Interval_Time, x.Instance_Number
      ", @dbid, @time_selection_start, @time_selection_end].concat whereval

    render_partial
  end

  def oracle_parameter
    @name_array = params[:name_array]
    @name_array = nil if @name_array == ''

    @caption = params[:caption]
    @caption = nil if @caption == ''

    @reduced_columns = params[:reduced_columns]

    where_string = ''
    where_values = []

    if @name_array
      raise "Array type expected instead of #{@name_array.class} for parameter @name_array" if @name_array.class != Array
      where_string << " AND Name IN ("
      @name_array.each_index do |i|
        where_string << "?"
        where_string << "," if i < @name_array.count-1
        where_values << @name_array[i]
      end
      where_string << ")"
    end

    @hint = nil

    record_modifier = proc{|rec|
      rec.value = rec.value + " (Caution!!! This is local session setting of Panorama's DB-Session! Database default may differ! Use sqlplus with SELECT * FROM gv$Parameter WHERE name='cursor_sharing'; to read real defaults."  if rec.name == 'cursor_sharing'
      rec.value = rec.value + " (Caution!!! This is local session setting of Panoramas DB-Session! Database default may differ! Use sqlplus with SELECT * FROM gv$Parameter WHERE name='nls_length_semantics'; to read real defaults.)"  if rec.name == 'nls_length_semantics'
    }

    begin
      @parameters = sql_select_iterator(["\
        SELECT /* Panorama-Tool Ramm */ *
        FROM   (SELECT NVL(v.Instance,      i.Instance)      Instance,
                       NVL(v.ID,            i.ID)            ID,
                       NVL(v.ParamType,     i.ParamType)     ParamType,
                       NVL(v.Name,          i.Name)          Name,
                       NVL(v.Description,   i.Description)   Description,
                       NVL(v.Value,         i.Value)         Value,
                       NVL(v.Display_Value, i.Display_Value) Display_Value,
                       NVL(v.IsDefault,     i.IsDefault)     IsDefault,
                       v.ISSES_MODIFIABLE, v.IsSys_Modifiable, v.IsInstance_Modifiable, v.IsModified, v.IsAdjusted, v.IsDeprecated, v.Update_Comment#{", v.IsBasic" if get_db_version >= '11.1'}#{", v.Con_ID" if get_db_version >= '12.1'}
                FROM   (SELECT /*+ NO_MERGE */
                               i.Instance_Number                 Instance,  -- Daten koennen nur on aktueller Instance gezogen werden
                               X$KSPPI.INDX                      ID,
                               X$KSPPI.KSPPITY                   ParamType,
                               X$KSPPI.KSPPINM                   Name,
                               X$KSPPI.KSPPDESC                  Description,
                               X$KSPPSV.KSPPSTVL                 Value,
                               NULL /* X$KSPPSV.ksppstdvl */     Display_Value, -- existiert ab 11g nicht mehr in dem View
                               X$KSPPSV.KSPPSTDF                 IsDefault
                        FROM  X$KSPPI
                        JOIN  X$KSPPSV ON X$KSPPSV.INDX = X$KSPPI.INDX
                        CROSS JOIN  V$Instance i
                       ) i
                FULL OUTER JOIN (
                                 SELECT /*+ NO_MERGE */
                                        Inst_ID                Instance,
                                        Num                    ID,
                                        Type                   ParamType,
                                        Name,
                                        Description,
                                        Value,
                                        Display_Value,
                                        IsDefault,
                                        ISSES_MODIFIABLE, IsSys_Modifiable, IsInstance_Modifiable, IsModified, IsAdjusted, IsDeprecated, Update_Comment#{", IsBasic" if get_db_version >= '11.1'}#{", Con_ID" if get_db_version >= '12.1'}
                                 FROM  gv$Parameter
                                ) v ON v.Instance = i.Instance AND v.ID = i.ID+1
               )
        WHERE 1=1 #{where_string}
        ORDER BY Name, Instance"].concat(where_values),
        record_modifier
      )

      render_partial

    rescue Exception
      if @name_array.nil?
        @hint = "Möglicherweise fehlende Zugriffsrechte auf Tabellen X$KSPPI und X$KSPPSV !</br>
  Es werden deshalb nur die documented Parameter aus GV$Parameter angezeigt.</br></br>

  Lösung: Exec als User 'SYS':</br>
  &nbsp;&nbsp;  create view X_$KSPPI as select * from X$KSPPI;</br>
  &nbsp;&nbsp;  grant select on X_$KSPPI to public;</br>
  &nbsp;&nbsp;  create public synonym X$KSPPI for sys.X_$KSPPI;</br></br>

  &nbsp;&nbsp;  create view X_$KSPPSV as select * from X$KSPPSV;</br>
  &nbsp;&nbsp;  grant select on X_$KSPPSV to public;</br>
  &nbsp;&nbsp;  create public synonym X$KSPPSV for sys.X_$KSPPSV;
  ".html_safe

      end
      @parameters = sql_select_iterator(["\
        SELECT /* Panorama-Tool Ramm */
          Inst_ID                Instance,
          Num                    ID,
          Type                   ParamType,
          Name,
          Description,
          Value,
          Display_Value,
          IsDefault,
          ISSES_MODIFIABLE, IsSys_Modifiable, IsInstance_Modifiable, IsModified, IsAdjusted, IsDeprecated, Update_Comment#{", IsBasic" if get_db_version >= '11.1'}#{", Con_ID" if get_db_version >= '12.1'}
        FROM  gv$Parameter
        WHERE 1=1 #{where_string}
        ORDER BY Name, Inst_ID"].concat(where_values),
        record_modifier
      )

      render_partial
    end

  end # oracle_parameter

  # Latch-Waits wegen cache buffers chains
  def latch_cache_buffers_chains
@waits = sql_select_all("\
      SELECT /*+ FIRST_ROWS */ /* Panorama-Tool Ramm */
        ln.Name,                                                  
        o.Owner,                                                  
        o.Object_Name,                                            
        sw.p3 Tries,                                              
        b.tch Touches,                                            
        TO_CHAR(sw.p1) LatchAddr,                                 
        b.dbablk BlockNo                                          
      FROM  v$session_wait sw,                                    
            v$latchname ln,                                       
            X$bh b,                                               
            dba_objects o                                         
      WHERE sw.Event = 'latch: cache buffers chains'              
      AND   ln.Latch# = sw.p2                                     
      AND   ln.name   = 'cache buffers chains'                    
      AND   b.hladdr=sw.p1raw                                     
      AND   o.object_id = b.obj                                   
      ORDER BY 1 ASC")

    render_partial
  rescue Exception => ex
    # render as html because format=>:html was requested, otherwhise test will fail
    alert_exception(ex, x_dollar_bh_solution_text, :html)
  end

  # Waits wegen db_file_sequential_read
  def wait_db_file_sequential_read
    @waits = sql_select_iterator "\
      SELECT /* Panorama-Tool Ramm */
        w.SID,                                                    
        w.Seq# SerialNo,                                          
        Wait_Time,                                                
        Seconds_In_Wait,                                          
        State,                                                    
        (SELECT SEGMENT_TYPE||':'||SEGMENT_NAME                   
        FROM DBA_Extents e                                        
        WHERE e.File_ID = w.P1                                    
        AND w.p2 BETWEEN e.BLOCK_ID AND e.BLOCK_ID + e.BLOCKS -1  
        ) name                                                    
      FROM V$Session_Wait w                                       
      WHERE Event='db file sequential read'                       
      ORDER BY 1 ASC"

    render_partial
  end
  
  def list_sessions
    @instance  = prepare_param_instance
    where_string = ""
    where_values = []
    if @instance
      where_string << " AND s.Inst_ID = ?"
      where_values << @instance
    end
    if params[:showOnlyUser]=="1"
      where_string << " AND s.type = 'USER'"
    end
    if params[:showPQServer]!="1"
      where_string << ' AND pqc.QCInst_ID IS NULL'   # Nur die QCInst_ID is nicht belegt in gv$PX_Session. Die OCSID ist auch für den Query-Koordinator belegt, der ja kein PQ ist
    end
    if params[:onlyActive]=="1"
      where_string << " AND s.Status='ACTIVE'"
    end
    if params[:showOnlyDbLink]=="1"
      where_string << " AND UPPER(s.program) like 'ORACLE@%' AND UPPER(s.Program) NOT LIKE 'ORACLE@'||(SELECT UPPER(i.Host_Name) FROM gv$Instance i WHERE i.Inst_ID=s.Inst_ID)||'%' "
    end
    if params[:object_owner] && params[:object_name] && params[:object_owner] != '' && params[:object_name] != ''
      where_string << " AND (s.Inst_ID, s.SID) IN (SELECT /*+ NO_MERGE */ Inst_ID, SID FROM GV$Access WHERE Owner = ? AND Object = ?"
      where_string << " AND Type = ?" if params[:object_type] && params[:object_type] != ''
      where_string << ")"
      where_values << params[:object_owner]
      where_values << params[:object_name]
      where_values << params[:object_type] if params[:object_type] && params[:object_type] != ''
    end
    if params[:filter] && params[:filter] != ''
      where_string << " AND ("
      where_string << "    TO_CHAR(s.SID)       LIKE '%'||?||'%'";   where_values << params[:filter]
      where_string << " OR TO_CHAR(s.Process)   LIKE '%'||?||'%'";   where_values << params[:filter]
      where_string << " OR TO_CHAR(p.spid)      LIKE '%'||?||'%'";   where_values << params[:filter]
      where_string << " OR s.UserName           LIKE '%'||UPPER(?)||'%'";   where_values << params[:filter]
      where_string << " OR UPPER(s.OSUser)      LIKE '%'||UPPER(?)||'%'";   where_values << params[:filter]
      where_string << " OR UPPER(s.Machine)     LIKE '%'||UPPER(?)||'%'";   where_values << params[:filter]
      where_string << " OR UPPER(s.Client_Info) LIKE '%'||UPPER(?)||'%'";   where_values << params[:filter]
      where_string << " OR UPPER(s.Module)      LIKE '%'||UPPER(?)||'%'";   where_values << params[:filter]
      where_string << " OR UPPER(s.Action)      LIKE '%'||UPPER(?)||'%'";   where_values << params[:filter]
      where_string << " OR UPPER(s.Program)     LIKE '%'||UPPER(?)||'%'";   where_values << params[:filter]
      where_string << ")"
    end

    @sessions = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
        s.SID,
        s.Serial# SerialNo,                                                                                          
        s.Status,
        s.SQL_ID,
        s.SQL_Child_Number,
        s.Inst_ID,
        #{"s.Con_ID, con.Name Container_Name, " if get_current_database[:cdb]}
        s.UserName,                 
        s.Client_Info,
        s.Module, s.Action,
        p.spID,
        p.PID,
        s.machine,                                                                                                                        
        s.OSUser,                                                                                                                         
        s.Process,                                                                                                                        
        s.program,
        s.Service_Name,
        SYSDATE - (s.Last_Call_Et/86400) Last_Call,
        s.Logon_Time,
        i.Block_Gets+i.Consistent_Gets+i.Physical_Reads+i.Block_Changes+i.Consistent_Changes IOIndex,
        temp.Temp_MB, temp.Temp_Extents, temp.Temp_Blocks,
        (       SELECT TO_CHAR(MIN(Start_Time), 'HH24:MI:SS') FROM GV$Session_LongOps o                                                   
                WHERE   o.SID                   = s.SID                 /* Referenz auf Session */                                        
                AND     o.Serial#               = s.Serial#             /* Referenz auf Session */                                        
                AND     o.SQL_Address           = s.SQL_Address         /* Referenz auf aktuelles Stmt, kann mehrfach ausgefuert worden sein */ 
                AND     o.SQL_Hash_Value        = s.SQL_Hash_Value      /* Referenz auf aktuelles Stmt, kann mehrfach ausgefuert worden sein */ 
                /* Vom Aktuellen Stmt aelteste Aktion nur zeigen, wenn kein anderes Stmt zwischendurch ausgefuehrt wurde */               
                AND     NOT EXISTS (SELECT '!' FROM GV$Session_LongOpS o1                                                                 
                                WHERE   o1.SID                  = o.SID                                                                   
                                AND     o1.Serial#              = o.Serial#                                                               
                                AND     o1.SQL_Address          != o.SQL_Address                                                          
                                AND     o1.SQL_Hash_Value       != o.SQL_Hash_Value                                                       
                                AND     o1.Last_Update_Time     > o.Last_Update_Time                                                      
                                )                                                                                                         
        )       LongSQL,
        px.Anzahl PQCount,
        pqc.QCInst_ID, pqc.QCSID, pqc.QCSerial# QCSerialNo,
        p.PGA_Used_Mem     + NVL(pq_mem.PQ_PGA_Used_Mem,0)     PGA_Used_Mem,
        p.PGA_Alloc_Mem    + NVL(pq_mem.PQ_PGA_Alloc_Mem,0)    PGA_Alloc_Mem,
        p.PGA_Freeable_Mem + NVL(pq_mem.PQ_PGA_Freeable_Mem,0) PGA_Freeable_Mem,
        p.PGA_Max_Mem      + NVL(pq_mem.PQ_PGA_Max_Mem,0)      PGA_Max_Mem,
        Open_Cursor, Open_Cursor_SQL,
        wa.Operation_Type, wa.Policy, wa.Active_Time_Secs, wa.Work_Area_Size_MB,
        wa.Expected_Size_MB, wa.Actual_Mem_Used_MB, wa.Max_Mem_Used_MB, wa.Number_Passes,
        wa.WA_TempSeg_Size_MB,
        CASE WHEN w.State = 'WAITING' THEN w.Event ELSE 'ON CPU' END Wait_Event,
        RawToHex(tx.XID) XID,
        #{get_db_version < '11.1' ? "w.Seconds_In_Wait" : "DECODE(w.State, 'WAITING', w.Wait_Time_Micro, w.Time_Since_Last_Wait_Micro)/1000000"} Seconds_Waiting
      FROM    GV$session s
      LEFT OUTER JOIN (SELECT Inst_ID, SID, count(*) Open_Cursor, count(distinct sql_id) Open_Cursor_SQL
                       FROM   gv$Open_Cursor
                       GROUP BY Inst_ID, SID
                      ) oc ON oc.Inst_ID = s.Inst_ID AND oc.SID = s.SID
      LEFT OUTER JOIN ( SELECT px.QCInst_ID, px.QCSID, px.QCSerial#, Count(*) Anzahl FROM GV$PX_Session px
                       GROUP BY px.QCInst_ID, px.QCSID, px.QCSerial#
                      ) px ON  px.QCInst_ID = s.Inst_ID
                           AND px.QCSID     = s.SID
                           AND px.QCSerial# = s.Serial#
      LEFT OUTER JOIN GV$PX_Session pqc ON pqc.Inst_ID = s.Inst_ID AND pqc.SID=s.SID --AND pqc.Serial#=s.Serial#    -- PQ Coordinator, SerialNo stimmt in Oracle 12c nicht mehr überein zwischen v$Session und v$px_session
      LEFT OUTER JOIN    GV$sess_io i ON i.Inst_ID = s.Inst_ID AND i.SID = s.SID
      LEFT OUTER JOIN    GV$process p ON p.Addr = s.pAddr AND p.Inst_ID = s.Inst_ID
      LEFT OUTER JOIN
              ( SELECT  DECODE(QCInst_ID, NULL, Inst_ID, QCinst_ID) Inst_ID,
                        DECODE(QCSID,NULL, SID, QCSID)  SID,
                        MIN(Operation_Type)             Operation_Type,
                        MIN(Policy)                     Policy,
                        MAX(Active_Time)/1000000        Active_Time_Secs,
                        SUM(Work_Area_Size)/(1024*1024) Work_Area_Size_MB,
                        SUM(Expected_Size)/(1024*1024)  Expected_Size_MB,
                        SUM(Actual_Mem_Used)/(1024*1024) Actual_Mem_Used_MB,
                        SUM(Max_Mem_Used)/(1024*1024)   Max_Mem_Used_MB,
                        MAX(Number_Passes)              Number_Passes,
                        SUM(TempSeg_Size)/(1024*1024)   WA_TempSeg_Size_MB,
                        COUNT(*)                        Anzahl
                FROM    gv$sql_workarea_active
                GROUP BY DECODE(QCInst_ID, NULL, Inst_ID, QCinst_ID),
                         DECODE(QCSID,NULL, SID, QCSID)
              ) wa ON wa.Inst_ID = s.Inst_ID AND wa.SID = s.SID
      LEFT OUTER JOIN
             (        -- PGA-Speicher möglicher PQ-Server. für die akt. Session Query-Coordinator ist
             SELECT px.QCInst_ID, px.QCSID, px.QCSerial#,
                    SUM(PGA_Used_Mem)     PQ_PGA_Used_Mem,
                    SUM(PGA_Alloc_Mem)    PQ_PGA_Alloc_Mem,
                    SUM(PGA_Freeable_Mem) PQ_PGA_Freeable_Mem,
                    SUM(PGA_Max_Mem)      PQ_PGA_Max_Mem
             FROM GV$PX_Session px
             JOIN GV$Session pqs ON pqs.Inst_ID = px.Inst_ID AND pqs.SID = px.SID
             JOIN gv$process pqp ON pqp.Inst_ID = px.inst_ID AND pqp.Addr = pqs.pAddr
             GROUP BY px.QCInst_ID, px.QCSID, px.QCSerial#
             ) pq_mem ON pq_mem.qcinst_id = s.Inst_ID AND pq_mem.QCSID = s.SID AND pq_mem.QCSerial# = s.Serial#
      LEFT OUTER JOIN
             (SELECT Inst_ID, Session_Addr, SUM(Extents) Temp_Extents, SUM(Blocks) Temp_Blocks, SUM(Blocks)*#{PanoramaConnection.db_blocksize}/(1024*1024) Temp_MB
              FROM   gv$Sort_Usage
              GROUP BY Inst_ID, Session_Addr
             ) temp ON temp.Inst_ID = s.Inst_ID AND temp.Session_Addr = s.sAddr
      #{"LEFT OUTER JOIN gv$Containers con ON con.Inst_ID=s.Inst_ID AND con.Con_ID=s.Con_ID" if get_current_database[:cdb]}
      LEFT OUTER JOIN gv$Session_Wait w ON w.Inst_ID = s.Inst_ID AND w.SID = s.SID
      LEFT OUTER JOIN gv$Transaction tx ON tx.Inst_ID = s.Inst_ID AND tx.Addr = s.TAddr
      WHERE 1=1 #{where_string}
      ORDER BY 1 ASC"].concat(where_values)

    render_partial :list_sessions
  end
  
  def show_session_detail
    @dbid        = prepare_param_dbid
    @instance    = prepare_param_instance
    @sid         = params[:sid].to_i
    @serialno    = params[:serialno].to_i
    @update_area = params[:update_area]

    @dbsessions =  sql_select_all ["\
           SELECT s.SQL_ID, s.Prev_SQL_ID, RawToHex(s.SAddr) SAddr, #{"s.Con_ID, con.Name Container_Name, " if get_current_database[:cdb]}
                  s.SQL_Child_Number, s.Prev_Child_Number,
                  s.Status, s.Client_Info, s.Module, s.Action, s.AudSID,
                  s.UserName, s.Machine, s.OSUser, s.Process, s.Program,
                  SYSDATE - (s.Last_Call_Et/86400) Last_Call,
                  s.Logon_Time, p.spID, p.PID,
                  RawToHex(tx.XID) Tx_ID,
                  tx.Start_Time,
                  c.AUTHENTICATION_TYPE
                  #{", c.Client_CharSet, c.Client_Connection, c.Client_OCI_Library, c.Client_Version, c.Client_Driver" if get_db_version >= "11.2" }
                  #{", s.SQL_Exec_Start, s.SQL_Exec_ID, s.Prev_Exec_Start, s.Prev_Exec_ID" if get_db_version >= '11.1' }
           FROM   GV$Session s
           JOIN   GV$process p                       ON p.Addr = s.pAddr AND p.Inst_ID = s.Inst_ID
           LEFT OUTER JOIN (SELECT Inst_ID, SID#{', Serial#' if get_db_version >= '11.2'}, AUTHENTICATION_TYPE
                                   #{", Client_CharSet, Client_Connection, Client_OCI_Library, Client_Version, Client_Driver" if get_db_version >= "11.2" }
                            FROM   GV$Session_Connect_Info
                            WHERE  Inst_ID=? AND SID=?
                            #{' AND Serial#=?' if get_db_version >= '11.2' }
                            AND    RowNum < 2         /* Verdichtung da fuer jede Zeile des Network_Banners ein Record in GV$Session_Connect_Info existiert */
                           ) c ON c.Inst_ID = s.Inst_ID AND c.SID = s.SID #{'AND c.Serial# = s.Serial#'  if get_db_version >= '11.2' }
           LEFT OUTER JOIN gv$Transaction tx ON tx.Inst_ID = s.Inst_ID AND tx.Addr = s.TAddr
           #{"LEFT OUTER JOIN gv$Containers con ON con.Inst_ID=s.Inst_ID AND con.Con_ID=s.Con_ID" if get_current_database[:cdb]}
           WHERE  s.Inst_ID=? AND s.SID=? AND s.Serial#=?",
           @instance, @sid].concat( get_db_version >= "11.2" ? [@serialno] : [] ).concat([@instance, @sid, @serialno])
    @dbsession    = nil
    @current_sql  = nil
    @previous_sql = nil
    if @dbsessions.length > 0   # Session lebt noch
      @dbsession = @dbsessions[0]
      @current_sql  = get_sga_sql_statement(@instance, @dbsession.sql_id)       if @dbsession.sql_id
      @previous_sql = get_sga_sql_statement(@instance, @dbsession.prev_sql_id)  if @dbsession.prev_sql_id

      @sql_data = [
          {:caption           => "Aktuelles SQL-Statement",
           :sql_id            => @dbsession.sql_id,
           :sql_child_number  => @dbsession.sql_child_number,
           :sql_text          => (@current_sql.html_safe if @current_sql)
          },
          {:caption           => "Vorheriges SQL-Statement",
           :sql_id            => @dbsession.prev_sql_id,
           :sql_child_number  => @dbsession.prev_child_number,
           :sql_text          => (@previous_sql.html_safe if @previous_sql)
          }
      ]

      if get_db_version >= '11.1'
        @sql_data[0][:sql_exec_start] = @dbsession.sql_exec_start
        @sql_data[0][:sql_exec_id]    = @dbsession.sql_exec_id
        @sql_data[1][:sql_exec_start] = @dbsession.prev_exec_start
        @sql_data[1][:sql_exec_id]    = @dbsession.prev_exec_id
      end
    end

    @pq_coordinator = sql_select_all ["SELECT s.Inst_ID, s.SID, s.Serial# SerialNo,
                                              s.SQL_ID, s.SQL_Child_Number, s.Status, s.Client_Info, s.Module, s.Action,
                                              s.UserName, s.Machine, s.OSUser, s.Process, s.Program,
                                              SYSDATE - (s.Last_Call_Et/86400) Last_Call,
                                              s.Logon_Time, p.spID, p.PID
                                       FROM   gv$PX_Session ps
                                       JOIN   gv$Session s ON s.Inst_ID = ps.QCInst_ID AND s.SID = ps.QCSID AND s.Serial# = ps.QCSerial#
                                       JOIN   GV$process p ON p.Addr = s.pAddr AND p.Inst_ID = s.Inst_ID
                                       WHERE  ps.Inst_ID = ?
                                       AND    ps.SID     = ?
                                       AND    ps.Serial# = ?
                                      ", @instance, @sid, @serialno]

    @open_cursor_counts = sql_select_first_row ["\
                         SELECT /*+ ORDERED USE_HASH(s) */
                                COUNT(*) Total,
                                SUM(CASE WHEN oc.SAddr=se.SAddr THEN 1 ELSE 0 END) Own_SAddr
                         FROM   GV$Session se
                         JOIN   gv$Open_Cursor oc ON oc.Inst_ID = se.Inst_ID AND oc.SID     = se.SID
                         WHERE  se.Inst_ID=? AND se.SID=? AND se.Serial#=?
                         ", @instance, @sid, @serialno]

    @pmems = sql_select_all ["\
            SELECT /*+ ORDERED USE_HASH(s p pm) */ pm.Category, 
                   SUM(pm.Allocated) Allocated,
                   SUM(pm.Used) Used,
                   SUM(pm.Max_Allocated) Max_Allocated
            FROM   (SELECT ? Inst_ID, ? SID, ? Serial# FROM DUAL
                    UNION ALL
                    SELECT Inst_ID, SID, Serial#
                    FROM   GV$PX_Session px
                    WHERE  px.QCInst_ID = ?
                    AND    px.QCSID     = ?
                    AND    px.QCSerial# = ?
                  ) x
            JOIN   GV$Session s ON s.Inst_ID = x.Inst_ID AND s.SID = x.SID AND s.serial# = x.Serial#
            JOIN   GV$Process p ON p.Inst_ID = s.Inst_ID AND p.Addr = s.pAddr
            JOIN   GV$Process_Memory pm ON pm.Inst_ID = p.Inst_ID AND pm.PID = p.PID AND pm.Serial# = p.Serial#
            GROUP BY pm.Category
            ", @instance, @sid, @serialno, @instance, @sid, @serialno]


    if @dbsession
      @sql_monitor_reports_count = get_sql_monitor_count(@dbid, @instance, nil, localeDateTime(@dbsession.logon_time, :minutes), localeDateTime(Time.now, :minutes), @sid, @serialno)

      render_partial :list_session_details
    else
      show_popup_message "Session #{@sid}/#{@serialno} does not exist anymore at instance #{@instance}!"
    end
  end

  def list_open_cursor_per_session
    @instance =  prepare_param_instance
    @sid     =  params[:sid].to_i
    @serialno = params[:serialno].to_i

    @opencursors = sql_select_iterator ["
      SELECT /*+ ORDERED USE_HASH(s wa) */
             oc.*,
             -- oc.SQL_ID oc_SQL_ID, oc.SQL_Text,
             wa.*,
             CASE WHEN se.SAddr = oc.SAddr THEN 'YES' ELSE 'NO' END Own_SAddr,
             sse.SID SAddr_SID, sse.Serial# SAddr_SerialNo
             #{", s.Child_Number" if get_db_version >= '12.1'}
      FROM   GV$Session se
      JOIN   gv$Open_Cursor oc ON oc.Inst_ID = se.Inst_ID
                              AND oc.SID     = se.SID
      LEFT OUTER JOIN (SELECT Inst_ID, Address, Hash_Value,
                               SUM(Estimated_Optimal_Size)  Estimated_Optimal_Size,
                               SUM(Estimated_OnePass_Size)  Estimated_OnePass_Size,
                               SUM(Last_Memory_used)        Last_Memory_Used,
                               SUM(Active_Time)             Active_Time,
                               SUM(Max_TempSeg_Size)        Max_TempSeg_Size,
                               SUM(Last_TempSeg_Size)       Last_TempSeg_Size
                       FROM   gv$SQL_Workarea
                       GROUP BY Inst_ID, Address, Hash_Value
                      ) wa ON wa.Inst_ID    = oc.Inst_ID
                          AND wa.Address    = oc.Address
                          AND wa.Hash_Value = oc.Hash_Value
      LEFT OUTER JOIN gv$Session sse ON sse.Inst_ID = oc.Inst_ID AND sse.SAddr = oc.SAddr
      #{"LEFT OUTER JOIN gv$SQL s ON s.Inst_ID = oc.Inst_ID AND s.Child_Address = oc.Child_Address" if get_db_version >= '12.1'}
      WHERE  se.Inst_ID=? AND se.SID=? AND se.Serial#=?
      ", @instance, @sid, @serialno]

    render_partial :list_open_cursor_per_session
  end

  def show_session_details_waits
    @instance = prepare_param_instance
    @sid      = params[:sid]
    @serialno = params[:serialno]

    @waits =  sql_select_all ["\
      SELECT w.Inst_ID, w.SID, w.Event,
             w.P1Text, w.P1, w.P1Raw,
             w.P2Text, w.P2, w.P2Raw,
             w.P3Text, w.P3, w.P3Raw,
             w.wait_Class,
             #{get_db_version >= '11.2' ? 'w.Wait_Time_Micro/1000' : 'w.Seconds_in_Wait*1000'} Wait_Time_ms,
             w.State
      FROM   GV$Session_Wait w
      WHERE  w.Inst_ID = ?
      AND    w.SID     = ?
      ", @instance, @sid]

    @pq_waits =  sql_select_all ["\
      SELECT s.Program,
             px.Inst_ID,
             px.SID,
             px.req_degree,
             px.degree,
             w.Event,
             w.P1Text, w.P1, w.P1Raw,
             w.P2Text, w.P2, w.P2Raw,
             w.P3Text, w.P3, w.P3Raw,
             w.wait_Class,
             #{get_db_version >= '11.2' ? 'w.Wait_Time_Micro/1000' : 'w.Seconds_in_Wait*1000'} Wait_Time_ms,
             w.State
      FROM   GV$PX_Session px,
             GV$Session s,
             GV$Session_Wait w
      WHERE  px.QCInst_ID = ?
      AND    px.QCSID     = ?
      AND    s.Inst_ID    = px.Inst_ID
      AND    s.SID        = px.SID
      AND    s.Serial#    = px.serial#
      AND    w.Inst_ID(+) = px.Inst_ID
      AND    w.SID(+)     = px.SID
      ", @instance, @sid]

    render_partial :list_session_details_waits
  end

  def show_session_details_locks
    @instance = prepare_param_instance
    @sid      = params[:sid]&.to_i
    @serialno = params[:serialno]&.to_i

    @locks =  sql_select_all ["\
      WITH RawLock AS (SELECT /*+ MATERIALIZE NO_MERGE */ * FROM gv$Lock)
      SELECT /*+ ORDERED */ /* Panorama-Tool Ramm */
             RowNum,
             CASE
               WHEN l.Type='TM' THEN         /* Locked Object for TM */
                 (SELECT LOWER(o.Owner)||'.'||o.object_name FROM sys.dba_objects o WHERE l.id1=o.object_id)
               WHEN l.Type='TX' THEN         /* Used Rollback Segment for TX */
                 (SELECT DECODE(Count(*),1,'','Multi:')||MIN(SUBSTR('RBS:'||x.XIDUSN,1,18)) FROM GV\$Transaction x WHERE x.Addr=s.TAddr)
             END                                                         Object,
             l.Type                                                      LockType,
             CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0  THEN o.Owner END                  Blocking_Owner,        /* Waiting for Lock */
             CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0  THEN o.Object_Name END            Blocking_Object_Name,  /* Waiting for Lock */
             CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0 AND s.Row_Wait_Obj# != -1  THEN
               RowIDTOChar(DBMS_RowID.RowID_Create(1, o.Data_Object_ID, s.Row_Wait_File#, s.Row_Wait_Block#, s.Row_Wait_Row#))
             END                                                         WaitingForRowID,
             o.Data_Object_ID                                            WaitingForData_Object_ID,
             l.ctime Seconds_In_Lock,
             l.ID1, l.ID2,
             /* Request!=0 indicates waiting for resource determinded by ID1, ID2 */
             TO_CHAR(l.Request)                                          Request,
             TO_CHAR(l.lmode)                                            LockMode,
             bs.Inst_ID                                                  Blocking_Instance_Number,
             bs.SID                                                      Blocking_SID,
             bs.Serial#                                                  Blocking_SerialNo,
             sblocked.Inst_ID                                            Blocked_Instance_Number,
             sblocked.SID                                                Blocked_SID,
             sblocked.Serial#                                            Blocked_SerialNo,
             oblocked.Owner                                              Blocked_Owner,
             oblocked.Object_Name                                        Blocked_Object_Name,
             oblocked.Data_Object_ID                                     Blocked_Data_Object_ID,
             CASE WHEN sblocked.LockWait IS NOT NULL AND sblocked.Row_Wait_Obj# != -1  THEN
               RowIDTOChar(DBMS_RowID.RowID_Create(1, oblocked.Data_Object_ID, sblocked.Row_Wait_File#, sblocked.Row_Wait_Block#, sblocked.Row_Wait_Row#))
             END                                                         Blocked_RowID
     FROM    RawLock l
     JOIN    gv$session s ON s.Inst_ID = l.Inst_ID AND s.SID = l.SID
     LEFT OUTER JOIN gv$Session bs ON bs.Inst_ID = s.Blocking_Instance AND bs.SID = s.Blocking_Session
     -- Join über der session bekanntes Objekt auf das gewartet wird, alternativ über dem Wait bekanntes Objekt
     LEFT OUTER JOIN DBA_Objects o ON o.Object_ID = DECODE(s.Row_Wait_Obj#, -1, DECODE(s.P2Text, 'object #', s.P2, NULL), s.Row_Wait_Obj#)  -- Objekt, auf das gewartet wird wenn existiert
     LEFT OUTER JOIN gv$Session  sblocked ON l.Type = 'TX' AND sblocked.Blocking_Instance = l.Inst_ID AND sblocked.Blocking_Session = l.SID
     LEFT OUTER JOIN DBA_Objects oblocked ON oblocked.Object_ID = DECODE(sblocked.Row_Wait_Obj#, -1, DECODE(sblocked.P2Text, 'object #', sblocked.P2, NULL), sblocked.Row_Wait_Obj#)
     WHERE  l.Inst_ID    = ?
     AND    l.SID        = ?
     AND    s.Serial#    = ?
     ORDER BY 1
     ", @instance, @sid, @serialno]

    render_partial :list_session_details_locks
  end

  def show_session_details_temp
    @instance = prepare_param_instance
    @sid      = params[:sid]
    @serialno = params[:serialno]
    @saddr    = params[:saddr]

    @temps = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             SQL_ID, Tablespace, Contents, SegType,
             SUM(Extents) Extents,
             SUM(Blocks) Blocks
      FROM   gv$TempSeg_Usage u
      WHERE  Inst_ID = ?
      AND    Session_Addr = HexToRaw(?)
      GROUP BY SQL_ID, Tablespace, Contents, SegType
      ", @instance, @saddr]

    render_partial :list_session_details_temp
  end

  def list_session_statistic
    @instance = prepare_param_instance
    @sid      = params[:sid]

    @stats = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             s.Statistic#    StatisticNo,
             s.Value,
             n.Class,
             n.Name
      FROM   gv$SesStat s
      JOIN   v$StatName n ON n.Statistic# = s.Statistic#
      WHERE  s.Inst_ID = ?
      AND    s.SID = ?
      AND    s.Value != 0
      ", @instance, @sid]

    render_partial
  end

  def list_session_optimizer_environment
    @instance = prepare_param_instance
    @sid      = params[:sid]

    @env = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */
             Name, #{'SQL_Feature, ' if get_db_version >= '11.2'}IsDefault, Value
      FROM   gV$SES_OPTIMIZER_ENV
      WHERE  Inst_ID = ?
      AND    SID = ?
      ", @instance, @sid]

    render_partial
  end


  # Ermitteln Object aus Parametern von v$session_wait
  def show_session_details_waits_object
    @object = object_nach_wait_parameter(params[:instance], params[:event],
            params[:p1], params[:p1raw], params[:p1text],
            params[:p2], params[:p2raw], params[:p2text],
            params[:p3], params[:p3raw], params[:p3text]
          )
    respond_to do |format|
      format.html {render :html => @object }
    end
  end

  def segment_stat   # Anzeige Auswahl-Dialog für Statistiken
    @stats = sql_select_all "\
        SELECT /* Panorama-Tool Ramm */
          DISTINCT Statistic_Name
        FROM  GV$Segment_Statistics
        WHERE Value != 0"

    render_partial
  end

  
  def show_segment_statistics
    @show_partitions = params[:show_partition_info] == '1'

    def smaller(obj1, obj2)
      return true   if obj1.inst_id < obj2.inst_id
      return false  if obj1.inst_id > obj2.inst_id
      return true   if obj1.object_type < obj2.object_type
      return false  if obj1.object_type > obj2.object_type
      return true   if obj1.owner < obj2.owner
      return false  if obj1.owner > obj2.owner
      return true   if obj1.object_name < obj2.object_name
      return false  if obj1.object_name > obj2.object_name
      return true   if !obj1.subobject_name && obj2.subobject_name  # NULL < Wert
      return false  if !obj2.subobject_name  # NULL < Wert
      return true   if obj1.subobject_name < obj2.subobject_name
      return false
    end
    
    def get_values  # ermitteln der Aktuellen Werte
      # Sortierung des Results muss mit Methode smaller korrelieren
      sql_select_all ["\
        SELECT /* Panorama-Tool Ramm */
          Inst_ID, Owner, Object_Name, SubObject_Name, Object_Type, SUM(Value) Value
        FROM   (
                SELECT Inst_ID, Owner, Object_Name, #{@show_partitions ? 'SubObject_Name' : 'NULL SubObject_Name'}, Object_Type, Value
                FROM  GV$Segment_Statistics
                WHERE Statistic_Name=?
                AND   Value != 0
               )
        GROUP BY Inst_ID, Object_Type, Owner, Object_Name, SubObject_Name
        ORDER BY Inst_ID, Object_Type, Owner, Object_Name, SubObject_Name",
        params[:statistic_name][:statistic_name]
        ]
    end # get_values

    # Sicherstellen, dass SQL-Sortierung analog der Sortierung in Ruby erfolgt
    PanoramaConnection.sql_execute "ALTER SESSION SET NLS_SORT=BINARY"

    @header = params[:statistic_name][:statistic_name]

    @column_options = []
    @column_options << {:caption=>"Inst",        :data=>"rec.inst_id",             :title=>"RAC-Instance"}
    @column_options << {:caption=>"Type",        :data=>"rec.object_type",         :title=>"Object-Type"}
    @column_options << {:caption=>"Owner",       :data=>"rec.owner",               :title=>"Object-Owner"}
    @column_options << {:caption=>"Name",        :data=>"rec.object_name",         :title=>"Object-Name"}
    @column_options << {:caption=>"Sub-Name",    :data=>"rec.subobject_name",      :title=>"Sub-Object-Name"} if @show_partitions
    @column_options << {:caption=>"Sample",      :data=>proc{|rec| formattedNumber(rec.sample)}, :title=>t(:dba_show_segment_statistics_sample_hint, :default=>'Statistics-value within the sample time'),    :align=>"right"}
    @column_options << {:caption=>"Total",       :data=>proc{|rec| formattedNumber(rec.total)},  :title=>t(:dba_show_segment_statistics_total_hint, :default=>'Statistics-value cumulated since instance startup'),     :align=>"right"}

    data1 = get_values    # Snapshot vor SampleTime
    sampletime = params[:sample_length].to_i
    if sampletime == 0    # Kein Sample gewünscht
      data2 = data1       # selbes Result noch einmal verwenden
    else
      sleep sampletime
      # raw JDBC connection does not cache results
      # PanoramaConnection.get_connection.clear_query_cache # Result-Caching Ausschalten für wiederholten Zugriff
      data2 = get_values    # Snapshot nach SampleTime
    end
    @data = []            # Leeres Array für Result
    d1_akt_index = 0;     # Vorlesen
    d2_akt_index = 0;     # Vorlesen
    while d1_akt_index < data1.length && d2_akt_index < data2.length # not EOF
      d1 = data1[d1_akt_index];   # Vorlauf Gruppe
      d2 = data2[d2_akt_index];   # Vorlauf Gruppe
      # Verarbeitung
      if d1.inst_id==d2.inst_id && d1.object_type==d2.object_type && d1.owner==d2.owner && d1.object_name==d2.object_name && d1.subobject_name==d2.subobject_name
        if params[:only_sample_change]!='1' || d2.value != d1.value
          @data << {
            "inst_id" => d1.inst_id,
            "object_type" => d1.object_type,
            "owner" => d1.owner,
            "object_name" => d1.object_name,
            "subobject_name" => d1.subobject_name,
            "sample" => d2.value - d1.value,
            "total" => d2.value
          }
        end
      end
      # Nachlesen für den Fall distinct Sätze
      if smaller(d1,d2)
        d1_akt_index = d1_akt_index+1
      else  
        d2_akt_index = d2_akt_index+1
      end
    end

    @data.each do |d|
      d.extend SelectHashHelper   # Hash per Methode zugriffsfaehig machen
    end

    @data = @data.sort {|x,y| y.sample <=> x.sample }

    output = gen_slickgrid(@data, @column_options, {:caption=>@header, :width=>"auto",  :max_height=>450})

    respond_to do |format|
      format.html {render :html => output}
    end
  end

  def show_session_waits
    @wait_sums = sql_select_iterator "\
      SELECT /*+ ORDERED USE_NL(s) Panorama Ramm */
             COUNT(*) Anzahl,
             s.Inst_ID,
             DECODE(s.State, 'WAITING', s.Event, 'ON CPU')  Event,
             DECODE(s.State, 'WAITING', s.Wait_Class, NULL) Wait_Class,
             DECODE(s.State, 'WAITING', s.State, NULL)      State,
             #{"SUM(Seconds_In_Wait) Sum_Wait_Time_Seconds," if get_db_version < '11.1'}
             #{"MAX(Seconds_In_Wait) Max_Wait_Time_Seconds," if get_db_version < '11.1'}
             #{"SUM(DECODE(State, 'WAITING', s.Wait_Time_Micro, s.Time_Since_Last_Wait_Micro))/1000000 Sum_Wait_Time_Seconds," if get_db_version >= '11.1'}
             #{"MAX(DECODE(State, 'WAITING', s.Wait_Time_Micro, s.Time_Since_Last_Wait_Micro))/1000000 Max_Wait_Time_Seconds," if get_db_version >= '11.1'}
             COUNT(DISTINCT s.Module)                       Module_Count,
             MIN(s.Module)                                  Module,
             COUNT(DISTINCT s.Action)                       Action_Count,
             MIN(s.Action)                                  Action
      FROM   gv$Session s
     WHERE   Wait_Class != 'Idle'
     GROUP BY Inst_ID, DECODE(State, 'WAITING', Event, 'ON CPU'),
              DECODE(State, 'WAITING', Wait_Class, NULL), DECODE(State, 'WAITING', State, NULL)
     ORDER BY COUNT(*) DESC, 6 DESC"

    # Erweitern der Daten um Informationen, die nicht im originalen Statement selektiert werden können,
    # da die Tabellen nicht auf allen DB zur Verfügung stehen
    record_modifier = proc{|rec|
      rec['waiting_app_desc']  = explain_application_info(rec.module)
      rec['blocking_app_desc'] = explain_application_info(rec.blocking_module)
    }

    @blocking_waits = sql_select_iterator("\
      WITH Locks AS (
              SELECT /*+ LEADING(l) */ /* Panorama-Tool Ramm */
                     s.Inst_ID,
                     s.SID,
                     s.Serial# SerialNo,
                     s.SQL_ID,
                     s.SQL_Child_Number,
                     s.Status,
                     s.Event,
                     s.Client_Info,
                     s.Module,
                     s.Action,
                     s.UserName,
                     s.machine,
                     s.OSUser,
                     s.Process,
                     s.program,
                     bo.Owner               Blocking_Object_Schema,
                     bo.Object_Name         Blocking_Object_Name,
                     bo.Data_Object_ID,
                     s.Row_Wait_File#       Row_Wait_File_No,
                     s.Row_Wait_Block#      Row_Wait_Block_No,
                     s.Row_Wait_Row#        Row_Wait_Row_No,
                     #{get_db_version < '11.1' ? "s.Seconds_In_Wait" : "s.Wait_Time_Micro/1000000"} Seconds_Waiting,
                     s.Blocking_Instance    Blocking_Instance_Number,
                     s.Blocking_Session     Blocking_SID,
                     bs.Serial#             Blocking_SerialNo,
                     bs.Status              Blocking_Status,
                     bs.Event               Blocking_Event,
                     bs.Client_Info         Blocking_Client_Info,
                     bs.Module              Blocking_Module,
                     bs.Action              Blocking_Action,
                     bs.UserName            Blocking_UserName,
                     bs.Machine             Blocking_Machine,
                     bs.OSUser              Blocking_OSUser,
                     bs.Process             Blocking_Process,
                     bs.Program             Blocking_Program
               FROM gv$session s
               JOIN gv$Session bs ON bs.Inst_ID = s.Blocking_Instance AND bs.SID = s.Blocking_Session
               -- Object der blockenden Session
               LEFT OUTER JOIN sys.DBA_Objects bo ON bo.Object_ID = CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Objekt */ s.P2
                                                                    ELSE CASE WHEN s.Row_Wait_Obj# != -1 THEN /* Session kennt Objekt */   s.Row_Wait_Obj#
                                                                         ELSE NULL
                                                                         END
                                                                    END
               WHERE s.type = 'USER'
              ),
      HLocks AS (
              SELECT /*+ NO_MERGE */ RowNum Row_Num, Level HLevel, l.*,
                     CONNECT_BY_ROOT Blocking_Instance_Number Root_Blocking_Instance_Number,
                     CONNECT_BY_ROOT Blocking_SID             Root_Blocking_SID,
                     CONNECT_BY_ROOT Blocking_SerialNo        Root_Blocking_SerialNo
              FROM   Locks l
              CONNECT BY NOCYCLE PRIOR  sid     = blocking_sid
                             AND PRIOR Inst_ID  = blocking_instance_number
                             AND PRIOR serialno = blocking_serialNo
             )
      SELECT l.*, NULL Waiting_App_Desc, NULL Blocking_App_Desc
      FROM   HLocks l
      -- Jede Zeile nur einmal unter der Root-Hierarchie erscheinen lassen, nicht als eigenen Knoten
      WHERE NOT EXISTS (SELECT 1 FROM HLocks t
                        WHERE  t.sid      = l.sid
                        AND    t.Inst_ID  = l.Inst_ID
                        AND    t.SerialNo = l.SerialNo
                        AND    t.HLevel   > l.HLevel
                       )
       ORDER BY Row_Num", record_modifier)

    render_partial
  end

  def list_waits_per_event
    @instance = params[:instance]
    @event    = params[:event]
    @waits = sql_select_iterator ["\
      SELECT Inst_ID, SID, Serial# SerialNo, Event, Wait_Class,
             P1Text, P1, P1Raw,
             P2Text, P2, P2Raw,
             P3Text, P3, P3Raw,
             #{"Seconds_In_Wait*1000 Wait_Time_MilliSeconds," if get_db_version < '11.1'}
             #{"DECODE(State, 'WAITING', s.Wait_Time_Micro, s.Time_Since_Last_Wait_Micro)/1000 Wait_Time_MilliSeconds," if get_db_version >= '11.1'}
             State,
             Client_Info, Module, Action,
             SQL_ID, Prev_SQL_ID, SQL_Child_Number, Prev_Child_Number
      FROM   gv$Session s
      WHERE  s.Inst_ID = ?
      AND    ((? = 'ON CPU' AND s.State != 'WAITING') OR s.Event   = ?) ",
      @instance, @event, @event]

    render_partial :list_waits_per_event
  end

  def show_dba_autotask_jobs
    @windows = sql_select_iterator "SELECT c.*,
                                           w.Resource_Plan, w.Schedule_Type, w.Repeat_Interval, w.Window_Priority, w.Comments
                                    FROM   DBA_AUTOTASK_WINDOW_CLIENTS c
                                    LEFT OUTER JOIN DBA_Scheduler_Windows w ON #{"w.Owner = 'SYS' AND " if get_db_version >= '12.1'}w.Window_Name = c.Window_Name
                                   "

    @tasks = sql_select_iterator "SELECT a.*,
                                         EXTRACT(HOUR FROM Mean_Job_Duration)*3600              + EXTRACT(MINUTE FROM Mean_Job_Duration)*60             + EXTRACT(SECOND FROM Mean_Job_Duration)            Mean_Job_Duration_Secs,
                                         EXTRACT(HOUR FROM Mean_Job_CPU)*3600                   + EXTRACT(MINUTE FROM Mean_Job_CPU)*60                  + EXTRACT(SECOND FROM Mean_Job_CPU)                 Mean_Job_CPU_Secs,
                                         EXTRACT(HOUR FROM TOTAL_CPU_LAST_7_DAYS)*3600          + EXTRACT(MINUTE FROM TOTAL_CPU_LAST_7_DAYS)*60         + EXTRACT(SECOND FROM TOTAL_CPU_LAST_7_DAYS)        TOTAL_CPU_LAST_7_DAYS_Secs,
                                         EXTRACT(HOUR FROM TOTAL_CPU_LAST_30_DAYS)*3600         + EXTRACT(MINUTE FROM TOTAL_CPU_LAST_30_DAYS)*60        + EXTRACT(SECOND FROM TOTAL_CPU_LAST_30_DAYS)       TOTAL_CPU_LAST_30_DAYS_Secs,
                                         EXTRACT(HOUR FROM MAX_DURATION_LAST_7_DAYS)*3600       + EXTRACT(MINUTE FROM MAX_DURATION_LAST_7_DAYS)*60      + EXTRACT(SECOND FROM MAX_DURATION_LAST_7_DAYS)     MAX_DURATION_LAST_7_DAYS_Secs,
                                         EXTRACT(HOUR FROM MAX_DURATION_LAST_30_DAYS)*3600      + EXTRACT(MINUTE FROM MAX_DURATION_LAST_30_DAYS)*60     + EXTRACT(SECOND FROM MAX_DURATION_LAST_30_DAYS)    MAX_DURATION_LAST_30_DAYS_Secs,
                                         EXTRACT(HOUR FROM WINDOW_DURATION_LAST_7_DAYS)*3600    + EXTRACT(MINUTE FROM WINDOW_DURATION_LAST_7_DAYS)*60   + EXTRACT(SECOND FROM WINDOW_DURATION_LAST_7_DAYS)  WINDOW_DURATION_7_DAYS_Secs,
                                         EXTRACT(HOUR FROM WINDOW_DURATION_LAST_30_DAYS)*3600   + EXTRACT(MINUTE FROM WINDOW_DURATION_LAST_30_DAYS)*60  + EXTRACT(SECOND FROM WINDOW_DURATION_LAST_30_DAYS) WINDOW_DURATION_30_DAYS_Secs,
                                         j.Job_Runs
                                  FROM   DBA_AutoTask_Client a
                                  JOIN   (SELECT /*+ NO_MERGE */ Client_Name, COUNT(*) Job_Runs
                                          FROM   DBA_AUTOTASK_JOB_HISTORY
                                          GROUP BY Client_Name
                                         ) j ON j.Client_Name = a.Client_Name
                                 "
    render_partial
  end

  def list_dba_autotask_job_runs
    @client_name =  params[:client_name]
    @job_runs = sql_select_iterator ["SELECT j.*,
                                             EXTRACT(HOUR FROM Window_Duration)*3600  + EXTRACT(MINUTE FROM Window_Duration)*60   + EXTRACT(SECOND FROM Window_Duration)  Window_Duration_Secs,
                                             EXTRACT(HOUR FROM Job_Duration)*3600     + EXTRACT(MINUTE FROM Job_Duration)*60      + EXTRACT(SECOND FROM Job_Duration)     Job_Duration_Secs
                                      FROM   DBA_Autotask_Job_History j
                                      WHERE Client_Name = ? ORDER BY Job_Start_Time DESC
                                     ", @client_name]
    render_partial
  end

  def list_database_triggers
    @triggers = sql_select_iterator "SELECT * FROM dba_triggers where base_object_type LIKE 'DATABASE%' ORDER BY Triggering_Event, Trigger_Name"
    params[:update_area] = 'content_for_layout'
    render_partial
  end


  def list_accessed_objects
    @instance = params[:instance]
    @sid      = params[:sid]

    @objects = sql_select_iterator ["\
      SELECT /*+ Panorama Ramm */ Owner, Object
      FROM   gv$Access
      WHERE  Inst_ID = ?
      AND    SID     = ?
      ", @instance, @sid]

    render_partial
  end

  def show_server_logs
    @instance = sql_select_one "SELECT Instance_Number FROM v$Instance"

    render_partial
  end

  def list_server_logs
    save_session_time_selection    # Werte puffern fuer spaetere Wiederverwendung
    @log_type     = params[:log_type]
    @incl_filter  = params[:incl_filter]
    @excl_filter  = params[:excl_filter]
    @incl_filter  = nil if @incl_filter == ''
    @excl_filter  = nil if @excl_filter == ''
    @suppress_defaults = params[:suppress_defaults] == '1'

    where_filter = ''
    where_values = []

    unless @log_type == 'all'
      where_filter << " AND TRIM(COMPONENT_ID)=?"
      where_values << @log_type
    end

    if @suppress_defaults
      if @excl_filter
        @excl_filter << '|'
      else
        @excl_filter = ''
      end
      @excl_filter << "Thread 1 advanced to log sequence % (LGWR switch)|"
      @excl_filter << "Current log# % seq# % mem#|"
      @excl_filter << "LNS: Standby redo logfile selected for thread % sequence % for destination LOG_ARCHIVE_DEST|"
      @excl_filter << "Archived Log entry % added for thread % sequence % ID % dest %:"



    end

    if @incl_filter
      where_filter << " AND ("
      incl_filters = @incl_filter.split('|')
      incl_filters.each_index do |i|
        where_filter << " Message_Text LIKE '%'||?||'%'"
        where_filter << " OR " if i < incl_filters.count-1
        where_values << incl_filters[i]
      end
      where_filter << " )"
    end

    if @excl_filter
      @excl_filter.split('|').each do |f|
        where_filter << " AND Message_Text NOT LIKE '%'||?||'%'"
        where_values << f
      end
    end

    if params[:detail]
      # adr_home, Inst_ID removed because not yet existing in 19c
      @result =  sql_select_iterator ["\
      SELECT Originating_Timestamp, Component_ID,
             Message_Type, Message_Level,
             Process_ID, Message_Text, FileName
      FROM   V$DIAG_ALERT_EXT
      WHERE  Originating_Timestamp >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}')
      AND    Originating_Timestamp < TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
      #{where_filter}
      ORDER BY Originating_Timestamp, Record_ID
   ", @time_selection_start, @time_selection_end].concat(where_values)

      render_partial :list_server_logs
    else  # grouping
      trunc_tag = params[:verdichtung][:tag]

      if trunc_tag == 'SS'
        ts_expr = "CAST(Originating_Timestamp AS DATE)"   # trunc second
      else
        ts_expr = "TRUNC(Originating_Timestamp, '#{trunc_tag}')"
      end

      @result =  sql_select_iterator ["\
      SELECT #{ts_expr} Originating_Timestamp, COUNT(*) Records, MAX(CAST(Originating_Timestamp AS DATE))+1/86400 Max_TS_add_1_sec
      FROM   V$DIAG_ALERT_EXT
      WHERE  Originating_Timestamp >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}')
      AND    Originating_Timestamp < TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
      #{where_filter}
      GROUP BY #{ts_expr}
      ORDER BY 1
   ", @time_selection_start, @time_selection_end].concat(where_values)

      render_partial :list_server_log_groups
    end
  end

  def list_patch_history
    @patches  = sql_select_iterator "SELECT * FROM sys.Registry$History ORDER BY Action_Time"
    @registry = sql_select_iterator "SELECT r.*, TO_DATE(Modified, 'DD-MON-YYYY HH24:MI:SS') date_modified FROM DBA_Registry r ORDER BY Comp_ID"
    if get_db_version >= '12.1'
      @sql_patches = sql_select_all "SELECT * FROM DBA_REGISTRY_SQLPATCH"
    end
    render_partial
  end

  def list_feature_usage
    @feature_usage = sql_select_all "SELECT * FROM DBA_FEATURE_USAGE_STATISTICS"

    # info grouped by management pack
    pack_usage = {}
    @feature_usage.each do |f|
      key = "#{f.dbid} #{pack_from_feature(f.name) }"
      if pack_usage[key].nil?
        pack_usage[key] = { :dbid               => f.dbid,
                            :pack               => pack_from_feature(f.name),
                            :detected_usages    => 0,
                            :currently_used     => 'FALSE'
        }
      end
      pack_usage[key][:detected_usages]   = pack_usage[key][:detected_usages] + f.detected_usages
      pack_usage[key][:currently_used]    = 'TRUE' if f.currently_used == 'TRUE'
      pack_usage[key][:first_usage_date]  = f.first_usage_date if f.first_usage_date && (pack_usage[key][:first_usage_date].nil? || f.first_usage_date <  pack_usage[key][:first_usage_date])
      pack_usage[key][:last_usage_date]   = f.last_usage_date  if f.last_usage_date  && (pack_usage[key][:last_usage_date].nil?  || f.last_usage_date  >  pack_usage[key][:last_usage_date])
    end

    @pack_usage = []
    pack_usage.each do |key, value|
      value.extend TolerantSelectHashHelper
      @pack_usage << value
    end

    render_partial
  end

  def show_trace_files
    @instance = sql_select_one "SELECT Instance_Number FROM v$Instance"
    render_partial
  end

  def list_trace_files
    save_session_time_selection
    @filename_incl_filter = prepare_param(:filename_incl_filter)
    @filename_excl_filter = prepare_param(:filename_excl_filter)
    @content_incl_filter  = prepare_param(:content_incl_filter)
    @content_excl_filter  = prepare_param(:content_excl_filter)

    where_string = ''
    where_values = []

    if @filename_incl_filter
      where_string << " AND ("
      incl_filters = @filename_incl_filter.split('|')
      incl_filters.each_index do |i|
        where_string << " f.Trace_Filename LIKE '%'||?||'%'"
        where_string << " OR " if i < incl_filters.count-1
        where_values << incl_filters[i]
      end
      where_string << " )"
    end

    if @filename_excl_filter
      @filename_excl_filter.split('|').each do |f|
        where_string << " AND f.Trace_Filename NOT LIKE '%'||?||'%'"
        where_values << f
      end
    end




    @files = sql_select_iterator ["SELECT f.*
                                   FROM   gv$Diag_Trace_File f
                                   WHERE  f.Change_Time >= TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                                   AND    f.Change_Time <  TO_TIMESTAMP(?, '#{sql_datetime_minute_mask}')
                                   #{where_string}
                                   ORDER BY f.Change_Time
                                  ", @time_selection_start, @time_selection_end].concat(where_values)

    # GV_$DIAG_TRACE_FILE
    # GV_$DIAG_TRACE_FILE_CONTENTS
    render_partial
  end

  def list_trace_file_content
    @instance       = prepare_param_instance
    @adr_home       = prepare_param(:adr_home)
    @trace_filename = prepare_param(:trace_filename)
    @con_id         = prepare_param(:con_id)

    @content = sql_select_iterator ["SELECT c.*, c.Serial# SerialNo
                                   FROM   gv$Diag_Trace_File_Contents c
                                   WHERE  c.Inst_ID        = ?
                                   AND    c.ADR_Home       = ?
                                   AND    c.Trace_FileName = ?
                                   AND    c.Con_ID         = ?
                                   ORDER BY c.Line_Number
                                  ", @instance, @adr_home, @trace_filename, @con_id]

    render_partial
  end

  def list_os_statistics
    @osstats = sql_select_iterator "SELECT * FROM gv$OSStat ORDER BY Stat_Name, Inst_ID"
    render_partial
  end

end # Class
