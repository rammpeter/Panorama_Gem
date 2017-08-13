-- Package for use by Panorama-Sampler
CREATE OR REPLACE Package panorama.Panorama_Sampler_ASH AS
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME


  PROCEDURE Run_Sampler_Daemon(p_Snapshot_Cycle_Seconds IN NUMBER, p_Instance_Number IN NUMBER, p_Con_ID IN NUMBER, p_Next_Snapshot_Start_Seconds IN NUMBER);

END Panorama_Sampler_ASH;