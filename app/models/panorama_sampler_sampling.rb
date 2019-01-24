class PanoramaSamplerSampling
  include PanoramaSampler::PackagePanoramaSamplerAsh
  include PanoramaSampler::PackagePanoramaSamplerSnapshot
  include PanoramaSampler::PackagePanoramaSamplerBlockingLocks
  include ExceptionHelper


  # call sampling method a'a do_object_size_sampling(snapshot_time)
  def self.do_sampling(sampler_config, snapshot_time, domain)
    PanoramaSamplerSampling.new(sampler_config).send("do_#{domain.downcase}_sampling".to_sym, snapshot_time)
  end

  # call housekeeping method a'a do_object_size_housekeeping(shrink_space)
  def self.do_housekeeping(sampler_config, shrink_space, domain)
    PanoramaSamplerSampling.new(sampler_config).send("do_#{domain.downcase}_housekeeping".to_sym, shrink_space)
  end

  def self.run_ash_daemon(sampler_config, snapshot_time)
    PanoramaSamplerSampling.new(sampler_config).run_ash_daemon_internal(snapshot_time)
  rescue Exception => e
    # try second time to fix error ORA-04068 existing state of package has changed ...
    PanoramaSamplerSampling.new(sampler_config).run_ash_daemon_internal(snapshot_time)
  end

  def initialize(sampler_config)
    @sampler_config = sampler_config
  end

  def do_awr_sampling(snapshot_time)
    last_snap = PanoramaConnection.sql_select_first_row ["SELECT Snap_ID, End_Interval_Time
                                                    FROM   #{@sampler_config.get_owner}.Panorama_Snapshot
                                                    WHERE  DBID=? AND Instance_Number=?
                                                    AND    Snap_ID = (SELECT MAX(Snap_ID) FROM #{@sampler_config.get_owner}.Panorama_Snapshot WHERE DBID=? AND Instance_Number=?)
                                                   ", PanoramaConnection.dbid, PanoramaConnection.instance_number, PanoramaConnection.dbid, PanoramaConnection.instance_number]

    if last_snap.nil?                                                           # First access
      @snap_id = 1
      begin_interval_time = (PanoramaConnection.sql_select_one "SELECT SYSDATE FROM Dual") - (@sampler_config.get_awr_ash_snapshot_cycle).minutes
    else
      @snap_id            = last_snap.snap_id + 1
      begin_interval_time = last_snap.end_interval_time
    end

    ## DBA_Hist_Snapshot, must be the first atomic transaction to ensure that next snap_id is exactly incremented
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config.get_owner}.Panorama_Snapshot (Snap_ID, DBID, Instance_Number, Startup_Time, Begin_Interval_Time, End_Interval_Time, Con_ID
                                    ) SELECT ?, ?, ?, Startup_Time, ?, SYSDATE, ? FROM v$Instance",
                                    @snap_id, PanoramaConnection.dbid, PanoramaConnection.instance_number, begin_interval_time, PanoramaConnection.con_id]

    do_snapshot_call = "Do_Snapshot(p_Snap_ID                   => ?,
                                    p_Instance                  => ?,
                                    p_DBID                      => ?,
                                    p_Con_DBID                  => ?,
                                    p_Con_ID                    => ?,
                                    p_Begin_Interval_Time       => ?,
                                    p_Snapshot_Cycle            => ?,
                                    p_Snapshot_Retention        => ?,
                                    p_SQL_Min_No_of_Execs       => ?,
                                    p_SQL_Min_Runtime_MilliSecs => ?
                                   )"

    if @sampler_config.get_select_any_table                                       # call PL/SQL package ?
      sql = " BEGIN #{@sampler_config.get_owner}.Panorama_Sampler_Snapshot.#{do_snapshot_call}; END;"
    else
      # replace PANORAMA. with the real owner in PL/SQL-Source
      sql = "
        DECLARE
        #{panorama_sampler_snapshot_code.gsub(/PANORAMA\./i, "#{@sampler_config.get_owner.upcase}.")}
        BEGIN
          #{do_snapshot_call};
        END;
        "
    end



    ## TODO: Con_DBID mit realen werten des Containers füllen, falls PDB-übergreifendes Sampling gewünscht wird
    PanoramaConnection.sql_execute [sql,
                                    @snap_id,
                                    PanoramaConnection.instance_number,
                                    PanoramaConnection.dbid,
                                    con_dbid,
                                    PanoramaConnection.con_id,
                                    begin_interval_time,
                                    @sampler_config.get_awr_ash_snapshot_cycle,
                                    @sampler_config.get_awr_ash_snapshot_retention,
                                    @sampler_config.get_sql_min_no_of_execs,
                                    @sampler_config.get_sql_min_runtime_millisecs
                                   ]
  end

  def do_awr_housekeeping(shrink_space)
    snapshots_to_delete = PanoramaConnection.sql_select_all ["SELECT Snap_ID FROM #{@sampler_config.get_owner}.Panorama_Snapshot WHERE DBID = ? AND Begin_Interval_Time < SYSDATE - ?", PanoramaConnection.dbid, @sampler_config.get_awr_ash_snapshot_retention]

    Rails.logger.info("PanoramaSampler_Sampling.do_awr_housekeeping with awr_ash_snapshot_retention=#{@sampler_config.get_awr_ash_snapshot_retention}")  if  ENV['RAILS_ENV'] == 'test'
    # Delete from tables with columns DBID and SNAP_ID
    snapshots_to_delete.each do |snapshot|
      PanoramaSamplerStructureCheck.tables.each do |table|
        if PanoramaSamplerStructureCheck.has_column?(table[:table_name], 'Snap_ID')
          execute_until_nomore ["DELETE FROM #{@sampler_config.get_owner}.#{table[:table_name]} WHERE DBID = ? AND Snap_ID <= ?", PanoramaConnection.dbid, snapshot.snap_id]
          exec_shrink_space(table[:table_name]) if shrink_space
        end
      end
    end
    # Delete from tables without columns DBID and SNAP_ID
    execute_until_nomore ["DELETE FROM #{@sampler_config.get_owner}.Panorama_SQL_Plan p
                           WHERE  DBID      = ?
                           AND    Con_DBID  = ?
                           AND    (SQL_ID, Plan_Hash_Value) NOT IN (SELECT SQL_ID, Plan_Hash_Value FROM #{@sampler_config.get_owner}.Panorama_SQLStat s
                                                 WHERE  s.DBID      = ?
                                                 AND    s.Con_DBID  = ?
                                                )
                          ", PanoramaConnection.dbid, con_dbid, PanoramaConnection.dbid, con_dbid]
    exec_shrink_space('Panorama_SQL_Plan') if shrink_space

    execute_until_nomore ["DELETE FROM #{@sampler_config.get_owner}.Panorama_SQLText t
                           WHERE  DBID      = ?
                           AND    Con_DBID  = ?
                           AND    SQL_ID NOT IN (SELECT SQL_ID FROM #{@sampler_config.get_owner}.Panorama_SQLStat s
                                                 WHERE  s.DBID      = ?
                                                 AND    s.Con_DBID  = ?
                                                )
                          ", PanoramaConnection.dbid, con_dbid, PanoramaConnection.dbid, con_dbid]
    exec_shrink_space('Panorama_SQLText') if shrink_space
  end

  # Run daemon, daeomon returns 1 second before next snapshot timestamp
  def run_ash_daemon_internal(snapshot_time)
    start_delay_from_snapshot = (Time.now - snapshot_time).round                # at seconds bound
    next_snapshot_start_seconds = @sampler_config.get_awr_ash_snapshot_cycle * 60 - start_delay_from_snapshot # Number of seconds until next snapshot start
    next_snapshot_start_seconds += 5                                            # Assume 5 seconds delay until start of sampling to fill with previous daemon

    if @sampler_config.get_select_any_table                                     # call PL/SQL package ?
      sql = " BEGIN #{@sampler_config.get_owner}.Panorama_Sampler_ASH.Run_Sampler_Daemon(?, ?, ?); END;"
    else
      sql = "
        DECLARE
        #{panorama_sampler_ash_code.gsub(/PANORAMA\./i, "#{@sampler_config.get_owner.upcase}.")}
        BEGIN
          Run_Sampler_Daemon(?, ?, ?);
        END;
        "
    end

    Rails.logger.info "#{Time.now}: Create new ASH daemon for ID=#{@sampler_config.get_id}, Name='#{@sampler_config.get_name}', Instance=#{PanoramaConnection.instance_number}, next_snapshot_start_seconds=#{next_snapshot_start_seconds}"

    PanoramaConnection.sql_execute [sql, PanoramaConnection.instance_number, PanoramaConnection.con_id, next_snapshot_start_seconds]
  end

  def do_object_size_sampling(snapshot_time)
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config.get_owner}.Panorama_Object_Sizes (Owner, Segment_Name, Segment_Type, Tablespace_Name, Gather_Date, Bytes, Num_Rows)
                                     SELECT s.*, n.Num_Rows
                                     FROM   (
                                             SELECT Owner, Segment_Name, Segment_Type, Tablespace_Name, TO_DATE(?, 'YYYY-MM-DD HH24:MI:SS'), NVL(SUM(Bytes), 0)
                                             FROM   DBA_Segments
                                             WHERE  Segment_Type NOT IN ('TYPE2 UNDO', 'TEMPORARY')
                                             GROUP BY Owner, Segment_Name, Segment_Type, Tablespace_Name
                                            ) s
                                     LEFT OUTER JOIN (
                                                      SELECT Owner, Index_Name Object_Name, Num_Rows, 'INDEX' Type
                                                      FROM DBA_Indexes
                                                      WHERE Num_Rows IS NOT NULL
                                                      UNION ALL
                                                      SELECT Owner, Table_Name Object_Name, Num_Rows, 'TABLE' Type
                                                      FROM DBA_Tables
                                                      WHERE Num_Rows IS NOT NULL
                                                      UNION ALL /* Num_Rows from table for LOBs */
                                                      SELECT l.Owner, l.Segment_Name Object_Name, t.Num_Rows, 'LOBSEGMENT' Type
                                                      FROM DBA_Lobs l
                                                      JOIN DBA_Tables  t ON t.Owner = l.Owner AND t.Table_Name = l.Table_Name
                                                      UNION ALL /* Num_Rows from table for LOBs */
                                                      SELECT l.Owner, l.Segment_Name Object_Name, t.Num_Rows, 'LOB PARTITION' Type
                                                      FROM DBA_Lobs l
                                                      JOIN DBA_Tables  t ON t.Owner = l.Owner AND t.Table_Name = l.Table_Name
                                                      UNION ALL /* Num_Rows from table for LOB indexes because LOB-indexes themself does not contain valid num_rows after analysis */
                                                      SELECT l.Owner, l.Index_Name Object_Name, t.Num_Rows, 'LOBINDEX' Type
                                                      FROM DBA_Lobs l
                                                      JOIN DBA_Tables  t ON t.Owner = l.Owner AND t.Table_Name = l.Table_Name
                                                     ) n ON n.Owner = s.Owner AND n.Object_Name = s.Segment_Name AND INSTR(s.Segment_Type, n.Type) > 0
                                    ",
                                    snapshot_time.strftime('%Y-%m-%d %H:%M:%S')
                                   ]
  end

  def do_object_size_housekeeping(shrink_space)
    execute_until_nomore ["DELETE FROM #{@sampler_config.get_owner}.Panorama_Object_Sizes
                           WHERE  Gather_Date < SYSDATE - ?
                          ", @sampler_config.get_object_size_snapshot_retention]
    exec_shrink_space('Panorama_Object_Sizes') if shrink_space
  end

  def do_cache_objects_sampling(snapshot_time)
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config.get_owner}.Panorama_Cache_Objects (
                                       SnapShot_Timestamp,
                                       Instance_Number,
                                       Owner,
                                       Name,
                                       Partition_Name,
                                       Blocks_Total,
                                       Blocks_Dirty)
                                     SELECT /*+ ORDERED USE_HASH(bh o) USE_NL(bh ts) Panorama */
                                            TO_DATE(?, 'YYYY-MM-DD HH24:MI:SS'),
                                            Inst_ID,
                                            NVL(o.Owner,'[UNKNOWN]'),
                                            NVL(o.Object_Name,'TS='||ts.Name),
                                            o.SubObject_Name,
                                            SUM(bh.Blocks),
                                            SUM(bh.DirtyBlocks)
                                     FROM   (
                                             SELECT /*+ NO_MERGE */ -- X$BH statt GV$BH weil damit kein Join gegen x$le mehr noetig innerhalb des Views
                                                    Inst_ID, ObjD, TS#, Count(*) Blocks,
                                                    SUM(DECODE (Dirty,'Y',1,0)) DirtyBlocks
                                             FROM   gv$BH
                                             GROUP BY Inst_ID, ObjD, TS#
                                            ) bh
                                     LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Data_Object_ID, Owner, Object_Name, Subobject_Name FROM DBA_Objects )o ON o.Data_Object_ID=bh.ObjD
                                     LEFT OUTER JOIN sys.TS$ ts ON ts.TS# = bh.TS#
                                     GROUP BY Inst_ID, NVL(o.Owner,'[UNKNOWN]'), NVL(o.Object_Name,'TS='||ts.Name), o.SubObject_Name
                                     HAVING SUM(bh.Blocks) > 1000 /* Geringfuegigkeits-Grenze */
                                    ", snapshot_time.strftime('%Y-%m-%d %H:%M:%S') ]
  end

  def do_cache_objects_housekeeping(shrink_space)
    execute_until_nomore ["DELETE FROM #{@sampler_config.get_owner}.Panorama_Cache_Objects
                           WHERE  Snapshot_Timestamp < SYSDATE - ?
                          ", @sampler_config.get_cache_objects_snapshot_retention]
    exec_shrink_space('Panorama_Cache_Objects') if shrink_space
  end

  def do_blocking_locks_sampling(snapshot_time)
    if @sampler_config.get_select_any_table                                     # call PL/SQL package ?
      sql = " BEGIN #{@sampler_config.get_owner}.Panorama_Sampler_Block_Locks.Create_Block_Locks_Snapshot(?, ?); END;"
    else
      sql = "
        DECLARE
        #{PanoramaSamplerStructureCheck.translate_plsql_aliases(@sampler_config, panorama_sampler_blocking_locks_code)}
        BEGIN
          Create_Block_Locks_Snapshot(?, ?);
        END;
        "
    end

    # TODO: LongLocksSeconds in config
    PanoramaConnection.sql_execute [sql, PanoramaConnection.instance_number, @sampler_config.get_blocking_locks_long_locks_limit]
  end

  def do_blocking_locks_housekeeping(shrink_space)
    execute_until_nomore ["DELETE FROM #{@sampler_config.get_owner}.Panorama_Blocking_Locks
                           WHERE  Snapshot_Timestamp < SYSDATE - ?
                          ", @sampler_config.get_blocking_locks_snapshot_retention]
    exec_shrink_space('Panorama_Blocking_Locks') if shrink_space
  end

  def do_longterm_trend_sampling(snapshot_time)
    start_time = snapshot_time - @sampler_config.get_longterm_trend_snapshot_cycle * 3600 * 2
    end_time   = snapshot_time - @sampler_config.get_longterm_trend_snapshot_cycle * 3600

    sql = "
      DECLARE
      BEGIN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE #{@sampler_config.get_owner}.Longterm_trend_Temp';
        INSERT INTO #{@sampler_config.get_owner}.Longterm_trend_Temp(Instance_Number, Wait_Class, Wait_Event, User_ID, Service_Hash, Machine, Module, Action, Seconds_Active)
        SELECT Instance_Number, Wait_Class, Wait_Event, User_ID, Service_Hash, Machine, Module, Action, COUNT(*) * 10
        FROM   (
                SELECT Instance_Number,
                       #{@sampler_config.get_longterm_trend_log_wait_class ? "NVL(Wait_Class,   'CPU')"  : "'NOT SAMPLED'"} Wait_Class,
                       #{@sampler_config.get_longterm_trend_log_wait_event ? "NVL(Event, Session_State)" : "'NOT SAMPLED'"} Wait_Event,
                       #{@sampler_config.get_longterm_trend_log_user       ? "NVL(User_ID,      0)"      : "'NOT SAMPLED'"} User_ID,
                       #{@sampler_config.get_longterm_trend_log_service    ? "NVL(Service_Hash, 0)"      : "'NOT SAMPLED'"} Service_Hash,
                       #{@sampler_config.get_longterm_trend_log_machine    ? "NVL(Machine,      'NULL')" : "'NOT SAMPLED'"} Machine,
                       #{@sampler_config.get_longterm_trend_log_module     ? "NVL(Module,       'NULL')" : "'NOT SAMPLED'"} Module,
                       #{@sampler_config.get_longterm_trend_log_action     ? "NVL(Action,       'NULL')" : "'NOT SAMPLED'"} Action
                FROM   #{@sampler_config.get_longterm_trend_data_source == :oracle_ash ? "DBA_Hist_Active_Sess_History" : "#{@sampler_config.get_owner}.Panorama_Active_Sess_History"}
                WHERE  Sample_Time >= TO_DATE('#{start_time.strftime('%Y-%m-%d %H:%M:%S')}', 'YYYY-MM-DD HH24:MI:SS')
                AND    Sample_Time <  TO_DATE('#{end_time.strftime(  '%Y-%m-%d %H:%M:%S')}', 'YYYY-MM-DD HH24:MI:SS')
               )
        GROUP BY Instance_Number, Wait_Class, Wait_Event, User_ID, Service_Hash, Machine, Module, Action;
      END;
    "
    puts sql
    PanoramaConnection.sql_execute [sql]
  end

  def do_longterm_trend_housekeeping(shrink_space)
    execute_until_nomore ["DELETE FROM #{@sampler_config.get_owner}.Longterm_Trend
                           WHERE  Snapshot_Timestamp < SYSDATE - ?
                          ", @sampler_config.get_longterm_trend_snapshot_retention]
    exec_shrink_space('Longterm_Trend') if shrink_space
  end


  def exec_shrink_space(table_name)
    Rails.logger.info "Executing ALTER TABLE #{@sampler_config.get_owner}.#{table_name} SHRINK SPACE CASCADE"
    PanoramaConnection.sql_execute("ALTER TABLE #{@sampler_config.get_owner}.#{table_name} ENABLE ROW MOVEMENT")
    PanoramaConnection.sql_execute("ALTER TABLE #{@sampler_config.get_owner}.#{table_name} SHRINK SPACE CASCADE")
  end

  private
  def con_dbid
    PanoramaConnection.dbid
  end

  # Limit transaction size to prevent unnecessary UNDO traffic and ORA-1550 snapshot too old
  def execute_until_nomore(params, max_rows=100000)
    sql_addition =  " AND RowNum <= #{max_rows}"
    params[0] << sql_addition if params.class == Array
    params    << sql_addition if params.class == String
    loop do
      result_count = PanoramaConnection.sql_execute params
      break if result_count < max_rows
    end
  end

end