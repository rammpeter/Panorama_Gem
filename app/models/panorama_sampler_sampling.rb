class PanoramaSamplerSampling

  include ExceptionHelper

  def self.do_sampling(sampler_config)
    PanoramaSamplerSampling.new(sampler_config).do_sampling_internal
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
      begin_interval_time = (sql_select_one "SELECT SYSDATE FROM Dual") - (@sampler_config[:snapshot_cyle]).minutes
    else
      @snap_id            = last_snap.snap_id + 1
      begin_interval_time = last_snap.end_interval_time
    end

    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config[:owner]}.Panorama_Snapshot (Snap_ID, DBID, Instance_Number, Begin_Interval_Time, End_Interval_Time
                                    ) VALUES (?, ?, ?, ?, SYSDATE)",  @snap_id, PanoramaConnection.dbid, PanoramaConnection.instance_number, begin_interval_time]
  end

end