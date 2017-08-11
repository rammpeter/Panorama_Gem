-- Package for use by Panorama-Sampler
CREATE OR REPLACE Package panorama.Panorama_Sampler AS
  PROCEDURE Run_Sampler_Daemon(p_Snapshot_Cycle_Minutes IN NUMBER, p_Instance_Number IN NUMBER, p_Con_ID IN NUMBER);

  PROCEDURE Move_To_Snapshot_Table(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Con_DBID IN NUMBER);
END Panorama_Sampler;