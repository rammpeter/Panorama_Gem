-- Package for use by Panorama-Sampler
CREATE OR REPLACE Package panorama.Panorama_Sampler_ASH AS
  PROCEDURE Run_Sampler_Daemon(p_Snapshot_Cycle_Minutes IN NUMBER, p_Instance_Number IN NUMBER, p_Con_ID IN NUMBER);

END Panorama_Sampler_ASH;