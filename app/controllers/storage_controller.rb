# encoding: utf-8
class StorageController < ApplicationController


  # Groesse und Füllung der Tabelspaces
  def tablespace_usage
    @tablespaces = sql_select_all("\
      SELECT /* Panorama-Tool Ramm */
             t.TableSpace_Name,
             t.contents,
             t.Block_Size                   BlockSize,
             f.FileSize                     MBTotal,
             NVL(free.MBFree,0)             MBFree,
             f.FileSize-NVL(free.MBFree,0)  MBUsed,
             (f.FileSize-NVL(free.MBFree,0))/f.FileSize*100 PctUsed,
             t.Status, t.Contents, t.Logging, t.Force_Logging, t.Extent_Management,
             t.Allocation_Type, t.Plugged_In,
             t.Segment_Space_Management, t.Def_Tab_Compression, t.Bigfile,
             f.AutoExtensible
             #{ ", t.Encrypted, t.Compress_For" if get_db_version >= '11.2'}
             #{ ", t.Def_InMemory" if get_db_version >= '12.1' && PanoramaConnection.edition == :enterprise}
      FROM  DBA_Tablespaces t
      LEFT OUTER JOIN
            (
            SELECT /* Panorama-Tool Ramm */
                   f.TABLESPACE_NAME,
                   Sum(f.BYTES)/1048576     MBFree
            FROM   DBA_FREE_SPACE f
            GROUP BY f.TABLESPACE_NAME
            ) free ON free.Tablespace_Name = t.Tablespace_Name
      LEFT OUTER JOIN
            (
            SELECT d.TableSpace_Name, SUM(d.Bytes)/1048576 FileSize,
                   CASE WHEN COUNT(DISTINCT AutoExtensible)> 1 THEN 'Partial' ELSE MIN(AutoExtensible) END AutoExtensible
            FROM   DBA_Data_Files d
            GROUP BY d.Tablespace_Name
            ) f ON f.Tablespace_Name = t.TableSpace_Name
      WHERE Contents != 'TEMPORARY'
      UNION ALL
      SELECT f.Tablespace_Name,
             t.Contents,
             t.Block_Size                   BlockSize,
             NVL(f.MBTotal,0)               MBTotal,
             NVL(f.MBTotal,0)-NVL(s.Used_Blocks,0)*t.Block_Size/1048576 MBFree,
             NVL(s.Used_Blocks,0)*t.Block_Size/1048576 MBUsed,
             (NVL(s.Used_Blocks,0)*t.Block_Size/1048576)/NVL(f.MBTotal,0)*100 PctUsed,
             t.Status, t.Contents, t.Logging, t.Force_Logging, t.Extent_Management,
             t.Allocation_Type, t.Plugged_In,
             t.Segment_Space_Management, t.Def_Tab_Compression, t.Bigfile,
             f.AutoExtensible
             #{ ", t.Encrypted, t.Compress_For" if get_db_version >= '11.2'}
             #{ ", t.Def_InMemory" if get_db_version >= '12.1'}
      FROM  DBA_Tablespaces t
      LEFT OUTER JOIN (SELECT Tablespace_Name, SUM(Bytes)/1048576 MBTotal, SUM(Bytes)/SUM(Blocks) BlockSize,
                              CASE WHEN COUNT(DISTINCT AutoExtensible)> 1 THEN 'Partial' ELSE MIN(AutoExtensible) END AutoExtensible
                       FROM DBA_Temp_Files
                       GROUP BY Tablespace_Name
                      ) f ON f.Tablespace_Name = t.TableSpace_Name
      LEFT OUTER JOIN (SELECT Tablespace_Name, SUM(Total_Blocks) Used_Blocks
                       FROM   GV$Sort_Segment
                       GROUP BY Tablespace_Name
                      ) s ON s.Tablespace_Name = t.TableSpace_Name
      WHERE t.Contents = 'TEMPORARY'
      UNION ALL
      SELECT 'Redo Inst='||Inst_ID           Tablespace_Name,
             'Redo-Logfile'             Contents,
             #{ if get_db_version >= "11.2"
                  "MIN(BlockSize)"
                else
                  0
                end
             }                          BlockSize,
             SUM(Bytes*Members)/1048576 MBTotal,
             0                          MBFree,
             SUM(Bytes*Members)/1048576 MBUsed,
             100                        PctUsed,
             NULL                       Status,
             'REDO-LOG'                 Contents,
             NULL                       Logging,
             NULL                       Force_Logging,
             NULL                       Extent_Management,
             NULL                       Allocation_Type,
             NULL                       Plugged_In,
             NULL                       Segment_Space_Management,
             NULL                       Def_Tab_Compression,
             NULL                       Bigfile,
             NULL                       AutoExtensible
             #{ ", NULL Encrypted, NULL Compress_For" if get_db_version >= '11.2'}
             #{ ", NULL Def_InMemory" if get_db_version >= '12.1'}
      FROM   gv$Log
      GROUP BY Inst_ID
      ORDER BY 4 DESC NULLS LAST
      ")


    @fra_size_bytes = sql_select_one("SELECT Value FROM v$Parameter WHERE Name='db_recovery_file_dest_size'").to_i
    #@flashback_log = sql_select_first_row "SELECT * FROM v$Flashback_Database_Log"
    @fra_usage = sql_select_all "SELECT * FROM v$Flash_Recovery_Area_Usage WHERE Percent_Space_Used > 0 ORDER BY Percent_Space_Used DESC"

    totals = {}
    total_sum = {"contents"=>"TOTAL", "mbtotal"=>0, "mbfree"=>0, "mbused"=>0}
    total_sum.extend SelectHashHelper
    @tablespaces.each do |t|
      unless totals[t.contents]
        totals[t.contents] = {"mbtotal"=>0, "mbfree"=>0, "mbused"=>0}
      end
      totals[t.contents]["mbtotal"] += t.mbtotal
      totals[t.contents]["mbfree"]  += t.mbfree
      totals[t.contents]["mbused"] += t.mbused
      total_sum["mbtotal"] += t.mbtotal
      total_sum["mbfree"]  += t.mbfree
      total_sum["mbused"]  += t.mbused
    end

    if @fra_size_bytes > 0
      totals['Fast Recovery Area'] = {}
      totals['Fast Recovery Area']['mbtotal'] = @fra_size_bytes / (1024*1024).to_i
      totals['Fast Recovery Area']['mbused'] = 0
      @fra_usage.each do |f|
        totals['Fast Recovery Area']['mbused'] += f.percent_space_used*@fra_size_bytes/(1024*1024)/100
      end
      totals['Fast Recovery Area']['mbfree'] = totals['Fast Recovery Area']['mbtotal'] - totals['Fast Recovery Area']['mbused']

      total_sum["mbtotal"] += totals['Fast Recovery Area']['mbtotal']
      total_sum["mbfree"]  += totals['Fast Recovery Area']['mbfree']
      total_sum["mbused"]  += totals['Fast Recovery Area']['mbused']
    end

    @totals = []
    totals.each do |key, value|
      value["contents"] = key
      value.extend SelectHashHelper
      @totals << value
    end
    @totals << total_sum

    schemas = sql_select_all("\
      SELECT /* Panorama-Tool Ramm */ Owner Schema, Type Segment_Type, SUM(Bytes)/1048576 MBytes
      FROM (
        SELECT s.Owner,
               DECODE(s.Segment_Type,
                      'INDEX PARTITION', 'Index',
                      'INDEX SUBPARTITION', 'Index',
                      'INDEX'          , 'Index',
                      'TABLE'          , 'Table',
                      'NESTED TABLE'   , 'Table',
                      'TABLE PARTITION', 'Table',
                      'TABLE SUBPARTITION', 'Table',
                      'LOBSEGMENT'     , 'Table',
                      'LOB PARTITION'  , 'Table',
                      'LOBINDEX'       , 'Index',
                      Segment_Type)||
               DECODE(i.Index_Type, 'IOT - TOP', ' IOT-PKey', '') Type,
               s.Bytes
        FROM   DBA_Segments s
        LEFT OUTER JOIN DBA_Indexes i ON i.Owner = s.Owner AND i.Index_Name=s.Segment_Name
        )
      GROUP BY Owner, Type
      HAVING SUM(Bytes) > 1048576 -- nur > 1 MB selektieren
      ORDER BY 3 DESC")

    # Menge der verwendeten Typen ermitteln
    @schema_segment_types = {}
    schemas.each do |s|
      @schema_segment_types[s.segment_type] = 0 unless @schema_segment_types[s.segment_type]                         # Type als genutzt markieren
      @schema_segment_types[s.segment_type] = @schema_segment_types[s.segment_type] + s.mbytes
    end
    @schema_segment_types = @schema_segment_types.sort_by {|key, value| -value}

    temp_schemas = {}
    schemas.each do |s|
      temp_schemas[s.schema] = {} unless temp_schemas[s.schema]                             # Neuer Record wenn noch nicht existiert
      temp_schemas[s.schema][s.segment_type] = 0 unless temp_schemas[s.schema][s.segment_type]  # Initialisierung
      temp_schemas[s.schema][s.segment_type] = temp_schemas[s.schema][s.segment_type] + s.mbytes
    end

    @schemas = []
    temp_schemas.each do |key, value|
      new_rec = {'schema' => key, 'total_mbytes' => 0}

      @schema_segment_types.each do |type, dummy|
        new_rec[type] = value[type]
        new_rec['total_mbytes'] = new_rec['total_mbytes'] + value[type] if value[type]
      end

      new_rec.extend SelectHashHelper
      @schemas << new_rec
    end


    @segments = sql_select_all "SELECT /* Panorama-Tool Ramm */ Segment_Type,
                                       SUM(Bytes)/1048576   MBytes
                                FROM  (SELECT s.Bytes,
                                              s.Segment_Type || DECODE(i.Index_Type, 'IOT - TOP', ' IOT-PKey', '') Segment_Type
                                       FROM   DBA_Segments s
                                       LEFT OUTER JOIN DBA_Indexes i ON i.Owner = s.Owner AND i.Index_Name=s.Segment_Name
                                      )
                                GROUP BY Segment_Type
                                ORDER BY 2 DESC"


    render_partial
  end


  # Einsprung aus show_materialzed_views
  def list_materialized_view_action
    case
      when params[:registered_mviews]      then list_registered_materialized_views
      when params[:all_mviews]             then list_all_materialized_views
      when params[:mview_logs]             then list_materialized_view_logs
      else
        raise "params missing for :mview or :mview_logs"
    end
  end

  def list_registered_materialized_views
    where_string = ""
    where_values = []

    if params[:snapshot_id]
      where_string << " AND m.MView_ID = ?"
      where_values << params[:snapshot_id]
    end

    global_name = sql_select_one 'SELECT Name FROM v$Database'

    @mvs = sql_select_iterator ["\
      SELECT m.Owner,
             m.Name,
             m.MView_Site,
             m.Can_use_Log,
             m.Updatable,
             m.Refresh_Method,
             m.MView_ID,
             m.Version,
             l.Snapshot_Logs, l.Oldest_Refresh_Date,
             (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments seg WHERE seg.Owner=m.Owner AND seg.Segment_Name=m.Name AND m.MView_Site = '#{global_name}') MBytes, /* Result nur wenn registered MView auf lokaler DB */
             t.Num_Rows, t.Last_Analyzed,
             mv.Master_Link
      FROM   sys.dba_registered_mviews m
      LEFT OUTER JOIN (SELECT Snapshot_ID, COUNT(*) Snapshot_Logs, MIN(Current_Snapshots) Oldest_Refresh_Date
                       FROM DBA_Snapshot_Logs GROUP BY Snapshot_ID) l  ON l.Snapshot_ID = m.MView_ID
      LEFT OUTER JOIN DBA_Tables t ON t.Owner = m.Owner AND t.Table_Name = m.Name AND m.MView_Site = '#{global_name}'     /* Table nur Joinen wenn registered MView auf lokaler DB */
      LEFT OUTER JOIN DBA_MViews mv ON mv.Owner = m.Owner AND mv.MView_Name = m.Name AND m.MView_Site = '#{global_name}'  /* Table nur Joinen wenn registered MView auf lokaler DB */
      WHERE 1=1 #{where_string}
    "].concat where_values

    render_partial :list_registered_materialized_views
  end

  def list_all_materialized_views
    where_string = ""
    where_values = []

    if params[:owner]
      where_string << " AND m.Owner = ?"
      where_values << params[:owner]
    end

    if params[:name]
      where_string << " AND m.MView_Name = ?"
      where_values << params[:name]
    end

    global_name = sql_select_one 'SELECT Name FROM v$Database'

    @mvs = sql_select_iterator ["\
      SELECT m.*, DECODE(r.Name, NULL, 'N', 'Y') Registered, r.MView_ID,
             l.Snapshot_logs, l.Oldest_Refresh_Date,
             (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments seg WHERE seg.Owner=m.Owner AND seg.Segment_Name=m.MView_Name) MBytes,
             t.Num_Rows, t.Last_Analyzed,
             s.Table_Name, s.Master_view, s.Master_Owner, s.Master, s.Can_Use_Log,
             s.Refresh_Method Fast_Refresh_Method, s.Error, s.fr_operations, s.cr_operations, s.Refresh_Group,
             s.Status content_status
      FROM   dba_MViews m
      LEFT OUTER JOIN DBA_Snapshots s ON s.Owner = m.Owner AND s.Name = m.MView_Name
      /* Lokal Registrierte MViews auf gleicher DB */
      LEFT OUTER JOIN DBA_Registered_MViews r ON r.Owner = m.Owner AND r.Name = m.MView_Name AND r.MView_Site='#{global_name}'
      LEFT OUTER JOIN (SELECT Snapshot_ID, COUNT(*) Snapshot_Logs, MIN(Current_Snapshots) Oldest_Refresh_Date
                       FROM DBA_Snapshot_Logs GROUP BY Snapshot_ID) l  ON l.Snapshot_ID = r.MView_ID
      LEFT OUTER JOIN DBA_Tables t ON t.Owner = m.Owner AND t.Table_Name = m.MView_Name
      WHERE  1=1 #{where_string}
      ORDER BY m.MView_Name
    "].concat where_values

    render_partial  :list_all_materialized_views
  end

  def list_materialized_view_logs
    where_string = ""
    where_values = []

    if params[:log_owner]
      where_string << " AND l.Log_Owner = ?"
      where_values << params[:log_owner]
    end

    if params[:log_name]
      where_string << " AND l.Log_Table = ?"
      where_values << params[:log_name]
    end

    @logs = sql_select_iterator ["\
      SELECT l.*, l.Object_ID Has_Object_ID,
             sl.Snapshot_count, sl.Oldest_Refresh_Date,
             t.Num_rows, t.Last_Analyzed,
             (SELECT SUM(Bytes)/(1024*1024) FROM DBA_Segments seg WHERE seg.Owner=l.Log_Owner AND seg.Segment_Name=l.log_Table) MBytes
      FROM   DBA_MView_Logs l
      LEFT OUTER JOIN   (SELECT Log_Owner, Log_Table, COUNT(*) Snapshot_Count, MIN(Current_Snapshots) Oldest_Refresh_Date
                         FROM   DBA_Snapshot_Logs
                         WHERE  Snapshot_ID IS NOT NULL -- hat wirklich registrierte Snapshots
                         GROUP BY Log_Owner, Log_Table
                        ) sl ON sl.Log_Owner = l.Log_Owner AND sl.Log_Table = l.Log_Table
      LEFT OUTER JOIN DBA_Tables t ON t.Owner = l.Log_Owner AND t.Table_Name = l.Log_Table
      WHERE 1=1 #{where_string}
      "].concat where_values

    render_partial  :list_materialized_view_logs
  end


  # Anzeige der n:m zwischen MV und MV-Log
  def list_snapshot_logs
    where_string = ""
    where_values = []
    @grid_caption = ""

    if params[:snapshot_id]
      where_string << " AND l.Snapshot_ID = ?"
      where_values << params[:snapshot_id]
      @grid_caption << " Snapshot-ID='#{params[:snapshot_id]}'"
    end

    if params[:log_owner]
      where_string << " AND l.Log_Owner = ?"
      where_values << params[:log_owner]
      @grid_caption << " Log-Owner='#{params[:log_owner]}'"
    end

    if params[:log_table]
      where_string << " AND l.Log_Table = ?"
      where_values << params[:log_table]
      @grid_caption << " Log-Table='#{params[:log_table]}'"
    end

    @snaps = sql_select_iterator ["\
      SELECT l.*, l.object_id contains_object_id,
             m.Owner mv_Owner, m.Name MV_Name, m.MView_Site
      FROM   DBA_Snapshot_Logs l
      LEFT OUTER JOIN DBA_Registered_MViews m ON m.MView_ID = l.Snapshot_ID
      WHERE  1=1 #{where_string}
      "].concat where_values

    render_partial :list_snapshot_logs
  end

  def list_registered_mview_query_text
    @mview_id = params[:mview_id]

    text = sql_select_one ["\
      SELECT m.query_txt
      FROM   sys.dba_registered_mviews m
      WHERE  MView_ID = ?
      ", @mview_id]

    respond_to do |format|
      format.html {render :html => render_yellow_pre(text)}
    end
  end

  # Ermittlung und Anzeige der realen Größe
  def list_real_num_rows
    object_owner = params[:owner]
    object_name  = params[:name]
    object_type  = params[:object_type]
    object_type  = 'TABLE' if object_type.nil? || object_type == ''

    case object_type
      when 'TABLE' then
        num_rows = sql_select_one ["\
          SELECT /*+ PARALLEL_INDEX(l,2) */ COUNT(*)
          FROM   #{object_owner}.#{object_name} l"]
      when 'INDEX' then
        expr = ''
        table_owner = ''
        table_name = ''
        sql_select_all(["\
        SELECT ie.Column_Expression, ic.Column_Name, ic.Table_Owner, ic.Table_Name
        FROM   DBA_Ind_Columns ic
        LEFT OUTER JOIN DBA_Ind_Expressions ie ON ie.Index_Owner = ic.Index_Owner AND ie.Index_Name=ic.Index_Name AND ie.Column_Position = ic.Column_Position
        WHERE  ic.Index_Owner = ?
        AND    ic.Index_Name  = ?
        ORDER BY ic.Column_Position", object_owner, object_name]).each do |rec|
          expr = "#{expr}||#{rec.column_expression ? rec.column_expression : rec.column_name}"
          table_owner = rec.table_owner
          table_name  = rec.table_name
        end

        expr = expr[2, expr.length-2]                                           # remove first two characters
        num_rows = sql_select_one ["\
          SELECT /*+ PARALLEL_INDEX(l,2) */ COUNT(#{expr})
          FROM   #{table_owner}.#{table_name} l"]
      else
        raise PopupMessageException.new("Unsupported object type '#{object_type}'")
    end

    respond_to do |format|
      format.html {render :html => "real:&nbsp;#{fn num_rows}".html_safe}
    end
  end

  # Nutzung von Datafiles
  def datafile_usage
    @datafiles = sql_select_iterator("\
      SELECT /* Panorama-Tool Ramm */
             d.*,
             NVL(f.BYTES,0)/1048576            MBFree,
             (d.BYTES-NVL(f.BYTES,0))/1048576  MBUsed,
             d.BYTES/1048576                   FileSize,
             (d.Bytes-NVL(f.Bytes,0))/d.BYTES  PctUsed,
             MaxBytes/1048576                  MaxMB,
             Increment_By/1048576              Increment_ByMB
      FROM   (SELECT File_Name, File_ID, Tablespace_Name, Bytes, Blocks,
                     Status, AutoExtensible, MaxBytes, Increment_By, Online_Status
              FROM   DBA_Data_Files
              UNION ALL
              SELECT File_Name, File_ID, Tablespace_Name, Bytes, Blocks,
                     Status, AutoExtensible, MaxBytes, Increment_By, '[UNKNOWN]' Online_Status
              FROM   DBA_Temp_Files
             )d
      LEFT JOIN (SELECT File_ID, Tablespace_Name, SUM(Bytes) Bytes
                 FROM   DBA_FREE_SPACE
                 GROUP BY File_ID, Tablespace_Name
                ) f ON f.FILE_ID = d.FILE_ID AND f.Tablespace_Name = d.Tablespace_Name -- DATA und Temp verwenden File_ID redundant
      ORDER BY 1 ASC")

    if get_db_version >= "11.2"
      @file_usage = sql_select_iterator "\
        SELECT f.*,
               NVL(d.File_Name, t.File_Name) File_Name,
               NVL(d.Tablespace_Name, t.Tablespace_Name) Tablespace_Name
        FROM   gv$IOStat_File f
        LEFT JOIN DBA_Data_Files d ON d.File_ID = f.File_No AND f.FileType_Name='Data File'   -- DATA und Temp verwenden File_ID redundant
        LEFT JOIN DBA_Temp_Files t ON t.File_ID = f.File_No AND f.FileType_Name='Temp File'
        ORDER BY f.Inst_ID, f.File_No
      "
    end

    render_partial
  end

  # Nutzung von Undo-Segmenten
  def undo_usage
    @undo_tablespaces = sql_select_iterator("\
      SELECT /* Panorama-Tool Ramm */
             Owner, Tablespace_Name,
             SUM(Bytes)/(1024*1024) Size_MB,
             SUM(DECODE(Status, 'UNEXPIRED', Bytes, 0))/(1024*1024) Size_MB_UnExpired,
             SUM(DECODE(Status, 'EXPIRED',   Bytes, 0))/(1024*1024) Size_MB_Expired,
             SUM(DECODE(Status, 'ACTIVE',    Bytes, 0))/(1024*1024) Size_MB_Active,
             (SELECT Inst_ID FROM gv$Parameter p WHERE Name='undo_tablespace' AND p.Value = e.Tablespace_Name) Inst_ID
      FROM   DBA_UNDO_Extents e
      GROUP BY Owner, Tablespace_Name
      ORDER BY SUM(Bytes) DESC")

    @undo_segments = sql_select_iterator("\
      SELECT /* Panorama-Tool Ramm */ i.*, t.Transactions, r.Segment_ID,
             (SELECT Inst_ID FROM gv$Parameter p WHERE Name='undo_tablespace' AND p.Value = i.Tablespace_Name) Inst_ID
      FROM   (SELECT
                     Owner, Segment_Name, Tablespace_Name,
                     SUM(Bytes)/(1024*1024) Size_MB,
                     SUM(DECODE(Status, 'UNEXPIRED', Bytes, 0))/(1024*1024) Size_MB_UnExpired,
                     SUM(DECODE(Status, 'EXPIRED',   Bytes, 0))/(1024*1024) Size_MB_Expired,
                     SUM(DECODE(Status, 'ACTIVE',    Bytes, 0))/(1024*1024) Size_MB_Active
              FROM   DBA_UNDO_Extents e
              GROUP BY Owner, Segment_Name, Tablespace_Name
            ) i
      LEFT OUTER JOIN DBA_Rollback_Segs r ON r.Segment_Name = i.Segment_Name
      LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ XidUsn, COUNT(*) Transactions FROM gv$Transaction GROUP BY XidUsn) t ON t.XidUsn = r.Segment_ID
      ORDER BY Size_MB DESC")

    render_partial
  end

  def list_undo_history
    save_session_time_selection
    @instance = prepare_param_instance
    @instance = nil if @instance == ''

    @undo_history = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
             Begin_Time, End_Time, Instance_Number, UndoBlks, TxnCount, MaxQueryLen, MaxQuerySQLID,
             MaxConcurrency, UnxpStealCnt, UnxpBlkRelCnt, UnxpBlkReuCnt, ExpStealCnt, ExpBlkRelCnt, ExpBlkReuCnt,
             SSOldErrCnt, NoSpaceErrCnt, ActiveBlks, UnexpiredBlks, ExpiredBlks, Tuned_UndoRetention
      FROM   DBA_Hist_UndoStat
      WHERE  Begin_Time BETWEEN TO_DATE(?, '#{sql_datetime_minute_mask}') AND TO_DATE(?, '#{sql_datetime_minute_mask}')
      #{'AND Instance_Number = ?' if @instance}
      ORDER BY Begin_Time
      ", @time_selection_start, @time_selection_end].concat(@instance ? [@instance] : [])

    render_partial
  end

  def list_undo_transactions
    @segment_id = params[:segment_id]
    @segment_id = nil if @segment_id == ''

    @undo_transactions = sql_select_iterator ["\
      SELECT /* Panorama-Tool Ramm */
             s.Inst_ID, s.SID, s.Serial# SerialNo, s.UserName, s.Program, s.Status, s.OSUser, s.Client_Info, s.Module, s.Action,
             t.Start_Time, t.Recursive, t.Used_Ublk Used_Undo_Blocks, t.Used_URec Used_Undo_Records, t.Log_IO, t.Phy_IO, RawToHex(t.XID) XID,
             t.XIDUSN Segment, t.XIDSLOT Slot, t.XIDSQN Sequence, t.CR_get, t.CR_Change
      FROM   v$Transaction t
      JOIN   gv$Session s ON s.TAddr = t.Addr
      #{'WHERE  t.XIDUsn = ?' if @segment_id}
      ORDER BY t.Used_Ublk DESC
      "].concat(@segment_id ? [@segment_id] : [])

    render_partial
  end

  def temp_usage
    @sort_segs = sql_select_all "\
        SELECT /* Panorama-Tool Ramm */ s.*,
               t.Block_Size
        FROM   gv$Sort_Segment s
        JOIN   DBA_Tablespaces t ON t.Tablespace_Name = s.Tablespace_Name
        ORDER BY Used_Blocks DESC
    "

    @temp_ts_size = sql_select_one "\
        SELECT SUM(Size_MB) Size_MB
        FROM   (
                SELECT /* Panorama-Tool Ramm */  SUM(d.Bytes)/1048576 Size_MB
                FROM DBA_Data_Files d
                WHERE d.Tablespace_Name IN (SELECT Tablespace_Name FROM gv$Sort_Segment)
                UNION ALL
                SELECT /* Panorama-Tool Ramm */  SUM(d.Bytes)/1048576 Size_MB
                FROM DBA_Temp_Files d
                WHERE d.Tablespace_Name IN (SELECT Tablespace_Name FROM gv$Sort_Segment)
               )
        "


    @data = sql_select_all "\
        SELECT /* Panorama-Tool Ramm */ t.INST_ID,
        s.SID,
        s.Serial# SerialNo,
        NVL(s.SQL_ID, s.Prev_SQL_ID) SQL_ID,
        NVL(s.SQL_Child_Number, s.Prev_Child_Number) Child_Number,
        s.UserName,
        s.Status,
        s.OSUser,
        s.Process,
        s.Machine,
        s.Program,
        SYSDATE - (s.Last_Call_Et/86400) Last_Call,
        t.Tablespace,
        t.SegType,
        t.Extents,
        t.Blocks
        FROM GV$TempSeg_Usage t,
             gv$session s
        WHERE s.Inst_ID = t.Inst_ID
        AND   s.SAddr = t.Session_Addr
        ORDER BY t.Blocks DESC
      "

    render_partial
  end

  def list_exadata_cell_server
    where_string = ''
    where_values = []
    @filter      = ''

    if params[:cellname]
      where_string << " AND c.CellName = ?"
      where_values << params[:cellname]
      @filter << " cell='#{params[:cellname]}'"
    end


    @cell_servers = sql_select_all ["\
      WITH Phys_Disks AS (SELECT /*+ NO_MERGE MATERIALIZE */
                                 c.cellname,
                                 CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/name/text()')                          AS VARCHAR2(100)) diskname,
                                 CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/diskType/text()')                      AS VARCHAR2(100)) diskType,
                                 CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalSize/text()')                  AS VARCHAR2(100)) physicalSize,
                                 CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/id/text()')                            AS VARCHAR2(100)) id
                          FROM   v$cell_config c,
                                 TABLE(XMLSEQUENCE(EXTRACT(XMLTYPE(c.confval), '/cli-output/physicaldisk'))) v
                          WHERE  c.conftype = 'PHYSICALDISKS'
                         ),
           Cell_Disks AS (SELECT /*+ NO_MERGE MATERIALIZE */
                                  c.cellname cd_cellname
                                , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/name/text()')                              AS VARCHAR2(100)) cd_name
                                , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/errorCount     /text()')                   AS VARCHAR2(100)) cd_errorCount
                                , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/freeSpace      /text()')                   AS VARCHAR2(100)) cd_freeSpace
                                , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/id             /text()')                   AS VARCHAR2(100)) cd_id
                                , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/physicalDisk   /text()')                   AS VARCHAR2(100)) cd_physicalDisk
                                , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/size           /text()')                   AS VARCHAR2(100)) cd_disk_size
                          FROM   v$cell_config c,
                                 TABLE(XMLSEQUENCE(EXTRACT(XMLTYPE(c.confval), '/cli-output/celldisk'))) v  -- gv$ isn't needed, all cells should be visible in all instances
                          WHERE  c.conftype = 'CELLDISKS'
                         ),
           Grid_Disks AS (SELECT /*+ NO_MERGE MATERIALIZE */
                              c.cellname gd_CellName
                            , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/name/text()')                               AS VARCHAR2(100)) gd_name
                            , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/cellDisk        /text()')                   AS VARCHAR2(100)) gd_cellDisk
                            , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/errorCount      /text()')                   AS VARCHAR2(100)) gd_errorCount
                            , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/size            /text()')                   AS VARCHAR2(100)) gd_disk_size
                          FROM
                              v$cell_config c
                            , TABLE(XMLSEQUENCE(EXTRACT(XMLTYPE(c.confval), '/cli-output/griddisk'))) v  -- gv$ isn't needed, all cells should be visible in all instances
                          WHERE  c.conftype = 'GRIDDISKS'
                         )
      SELECT /* Panorama-Tool Ramm */
             c.CellName,
             CAST(extract(xmltype(confval), '/cli-output/cell/name/text()')                 AS VARCHAR2(200)) Cell_Name,
             CAST(extract(xmltype(confval), '/cli-output/cell/cellVersion/text()')          AS VARCHAR2(200)) Cell_Version,
             CAST(extract(xmltype(confval), '/cli-output/cell/cpuCount/text()')             AS VARCHAR2(200)) CPU_Count,
             CAST(extract(xmltype(confval), '/cli-output/cell/memoryGB/text()')             AS VARCHAR2(200)) memoryGB,
             CAST(extract(xmltype(confval), '/cli-output/cell/diagHistoryDays/text()')      AS VARCHAR2(200)) diagHistoryDays,
             CAST(extract(xmltype(confval), '/cli-output/cell/flashCacheMode/text()')       AS VARCHAR2(200)) flashCacheMode,
             CAST(extract(xmltype(confval), '/cli-output/cell/interconnectCount/text()')    AS VARCHAR2(200)) interconnectCount,
             CAST(extract(xmltype(confval), '/cli-output/cell/kernelVersion/text()')        AS VARCHAR2(200)) kernelVersion,
             CAST(extract(xmltype(confval), '/cli-output/cell/makeModel/text()')            AS VARCHAR2(200)) makeModel,
             CAST(extract(xmltype(confval), '/cli-output/cell/notificationMethod/text()')   AS VARCHAR2(200)) notificationMethod,
             CAST(extract(xmltype(confval), '/cli-output/cell/notificationPolicy/text()')   AS VARCHAR2(200)) notificationPolicy,
             CAST(extract(xmltype(confval), '/cli-output/cell/snmpSubscriber/text()')       AS VARCHAR2(1000)) snmpSubscriber,
             CAST(extract(xmltype(confval), '/cli-output/cell/status/text()')               AS VARCHAR2(200)) status,
             CAST(extract(xmltype(confval), '/cli-output/cell/upTime/text()')               AS VARCHAR2(200)) upTime,
             CAST(extract(xmltype(confval), '/cli-output/cell/temperatureReading/text()')   AS VARCHAR2(200)) temperatureReading,
             d.total_gb_FlashDisk, d.total_gb_HardDisk, d.num_FlashDisks, d.num_HardDisks,
             cd.cd_Cell_Disk_Count, cd.cd_disk_size, cd.cd_freeSpace, cd.cd_errorCount,
             gd.gd_Grid_Disk_Count, gd.gd_disk_size
      FROM   v$Cell_Config c
      LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ cellname,
                              ROUND(SUM(CASE WHEN diskType = 'FlashDisk' THEN physicalsize END/1024/1024/1024)) total_gb_FlashDisk,
                              ROUND(SUM(CASE WHEN diskType = 'HardDisk'  THEN physicalsize END/1024/1024/1024)) total_gb_HardDisk,
                              SUM(CASE WHEN diskType = 'FlashDisk'  THEN 1 END) num_FlashDisks,
                              SUM(CASE WHEN diskType = 'HardDisk'  THEN 1 END) num_HardDisks
                       FROM   Phys_Disks
                       GROUP BY cellname
                      ) d ON d.CellName = c.CellName
      LEFT OUTER JOIN (SELECT cd.cd_CellName,
                              COUNT(*)           cd_Cell_Disk_Count,
                              SUM(cd_disk_size)  cd_disk_size,
                              SUM(cd_freeSpace)  cd_freeSpace,
                              SUM(cd_errorCount) cd_errorCount
                       FROM   Cell_disks cd
                       GROUP BY cd.cd_CellName
                      ) cd ON cd.cd_CellName = c.CellName
      LEFT OUTER JOIN (SELECT gd.gd_CellName,
                              COUNT(*)             gd_Grid_Disk_Count,
                              SUM(gd.gd_disk_size) gd_disk_size
                       FROM   Grid_Disks gd
                       GROUP BY gd.gd_CellName
                      ) gd ON gd.gd_CellName = c.CellName
      WHERE  c.ConfType = 'CELL'
      #{where_string}
      ORDER BY c.CellName
    "].concat(where_values)

    render_partial
  end

  def list_exadata_cell_physical_disk
    where_string = ''
    where_values = []
    @filter      = ''

    if params[:cellname]
      where_string << " AND pd.CellName = ?"
      where_values << params[:cellname]
      @filter << " cell='#{params[:cellname]}'"
    end

    if params[:disktype]
      where_string << " AND pd.DiskType = ?"
      where_values << params[:disktype]
      @filter << " disktype='#{params[:disktype]}'"
    end

    if params[:physical_disk_id]
      where_string << " AND pd.ID = ?"
      where_values << params[:physical_disk_id]
      @filter << " phys. disk ID='#{params[:physical_disk_id]}'"
    end



    @disks = sql_select_all ["\
      WITH Cell_Disks AS (SELECT /*+ NO_MERGE MATERIALIZE */
                                  c.cellname cd_cellname
                                , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/name/text()')                              AS VARCHAR2(100)) cd_name
                                , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/errorCount     /text()')                   AS VARCHAR2(100)) cd_errorCount
                                , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/freeSpace      /text()')                   AS VARCHAR2(100)) cd_freeSpace
                                , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/id             /text()')                   AS VARCHAR2(100)) cd_id
                                , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/physicalDisk   /text()')                   AS VARCHAR2(100)) cd_physicalDisk
                                , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/size           /text()')                   AS VARCHAR2(100)) cd_disk_size
                          FROM   v$cell_config c,
                                 TABLE(XMLSEQUENCE(EXTRACT(XMLTYPE(c.confval), '/cli-output/celldisk'))) v  -- gv$ isn't needed, all cells should be visible in all instances
                          WHERE  c.conftype = 'CELLDISKS'
                         ),
           Grid_Disks AS (SELECT /*+ NO_MERGE MATERIALIZE */
                              c.cellname gd_CellName
                            , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/name/text()')                               AS VARCHAR2(100)) gd_name
                            , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/cellDisk        /text()')                   AS VARCHAR2(100)) gd_cellDisk
                            , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/errorCount      /text()')                   AS VARCHAR2(100)) gd_errorCount
                            , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/size            /text()')                   AS VARCHAR2(100)) gd_disk_size
                          FROM
                              v$cell_config c
                            , TABLE(XMLSEQUENCE(EXTRACT(XMLTYPE(c.confval), '/cli-output/griddisk'))) v  -- gv$ isn't needed, all cells should be visible in all instances
                          WHERE  c.conftype = 'GRIDDISKS'
                         )
      SELECT /* Panorama-Tool Ramm */ pd.*, cd.*, gd.*
      FROM   (SELECT /*+ NO_MERGE */
                      c.cellname
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/name/text()')                          AS VARCHAR2(20)) diskname
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/diskType/text()')                      AS VARCHAR2(20)) diskType
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/luns/text()')                          AS VARCHAR2(20)) luns
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/makeModel/text()')                     AS VARCHAR2(50)) makeModel
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalFirmware/text()')              AS VARCHAR2(20)) physicalFirmware
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalInsertTime/text()')            AS VARCHAR2(30)) physicalInsertTime
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalSerial/text()')                AS VARCHAR2(20)) physicalSerial
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalSize/text()')                  AS VARCHAR2(20)) physicalSize
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/slotNumber/text()')                    AS VARCHAR2(30)) slotNumber
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/status/text()')                        AS VARCHAR2(20)) status
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/id/text()')                            AS VARCHAR2(20)) id
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/key_500/text()')                       AS VARCHAR2(20)) key_500
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/predfailStatus/text()')                AS VARCHAR2(20)) predfailStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/poorPerfStatus/text()')                AS VARCHAR2(20)) poorPerfStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/wtCachingStatus/text()')               AS VARCHAR2(20)) wtCachingStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/peerFailStatus/text()')                AS VARCHAR2(20)) peerFailStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/criticalStatus/text()')                AS VARCHAR2(20)) criticalStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errCmdTimeoutCount/text()')            AS VARCHAR2(20)) errCmdTimeoutCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errHardReadCount/text()')              AS VARCHAR2(20)) errHardReadCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errHardWriteCount/text()')             AS VARCHAR2(20)) errHardWriteCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errMediaCount/text()')                 AS VARCHAR2(20)) errMediaCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errOtherCount/text()')                 AS VARCHAR2(20)) errOtherCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errSeekCount/text()')                  AS VARCHAR2(20)) errSeekCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/sectorRemapCount/text()')              AS VARCHAR2(20)) sectorRemapCount
              FROM   v$cell_config c,
                     TABLE(XMLSEQUENCE(EXTRACT(XMLTYPE(c.confval), '/cli-output/physicaldisk'))) v
              WHERE  c.conftype = 'PHYSICALDISKS'
             ) pd
      LEFT OUTER JOIN ( SELECT cd_CellName, cd_physicalDisk,
                               COUNT(*)           cd_Cell_Disk_Count,
                               SUM(cd_disk_size)  cd_disk_size,
                               SUM(cd_freeSpace)  cd_freeSpace,
                               SUM(cd_errorCount) cd_errorCount
                        FROM   Cell_disks
                        GROUP BY cd_CellName, cd_physicalDisk
                      ) cd ON cd.cd_CellName = pd.CellName AND cd.cd_physicalDisk = pd.ID
      LEFT OUTER JOIN ( SELECT cd.cd_CellName, cd.cd_physicalDisk,
                               COUNT(*)             gd_Grid_Disk_Count,
                               SUM(gd.gd_disk_size) gd_disk_size
                        FROM   Grid_Disks gd
                        JOIN   Cell_Disks cd ON cd.cd_CellName = gd.gd_CellName AND cd.cd_Name = gd.gd_CellDisk
                        GROUP BY cd.cd_CellName, cd.cd_physicalDisk
                      ) gd ON gd.cd_cellName = pd.CellName AND gd.cd_physicalDisk = pd.ID
      WHERE 1=1
      #{where_string}
    "].concat(where_values)

    render_partial
  end

  def list_exadata_cell_cell_disk
    where_string = ''
    where_values = []
    @filter      = ''

    if params[:cellname]
      where_string << " AND pd.CellName = ?"
      where_values << params[:cellname]
      @filter << " cell='#{params[:cellname]}'"
    end

    if params[:disktype]
      where_string << " AND pd.DiskType = ?"
      where_values << params[:disktype]
      @filter << " disktype='#{params[:disktype]}'"
    end

    if params[:physical_disk_id]
      where_string << " AND pd.ID = ?"
      where_values << params[:physical_disk_id]
      @filter << " phys. disk ID='#{params[:physical_disk_id]}'"
    end

    if params[:cell_disk_name]
      where_string << " AND cd.cd_Name = ?"
      where_values << params[:cell_disk_name]
      @filter << " cell disk name='#{params[:cell_disk_name]}'"
    end


    @disks = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ pd.*, cd.*, gd.*
      FROM   (SELECT /*+ NO_MERGE */
                      c.cellname
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/name/text()')                          AS VARCHAR2(20)) diskname
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/diskType/text()')                      AS VARCHAR2(20)) diskType
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/luns/text()')                          AS VARCHAR2(20)) luns
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/makeModel/text()')                     AS VARCHAR2(50)) makeModel
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalFirmware/text()')              AS VARCHAR2(20)) physicalFirmware
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalInsertTime/text()')            AS VARCHAR2(30)) physicalInsertTime
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalSerial/text()')                AS VARCHAR2(20)) physicalSerial
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalSize/text()')                  AS VARCHAR2(20)) physicalSize
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/slotNumber/text()')                    AS VARCHAR2(30)) slotNumber
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/status/text()')                        AS VARCHAR2(20)) status
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/id/text()')                            AS VARCHAR2(20)) id
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/key_500/text()')                       AS VARCHAR2(20)) key_500
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/predfailStatus/text()')                AS VARCHAR2(20)) predfailStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/poorPerfStatus/text()')                AS VARCHAR2(20)) poorPerfStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/wtCachingStatus/text()')               AS VARCHAR2(20)) wtCachingStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/peerFailStatus/text()')                AS VARCHAR2(20)) peerFailStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/criticalStatus/text()')                AS VARCHAR2(20)) criticalStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errCmdTimeoutCount/text()')            AS VARCHAR2(20)) errCmdTimeoutCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errHardReadCount/text()')              AS VARCHAR2(20)) errHardReadCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errHardWriteCount/text()')             AS VARCHAR2(20)) errHardWriteCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errMediaCount/text()')                 AS VARCHAR2(20)) errMediaCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errOtherCount/text()')                 AS VARCHAR2(20)) errOtherCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errSeekCount/text()')                  AS VARCHAR2(20)) errSeekCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/sectorRemapCount/text()')              AS VARCHAR2(20)) sectorRemapCount
              FROM   v$cell_config c,
                     TABLE(XMLSEQUENCE(EXTRACT(XMLTYPE(c.confval), '/cli-output/physicaldisk'))) v
              WHERE  c.conftype = 'PHYSICALDISKS'
             ) pd
      JOIN (
            SELECT /*+ NO_MERGE */
                    c.cellname cd_cellname
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/name/text()')                              AS VARCHAR2(100)) cd_name
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/comment        /text()')                   AS VARCHAR2(100)) cd_disk_comment
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/creationTime   /text()')                   AS VARCHAR2(100)) cd_creationTime
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/deviceName     /text()')                   AS VARCHAR2(100)) cd_deviceName
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/devicePartition/text()')                   AS VARCHAR2(100)) cd_devicePartition
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/diskType       /text()')                   AS VARCHAR2(100)) cd_diskType
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/errorCount     /text()')                   AS VARCHAR2(100)) cd_errorCount
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/freeSpace      /text()')                   AS VARCHAR2(100)) cd_freeSpace
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/id             /text()')                   AS VARCHAR2(100)) cd_id
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/interleaving   /text()')                   AS VARCHAR2(100)) cd_interleaving
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/lun            /text()')                   AS VARCHAR2(100)) cd_lun
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/physicalDisk   /text()')                   AS VARCHAR2(100)) cd_physicalDisk
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/size           /text()')                   AS VARCHAR2(100)) cd_disk_size
                  , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/status         /text()')                   AS VARCHAR2(100)) cd_status
            FROM   v$cell_config c,
                   TABLE(XMLSEQUENCE(EXTRACT(XMLTYPE(c.confval), '/cli-output/celldisk'))) v  -- gv$ isn't needed, all cells should be visible in all instances
            WHERE  c.conftype = 'CELLDISKS'
          ) cd ON cd.cd_CellName = pd.CellName AND cd.cd_physicalDisk = pd.ID
      LEFT OUTER JOIN ( SELECT gd_CellName, gd_CellDisk,
                               COUNT(*)             gd_Grid_Disk_Count,
                               SUM(gd.gd_disk_size) gd_disk_size
                        FROM   (SELECT /*+ NO_MERGE MATERIALIZE */
                                        c.cellname gd_CellName
                                      , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/name/text()')                               AS VARCHAR2(100)) gd_name
                                      , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/cellDisk        /text()')                   AS VARCHAR2(100)) gd_cellDisk
                                      , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/errorCount      /text()')                   AS VARCHAR2(100)) gd_errorCount
                                      , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/size            /text()')                   AS VARCHAR2(100)) gd_disk_size
                                FROM   v$cell_config c,
                                       TABLE(XMLSEQUENCE(EXTRACT(XMLTYPE(c.confval), '/cli-output/griddisk'))) v  -- gv$ isn't needed, all cells should be visible in all instances
                                WHERE  c.conftype = 'GRIDDISKS'
                               )gd
                        GROUP BY gd_CellName, gd_CellDisk
                      ) gd ON gd.gd_cellName = cd.cd_CellName AND gd.gd_CellDisk = cd.cd_Name
      WHERE 1=1
      #{where_string}
    "].concat(where_values)

    render_partial
  end

  def list_exadata_cell_grid_disk
    where_string = ''
    where_values = []
    @filter      = ''

    if params[:cellname]
      where_string << " AND pd.CellName = ?"
      where_values << params[:cellname]
      @filter << " cell='#{params[:cellname]}'"
    end

    if params[:disktype]
      where_string << " AND pd.DiskType = ?"
      where_values << params[:disktype]
      @filter << " disktype='#{params[:disktype]}'"
    end

    if params[:physical_disk_id]
      where_string << " AND pd.ID = ?"
      where_values << params[:physical_disk_id]
      @filter << " phys. disk ID='#{params[:physical_disk_id]}'"
    end

    if params[:cell_disk_name]
      where_string << " AND cd.cd_Name = ?"
      where_values << params[:cell_disk_name]
      @filter << " cell disk name='#{params[:cell_disk_name]}'"
    end

    @disks = sql_select_all ["\
      SELECT /* Panorama-Tool Ramm */ pd.*, cd.*, gd.*, adg.Name ASM_Disk_Group_Name
      FROM   (SELECT /*+ NO_MERGE */
                      c.cellname
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/name/text()')                          AS VARCHAR2(20)) diskname
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/diskType/text()')                      AS VARCHAR2(20)) diskType
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/luns/text()')                          AS VARCHAR2(20)) luns
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/makeModel/text()')                     AS VARCHAR2(50)) makeModel
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalFirmware/text()')              AS VARCHAR2(20)) physicalFirmware
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalInsertTime/text()')            AS VARCHAR2(30)) physicalInsertTime
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalSerial/text()')                AS VARCHAR2(20)) physicalSerial
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/physicalSize/text()')                  AS VARCHAR2(20)) physicalSize
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/slotNumber/text()')                    AS VARCHAR2(30)) slotNumber
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/status/text()')                        AS VARCHAR2(20)) status
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/id/text()')                            AS VARCHAR2(20)) id
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/key_500/text()')                       AS VARCHAR2(20)) key_500
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/predfailStatus/text()')                AS VARCHAR2(20)) predfailStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/poorPerfStatus/text()')                AS VARCHAR2(20)) poorPerfStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/wtCachingStatus/text()')               AS VARCHAR2(20)) wtCachingStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/peerFailStatus/text()')                AS VARCHAR2(20)) peerFailStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/criticalStatus/text()')                AS VARCHAR2(20)) criticalStatus
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errCmdTimeoutCount/text()')            AS VARCHAR2(20)) errCmdTimeoutCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errHardReadCount/text()')              AS VARCHAR2(20)) errHardReadCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errHardWriteCount/text()')             AS VARCHAR2(20)) errHardWriteCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errMediaCount/text()')                 AS VARCHAR2(20)) errMediaCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errOtherCount/text()')                 AS VARCHAR2(20)) errOtherCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/errSeekCount/text()')                  AS VARCHAR2(20)) errSeekCount
                    , CAST(EXTRACTVALUE(VALUE(v), '/physicaldisk/sectorRemapCount/text()')              AS VARCHAR2(20)) sectorRemapCount
              FROM   v$cell_config c,
                     TABLE(XMLSEQUENCE(EXTRACT(XMLTYPE(c.confval), '/cli-output/physicaldisk'))) v
              WHERE  c.conftype = 'PHYSICALDISKS'
             ) pd
      JOIN (
                        SELECT /*+ NO_MERGE */
                                c.cellname cd_cellname
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/name/text()')                              AS VARCHAR2(100)) cd_name
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/comment        /text()')                   AS VARCHAR2(100)) cd_disk_comment
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/creationTime   /text()')                   AS VARCHAR2(100)) cd_creationTime
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/deviceName     /text()')                   AS VARCHAR2(100)) cd_deviceName
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/devicePartition/text()')                   AS VARCHAR2(100)) cd_devicePartition
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/diskType       /text()')                   AS VARCHAR2(100)) cd_diskType
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/errorCount     /text()')                   AS VARCHAR2(100)) cd_errorCount
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/freeSpace      /text()')                   AS VARCHAR2(100)) cd_freeSpace
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/id             /text()')                   AS VARCHAR2(100)) cd_id
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/interleaving   /text()')                   AS VARCHAR2(100)) cd_interleaving
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/lun            /text()')                   AS VARCHAR2(100)) cd_lun
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/physicalDisk   /text()')                   AS VARCHAR2(100)) cd_physicalDisk
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/size           /text()')                   AS VARCHAR2(100)) cd_disk_size
                              , CAST(EXTRACTVALUE(VALUE(v), '/celldisk/status         /text()')                   AS VARCHAR2(100)) cd_status
                        FROM   v$cell_config c,
                               TABLE(XMLSEQUENCE(EXTRACT(XMLTYPE(c.confval), '/cli-output/celldisk'))) v  -- gv$ isn't needed, all cells should be visible in all instances
                        WHERE  c.conftype = 'CELLDISKS'
                      ) cd ON cd.cd_CellName = pd.CellName AND cd.cd_physicalDisk = pd.ID
      JOIN (
                        SELECT /*+ NO_MERGE */
                            c.cellname gd_CellName
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/name/text()')                               AS VARCHAR2(100)) gd_name
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/asmDiskgroupName/text()')                   AS VARCHAR2(100)) gd_asmDiskgroupName
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/asmDiskName     /text()')                   AS VARCHAR2(100)) gd_asmDiskName
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/asmFailGroupName/text()')                   AS VARCHAR2(100)) gd_asmFailGroupName
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/availableTo     /text()')                   AS VARCHAR2(100)) gd_availableTo
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/cachingPolicy   /text()')                   AS VARCHAR2(100)) gd_cachingPolicy
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/cellDisk        /text()')                   AS VARCHAR2(100)) gd_cellDisk
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/comment         /text()')                   AS VARCHAR2(100)) gd_disk_comment
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/creationTime    /text()')                   AS VARCHAR2(100)) gd_creationTime
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/diskType        /text()')                   AS VARCHAR2(100)) gd_diskType
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/errorCount      /text()')                   AS VARCHAR2(100)) gd_errorCount
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/id              /text()')                   AS VARCHAR2(100)) gd_id
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/offset          /text()')                   AS VARCHAR2(100)) gd_offset
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/size            /text()')                   AS VARCHAR2(100)) gd_disk_size
                          , CAST(EXTRACTVALUE(VALUE(v), '/griddisk/status          /text()')                   AS VARCHAR2(100)) gd_status
                        FROM
                            v$cell_config c
                          , TABLE(XMLSEQUENCE(EXTRACT(XMLTYPE(c.confval), '/cli-output/griddisk'))) v  -- gv$ isn't needed, all cells should be visible in all instances
                        WHERE  c.conftype = 'GRIDDISKS'
                      ) gd ON gd.gd_cellName = pd.CellName AND gd.gd_CellDisk = cd.cd_Name
      LEFT OUTER JOIN v$ASM_Disk ad       ON ad.Name = gd.gd_ASMDiskName
      LEFT OUTER JOIN v$ASM_DiskGroup adg ON adg.Group_Number = ad.Group_Number
      WHERE 1=1
      #{where_string}
                             "].concat(where_values)

    render_partial
  end

  def list_temp_usage_sysmetric_historic
    save_session_time_selection

    recs = sql_select_all ["
      SELECT *
      FROM   (
              SELECT x.*, TRUNC(Group_Time+30/86400, 'MI') Normalized_Begin_Time
              FROM   (
                      SELECT Inst_ID Instance_Number, Begin_Time Group_Time, Begin_Time, End_Time, Value/(1024*1024) Value_MB
                      FROM gv$SysMetric_History
                      WHERE  Metric_Name = 'Temp Space Used'
                      AND    End_Time   >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}')
                      AND    Begin_Time <= TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
                      UNION ALL
                      SELECT s.Instance_Number, ss.Begin_Interval_Time Group_Time, s.Begin_Time, s.End_Time, s.MaxVal/(1024*1024) Value_MB
                      FROM   (SELECT /*+ NO_MERGE */ ss.DBID, ss.Instance_Number, ss.Snap_ID, ss.Begin_Interval_Time, ss.End_Interval_Time
                              FROM   DBA_Hist_Snapshot ss
                              JOIN   (SELECT /*+ NO_MERGE */ Inst_ID, MIN(Begin_Time) First_SGA_Time FROM gv$SysMetric_History GROUP BY Inst_ID) t ON t.Inst_ID = ss.Instance_Number /* use only for period not considered by gv$SysMetric_History */
                              WHERE  End_Interval_Time   >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}')
                              AND    Begin_Interval_Time <= TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
                              AND    ss.Begin_Interval_Time < t.First_SGA_Time
                              AND    ss.DBID = ?
                             ) ss
                      JOIN   DBA_Hist_SysMetric_Summary s ON s.DBID = ss.DBID AND s.Instance_Number = ss.Instance_Number AND s.Snap_ID = ss.Snap_ID
                      WHERE  s.Metric_Name = 'Temp Space Used'
                     ) x
             )
      ORDER BY Normalized_Begin_Time, Instance_Number
      ", @time_selection_start, @time_selection_end, @time_selection_start, @time_selection_end, get_dbid
    ]

    temp_usage = {}
    @instances = {}
    recs.each do |r|
      @instances[r.instance_number] = true
      temp_usage[r.normalized_begin_time]                                 = {:normalized_begin_time => r.normalized_begin_time, :total_used => 0, :total_allocated => 0} unless temp_usage[r.normalized_begin_time]
      temp_usage[r.normalized_begin_time][:total_used]                    += r.value_mb
      temp_usage[r.normalized_begin_time][:min_begin_time]                = r.begin_time if temp_usage[r.normalized_begin_time][:min_begin_time].nil? || temp_usage[r.normalized_begin_time][:min_begin_time] > r.begin_time
      temp_usage[r.normalized_begin_time][:max_end_time]                  = r.end_time   if temp_usage[r.normalized_begin_time][:max_end_time].nil?   || temp_usage[r.normalized_begin_time][:max_end_time]   < r.end_time
      temp_usage[r.normalized_begin_time][r.instance_number]              = {} unless temp_usage[r.normalized_begin_time][r.instance_number]
      temp_usage[r.normalized_begin_time][r.instance_number][:value_used] = r.value_mb
      temp_usage[r.normalized_begin_time][r.instance_number][:begin_time] = r.begin_time
      temp_usage[r.normalized_begin_time][r.instance_number][:end_time]   = r.end_time
    end

    alloc_recs = sql_select_all ["
      SELECT TRUNC(ss.Begin_Interval_Time+30/86400, 'MI') Normalized_Begin_Time, st.Instance_Number, ss.Begin_Interval_Time, ss.End_Interval_Time, st.Value/(1024*1024) Value_MB
      FROM   DBA_Hist_SysStat st
      JOIN   DBA_hist_SnapShot ss ON ss.DBID = st.DBID AND ss.Instance_Number = st.Instance_Number AND ss.Snap_ID = st.Snap_ID
      WHERE  st.Stat_ID = 280471097 /* temp space allocated (bytes) */
      AND    ss.End_Interval_Time   >= TO_DATE(?, '#{sql_datetime_mask(@time_selection_start)}')
      AND    ss.Begin_Interval_Time <= TO_DATE(?, '#{sql_datetime_mask(@time_selection_end)}')
      AND    ss.DBID = ?
      ORDER BY 1,2
      ", @time_selection_start, @time_selection_end, get_dbid]

    alloc_recs.each do |a|
      @instances[a.instance_number] = true
      temp_usage[a.normalized_begin_time]                                           = {:normalized_begin_time => a.normalized_begin_time, :total_used => 0, :total_allocated => 0} unless temp_usage[a.normalized_begin_time]
      temp_usage[a.normalized_begin_time][:total_allocated]                         += a.value_mb
      temp_usage[a.normalized_begin_time][:min_begin_interval_time]                = a.begin_interval_time if temp_usage[a.normalized_begin_time][:min_begin_interval_time].nil? || temp_usage[a.normalized_begin_time][:min_begin_interval_time] > a.begin_interval_time
      temp_usage[a.normalized_begin_time][:max_end_interval_time]                  = a.end_interval_time   if temp_usage[a.normalized_begin_time][:max_end_interval_time].nil?   || temp_usage[a.normalized_begin_time][:max_end_interval_time]   < a.end_interval_time
      temp_usage[a.normalized_begin_time][a.instance_number]                        = {} unless temp_usage[a.normalized_begin_time][a.instance_number]
      temp_usage[a.normalized_begin_time][a.instance_number][:value_allocated]      = a.value_mb
      temp_usage[a.normalized_begin_time][a.instance_number][:begin_interval_time]  = a.begin_interval_time
      temp_usage[a.normalized_begin_time][a.instance_number][:end_interval_time]    = a.end_interval_time
    end

    # Convert Hash to Array
    @temp_usage = []
    temp_usage.each do |key, value|
      value[:total_allocated] = nil if value[:total_allocated] == 0             # don't show 0 if no sample available for this timestamp
      @temp_usage << value
    end

    render_partial
  end

  def list_free_extents
    where_string = ''
    where_values = []
    @filter      = ''


    if params[:tablespace]
      where_string << " AND Tablespace_Name = ?"
      where_values << params[:tablespace]
      @filter << " Tablespace='#{params[:tablespace]}'"
    end

    @free_exts = sql_select_all ["
      WITH FRows AS (
              SELECT x.*,
                     TRUNC(Size_KB/64)            Extents_64K_Fit,
                     TRUNC(Size_KB/1024)          Extents_1M_Fit,
                     TRUNC(Size_KB/(8*1024))      Extents_8M_Fit,
                     TRUNC(Size_KB/(64*1024))     Extents_64M_Fit,
                     TRUNC(Size_KB/(256*1024))    Extents_256M_Fit
              FROM  (
                    SELECT w.*,
                           CASE
                             WHEN Categ='64K'  THEN 64
                             WHEN Categ='1M'   THEN 1024
                             WHEN Categ='8M'   THEN 8*1024
                             WHEN Categ='64M'  THEN 64*1024
                             WHEN Categ='256M' THEN 256*1024
                           END Extent_Size_KB
                    FROM   (
                            SELECT Tablespace_Name, Bytes/1024 Size_KB,
                                   CASE
                                        WHEN Bytes < 1024*1024      THEN '64K'
                                        WHEN Bytes < 8*1024*1024    THEN '1M'
                                        WHEN Bytes < 64*1024*1024   THEN '8M'
                                        WHEN Bytes < 256*1024*1024  THEN '64M'
                                   ELSE '256M'
                                   END Categ,
                                   CASE
                                        WHEN Bytes < 1024*1024      THEN 1
                                        WHEN Bytes < 8*1024*1024    THEN 2
                                        WHEN Bytes < 64*1024*1024   THEN 3
                                        WHEN Bytes < 256*1024*1024  THEN 4
                                   ELSE 5
                                   END Categ_Sort
                            FROM   DBA_Free_Space
                            WHERE 1=1 #{where_string}
                           ) w
                    ) x
      ),
      Fits AS (SELECT /*+ NO_MRGE */ c.Categ,
                      SUM(CASE
                      WHEN c.Categ = '64K'  THEN Extents_64K_Fit
                      WHEN c.Categ = '1M'   THEN Extents_1M_Fit
                      WHEN c.Categ = '8M'   THEN Extents_8M_Fit
                      WHEN c.Categ = '64M'  THEN Extents_64M_Fit
                      WHEN c.Categ = '256M' THEN Extents_256M_Fit
                     END) Number_Fits
              FROM   FRows
              CROSS JOIN (SELECT '64K' Categ FROM DUAL UNION ALL SELECT '1M' FROM DUAL UNION ALL SELECT '8M' FROM DUAL UNION ALL SELECT '64M' FROM DUAL UNION ALL SELECT '256M' FROM Dual) c
              GROUP BY c.Categ
             )
      SELECT y.*, f.Number_fits, f.Number_fits*Extent_Size_KB/1024 MB_Available_to_Create
      FROM   (
              SELECT Categ, Categ_Sort, Extent_Size_KB,  SUM(Size_KB) Size_KB, COUNT(*) Chunk_Num
              FROM  FRows  y
              GROUP BY Categ, Categ_Sort, Extent_Size_KB
             ) y
      JOIN  Fits f ON f.Categ = y.Categ
      ORDER BY Categ_Sort
      "].concat(where_values)

    render_partial
  end

  def list_object_extents
    @owner        = params[:owner]
    @segment_name = params[:segment_name]

    @extents = sql_select_all ["\
      SELECT Bytes/1024 Extent_Size_KB, COUNT(*) Extent_Count, SUM(Bytes)/1024 Total_Size_KB
      FROM   DBA_Extents
      WHERE  Owner        = ?
      AND    Segment_Name = ?
      GROUP BY Bytes
      ORDER BY Bytes
    ", @owner, @segment_name]

    render_partial
  end

end
