class PanoramaSamplerSampling

  include ExceptionHelper


  def self.do_sampling(sampler_config)
    PanoramaSamplerSampling.new(sampler_config).do_sampling_internal
  end

  def self.do_housekeeping(sampler_config)
    PanoramaSamplerSampling.new(sampler_config).do_housekeeping_internal
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

    ## DBA_Hist_Snapshot
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config[:owner]}.Panorama_Snapshot (Snap_ID, DBID, Instance_Number, Begin_Interval_Time, End_Interval_Time#{", Con_ID" if PanoramaConnection.db_version >= '12.1'}
                                    ) VALUES (?, ?, ?, ?, SYSDATE#{", ?" if PanoramaConnection.db_version >= '12.1'})",  @snap_id, PanoramaConnection.dbid, PanoramaConnection.instance_number, begin_interval_time].concat(
        PanoramaConnection.db_version >= '12.1' ? [0] : []
    )

    ## DBA_Hist_Log
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config[:owner]}.Panorama_Log (Snap_ID, DBID, Instance_Number, Group#, Thread#, Sequence#, Bytes, Members, Archived, Status, First_Change#, First_Time#{", Con_DBID, Con_ID" if PanoramaConnection.db_version >= '12.1'}
                                    ) SELECT ?, ?, ?,
                                             Group#, Thread#, Sequence#, Bytes, Members, Archived, Status, First_Change#, First_Time, ?#{PanoramaConnection.db_version >= '12.1' ? ", Con_ID" : "0"}
                                      FROM   v$Log
                                    ",  @snap_id, PanoramaConnection.dbid, PanoramaConnection.instance_number, PanoramaConnection.dbid]
  end

  def do_housekeeping_internal

  end

end