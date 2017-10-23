class PanoramaSamplerSampling
  include PanoramaSampler::PackagePanoramaSamplerAsh
  include PanoramaSampler::PackagePanoramaSamplerSnapshot
  include ExceptionHelper


  def self.do_sampling(sampler_config)
    PanoramaSamplerSampling.new(sampler_config).do_sampling_internal
  end

  def self.do_housekeeping(sampler_config, shrink_space)
    PanoramaSamplerSampling.new(sampler_config).do_housekeeping_internal(shrink_space)
  end

  def self.run_ash_daemon(sampler_config, snapshot_time)
    PanoramaSamplerSampling.new(sampler_config).run_ash_daemon_internal(snapshot_time)
  rescue Exception => e
    # try second time to fix error ORA-04068 existing state of package has changed ...
    PanoramaSamplerSampling.new(sampler_config).run_ash_daemon_internal(snapshot_time)
  end

  def self.do_object_size_sampling(sampler_config, snapshot_time)
    PanoramaConnection.sql_execute ["INSERT INTO #{sampler_config[:owner]}.Panorama_Object_Sizes (Owner, Segment_Name, Segment_Type, Tablespace_Name, Gather_Date, Bytes)
                                     SELECT Owner, Segment_Name, Segment_Type, Tablespace_Name, ?, SUM(Bytes)
                                     FROM   DBA_Segments
                                     GROUP BY Owner, Segment_Name, Segment_Type, Tablespace_Name
                                    ",
                                    snapshot_time]
  end

  def self.do_object_size_housekeeping(sampler_config, shrink_space)
    PanoramaSamplerSampling.new(sampler_config).do_object_size_housekeeping_internal(shrink_space)
  end

  def initialize(sampler_config)
    @sampler_config = sampler_config
  end

  def do_sampling_internal
    last_snap = PanoramaConnection.sql_select_first_row ["SELECT Snap_ID, End_Interval_Time
                                                    FROM   #{@sampler_config[:owner]}.Panorama_Snapshot
                                                    WHERE  DBID=? AND Instance_Number=?
                                                    AND    Snap_ID = (SELECT MAX(Snap_ID) FROM #{@sampler_config[:owner]}.Panorama_Snapshot WHERE DBID=? AND Instance_Number=?)
                                                   ", PanoramaConnection.dbid, PanoramaConnection.instance_number, PanoramaConnection.dbid, PanoramaConnection.instance_number]

    if last_snap.nil?                                                           # First access
      @snap_id = 1
      begin_interval_time = (PanoramaConnection.sql_select_one "SELECT SYSDATE FROM Dual") - (@sampler_config[:snapshot_cycle]).minutes
    else
      @snap_id            = last_snap.snap_id + 1
      begin_interval_time = last_snap.end_interval_time
    end

    ## DBA_Hist_Snapshot, must be the first atomic transaction to ensure that next snap_id is exactly incremented
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config[:owner]}.Panorama_Snapshot (Snap_ID, DBID, Instance_Number, Begin_Interval_Time, End_Interval_Time, Con_ID
                                    ) VALUES (?, ?, ?, ?, SYSDATE, ?)",
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

    if @sampler_config[:select_any_table]                                       # call PL/SQL package ?
      sql = " BEGIN #{@sampler_config[:owner]}.Panorama_Sampler_Snapshot.#{do_snapshot_call}; END;"
    else
      sql = "
        DECLARE
        #{panorama_sampler_snapshot_code}
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
                                    @sampler_config[:snapshot_cycle],
                                    @sampler_config[:snapshot_retention],
                                    @sampler_config[:sql_min_no_of_execs],
                                    @sampler_config[:sql_min_runtime_millisecs]
                                   ]
  end

  def do_housekeeping_internal(shrink_space)
    snapshots_to_delete = PanoramaConnection.sql_select_all ["SELECT Snap_ID FROM Panorama_Snapshot WHERE DBID = ? AND Begin_Interval_Time < SYSDATE - ?", PanoramaConnection.dbid, @sampler_config[:snapshot_retention]]

    # Delete from tables with columns DBID and SNAP_ID
    snapshots_to_delete.each do |snapshot|
      PanoramaSamplerStructureCheck.tables.each do |table|
        if PanoramaSamplerStructureCheck.has_column?(table[:table_name], 'Snap_ID')
          execute_until_nomore ["DELETE FROM #{@sampler_config[:owner]}.#{table[:table_name]} WHERE DBID = ? AND Snap_ID <= ?", PanoramaConnection.dbid, snapshot.snap_id]
          exec_shrink_space(table[:table_name]) if shrink_space
        end
      end
    end
    # Delete from tables without columns DBID and SNAP_ID
    execute_until_nomore ["DELETE FROM #{@sampler_config[:owner]}.Panorama_SQL_Plan p
                           WHERE  DBID      = ?
                           AND    Con_DBID  = ?
                           AND    (SQL_ID, Plan_Hash_Value) NOT IN (SELECT SQL_ID, Plan_Hash_Value FROM Panorama_SQLStat s
                                                 WHERE  s.DBID      = ?
                                                 AND    s.Con_DBID  = ?
                                                )
                          ", PanoramaConnection.dbid, con_dbid, PanoramaConnection.dbid, con_dbid]
    exec_shrink_space('Panorama_SQL_Plan') if shrink_space

    execute_until_nomore ["DELETE FROM #{@sampler_config[:owner]}.Panorama_SQLText t
                           WHERE  DBID      = ?
                           AND    Con_DBID  = ?
                           AND    SQL_ID NOT IN (SELECT SQL_ID FROM Panorama_SQLStat s
                                                 WHERE  s.DBID      = ?
                                                 AND    s.Con_DBID  = ?
                                                )
                          ", PanoramaConnection.dbid, con_dbid, PanoramaConnection.dbid, con_dbid]
    exec_shrink_space('Panorama_SQLText') if shrink_space
  end

  def do_object_size_housekeeping_internal(shrink_space)
    execute_until_nomore ["DELETE FROM #{@sampler_config[:owner]}.Panorama_Object_Sizes
                           WHERE  Gather_Date < SYSDATE - ?
                          ", @sampler_config[:object_size_snapshot_retention]]
    exec_shrink_space('Panorama_Object_Sizes') if shrink_space
  end

  # Run daemon, daeomon returns 1 second before next snapshot timestamp
  def run_ash_daemon_internal(snapshot_time)
    start_delay_from_snapshot = Time.now - snapshot_time
    snapshot_cycle_seconds = @sampler_config[:snapshot_cycle] * 60
    if start_delay_from_snapshot > 30                                           # ASH-daemon starts more than 30 seconds after snapshot due to structure-check before
      snapshot_cycle_seconds -= start_delay_from_snapshot.to_i - 30             # Limit delay so that ASH-daemon terminates max. 30 seconds after next snapshot
    end
    next_snapshot_start_seconds = @sampler_config[:snapshot_cycle] * 60 - start_delay_from_snapshot # Number of seconds until next snapshot start
    if @sampler_config[:select_any_table]                                       # call PL/SQL package ?
      sql = " BEGIN #{@sampler_config[:owner]}.Panorama_Sampler_ASH.Run_Sampler_Daemon(?, ?, ?, ?); END;"
    else
      sql = "
        DECLARE
        #{panorama_sampler_ash_code}
        BEGIN
          Run_Sampler_Daemon(?, ?, ?, ?);
        END;
        "
    end

    PanoramaConnection.sql_execute [sql, snapshot_cycle_seconds, PanoramaConnection.instance_number, PanoramaConnection.con_id, next_snapshot_start_seconds]
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

  def exec_shrink_space(table_name)
    PanoramaConnection.sql_execute("ALTER TABLE #{@sampler_config[:owner]}.#{table_name} ENABLE ROW MOVEMENT")
    PanoramaConnection.sql_execute("ALTER TABLE #{@sampler_config[:owner]}.#{table_name} SHRINK SPACE CASCADE")
  end
end