module PanoramaSampler::PackagePanoramaSamplerSnapshot
  # PL/SQL-Package for snapshot creation
  def panorama_sampler_snapshot_spec
    "
CREATE OR REPLACE PACKAGE panorama.Panorama_Sampler_Snapshot IS
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME

  PROCEDURE Move_ASH_To_Snapshot_Table(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Con_DBID IN NUMBER);
END Panorama_Sampler_Snapshot;
    "
  end

  def panorama_sampler_snapshot_body
    "
CREATE OR REPLACE PACKAGE BODY panorama.Panorama_Sampler_Snapshot IS
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME

  PROCEDURE Move_ASH_To_Snapshot_Table(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Con_DBID IN NUMBER) IS
    v_Max_Sample_ID NUMBER;
  BEGIN
    SELECT MAX(Sample_ID) INTO v_Max_Sample_ID FROM Panorama_V$Active_Sess_History;
    INSERT INTO Panorama_Active_Sess_History (
      Snap_ID, DBID, Instance_Number, Sample_ID, Sample_Time, Session_ID, Session_Type, Flags, User_ID, SQL_ID, Is_SQLID_Current, SQL_Child_Number,
      SQL_OpCode, SQL_OpName, FORCE_MATCHING_SIGNATURE, TOP_LEVEL_SQL_ID, TOP_LEVEL_SQL_OPCODE, SQL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID,
      SQL_PLAN_OPERATION, SQL_PLAN_OPTIONS, SQL_EXEC_ID, SQL_EXEC_START, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID,
      Con_DBID, Con_ID
    ) SELECT p_Snap_ID, p_DBID, Instance_Number, Sample_ID, Sample_Time, Session_ID, Session_Type, Flags, User_ID, SQL_ID, Is_SQLID_Current, SQL_Child_Number,
             SQL_OpCode, SQL_OpName, FORCE_MATCHING_SIGNATURE, TOP_LEVEL_SQL_ID, TOP_LEVEL_SQL_OPCODE, SQL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID,
             SQL_PLAN_OPERATION, SQL_PLAN_OPTIONS, SQL_EXEC_ID, SQL_EXEC_START, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID,
             p_Con_DBID, Con_ID
      FROM   Panorama_V$Active_Sess_History
      WHERE  Sample_ID <= v_Max_Sample_ID
    ;
    DELETE FROM Panorama_V$Active_Sess_History WHERE Sample_ID <= v_Max_Sample_ID;
    COMMIT;
  END Move_ASH_To_Snapshot_Table;


END Panorama_Sampler_Snapshot;
    "
  end


end