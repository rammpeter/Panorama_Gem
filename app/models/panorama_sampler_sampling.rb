class PanoramaSamplerSampling

  include ExceptionHelper


  def self.do_sampling(sampler_config)
    PanoramaSamplerSampling.new(sampler_config).do_sampling_internal
  end

  def self.do_housekeeping(sampler_config)
    PanoramaSamplerSampling.new(sampler_config).do_housekeeping_internal
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

    ## TODO: Con_DBID mit realen werten des Containers füllen, falls PDB-übergreifendes Sampling gewünscht wird
    PanoramaConnection.sql_execute [" BEGIN #{@sampler_config[:owner]}.Panorama_Sampler_Snapshot.Do_Snapshot(?, ?, ?, ?, ?, ?, ?, ?); END;",
                                    @snap_id, PanoramaConnection.instance_number, PanoramaConnection.dbid, con_dbid, PanoramaConnection.con_id,
                                    begin_interval_time, @sampler_config[:snapshot_cycle], @sampler_config[:snapshot_retention]]
  end

  def do_housekeeping_internal
    snapshots_to_delete = PanoramaConnection.sql_select_all ["SELECT Snap_ID FROM Panorama_Snapshot WHERE DBID = ? AND Begin_Interval_Time < SYSDATE - ?", PanoramaConnection.dbid, @sampler_config[:snapshot_retention]]

    # Delete from tables with columns DBID and SNAP_ID
    snapshots_to_delete.each do |snapshot|
      PanoramaSamplerStructureCheck.tables.each do |table|
        if PanoramaSamplerStructureCheck.has_column?(table[:table_name], 'Snap_ID')
          PanoramaConnection.sql_execute ["DELETE FROM #{@sampler_config[:owner]}.#{table[:table_name]} WHERE DBID = ? AND Snap_ID <= ?", PanoramaConnection.dbid, snapshot.snap_id]
        end
      end
    end
    # Delete from tables without columns DBID and SNAP_ID

  end

  # Run daemon, daeomon returns 1 second before next snapshot timestamp
  def run_ash_daemon_internal(snapshot_time)
    start_delay_from_snapshot = Time.now - snapshot_time
    snapshot_cycle_seconds = @sampler_config[:snapshot_cycle] * 60
    if start_delay_from_snapshot > 30                                           # ASH-daemon starts more than 30 seconds after snapshot due to structure-check before
      snapshot_cycle_seconds -= start_delay_from_snapshot.to_i - 30             # Limit delay so that ASH-daemon terminates max. 30 seconds after next snapshot
    end
    next_snapshot_start_seconds = @sampler_config[:snapshot_cycle] * 60 - start_delay_from_snapshot # Number of seconds until next snapshot start
    PanoramaConnection.sql_execute [" BEGIN #{@sampler_config[:owner]}.Panorama_Sampler_ASH.Run_Sampler_Daemon(?, ?, ?, ?); END;",
                                    snapshot_cycle_seconds, PanoramaConnection.instance_number, PanoramaConnection.con_id, next_snapshot_start_seconds]
  end

  private
  def con_dbid
    PanoramaConnection.dbid
  end

end