module PanoramaSampler::PackagePanoramaSamplerSnapshot
  # PL/SQL-Package for snapshot creation
  def panorama_sampler_snapshot_spec
    "
CREATE OR REPLACE PACKAGE panorama.Panorama_Sampler_Snapshot IS
  PROCEDURE Move_ASH_To_Snapshot_Table(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Con_DBID IN NUMBER);
END Panorama_Sampler_Snapshot;
    "
  end

  def panorama_sampler_snapshot_body
    "
CREATE OR REPLACE PACKAGE BODY panorama.Panorama_Sampler_Snapshot IS
  PROCEDURE Move_ASH_To_Snapshot_Table(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    NULL;
  END;
END Panorama_Sampler_Snapshot;
    "
  end


end