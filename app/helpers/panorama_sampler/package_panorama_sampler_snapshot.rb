module PanoramaSampler::PackagePanoramaSamplerSnapshot
  # PL/SQL-Package for snapshot creation
  def panorama_sampler_snapshot_spec
    "
CREATE OR REPLACE PACKAGE panorama.Panorama_Sampler_Snapshot IS
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME

  PROCEDURE Do_Snapshot(p_Snap_ID IN NUMBER, p_Instance IN NUMBER, p_DBID IN NUMBER, p_Con_DBID IN NUMBER, p_Con_ID IN NUMBER);
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
    SELECT MAX(Sample_ID) INTO v_Max_Sample_ID FROM Internal_V$Active_Sess_History;
    INSERT INTO Internal_Active_Sess_History (
      Snap_ID, DBID, Instance_Number, Sample_ID, Sample_Time, Session_ID, Session_Type, Flags, User_ID, SQL_ID, Is_SQLID_Current, SQL_Child_Number,
      SQL_OpCode, SQL_OpName, FORCE_MATCHING_SIGNATURE, TOP_LEVEL_SQL_ID, TOP_LEVEL_SQL_OPCODE, SQL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID,
      SQL_PLAN_OPERATION, SQL_PLAN_OPTIONS, SQL_EXEC_ID, SQL_EXEC_START, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID,
      QC_INSTANCE_ID, QC_SESSION_ID, QC_SESSION_SERIAL#, PX_FLAGS, Event, Event_ID, SEQ#, P1TEXT, P1, P2TEXT, P2, P3TEXT, P3, Wait_Class, Wait_Class_ID, Wait_Time,
      Session_State, Time_Waited, BLOCKING_SESSION_STATUS, BLOCKING_SESSION, BLOCKING_SESSION_SERIAL#, BLOCKING_INST_ID, BLOCKING_HANGCHAIN_INFO,
      Current_Obj#, Current_File#, Current_Block#, Current_Row#, Top_Level_Call#,
      Con_DBID, Con_ID
    ) SELECT p_Snap_ID, p_DBID, Instance_Number, Sample_ID, Sample_Time, Session_ID, Session_Type, Flags, User_ID, SQL_ID, Is_SQLID_Current, SQL_Child_Number,
             SQL_OpCode, SQL_OpName, FORCE_MATCHING_SIGNATURE, TOP_LEVEL_SQL_ID, TOP_LEVEL_SQL_OPCODE, SQL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID,
             SQL_PLAN_OPERATION, SQL_PLAN_OPTIONS, SQL_EXEC_ID, SQL_EXEC_START, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID,
             QC_INSTANCE_ID, QC_SESSION_ID, QC_SESSION_SERIAL#, PX_FLAGS, Event, Event_ID, SEQ#, P1TEXT, P1, P2TEXT, P2, P3TEXT, P3, Wait_Class, Wait_Class_ID, Wait_Time,
             Session_State, Time_waited, BLOCKING_SESSION_STATUS, BLOCKING_SESSION, BLOCKING_SESSION_SERIAL#, BLOCKING_INST_ID, BLOCKING_HANGCHAIN_INFO,
             Current_Obj#, Current_File#, Current_Block#, Current_Row#, Top_Level_Call#,
             p_Con_DBID, Con_ID
      FROM   Internal_V$Active_Sess_History
      WHERE  Sample_ID <= v_Max_Sample_ID
    ;
    DELETE FROM Internal_V$Active_Sess_History WHERE Sample_ID <= v_Max_Sample_ID;
    COMMIT;
  END Move_ASH_To_Snapshot_Table;

  PROCEDURE Snap_DB_cache_Advice(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO Panorama_DB_Cache_Advice (SNAP_ID, DBID, INSTANCE_NUMBER, BPID, BUFFERS_FOR_ESTIMATE, NAME, BLOCK_SIZE, ADVICE_STATUS, SIZE_FOR_ESTIMATE,
    SIZE_FACTOR, PHYSICAL_READS, BASE_PHYSICAL_READS, ACTUAL_PHYSICAL_READS, ESTD_PHYSICAL_READ_TIME, CON_DBID, CON_ID
    ) SELECT p_Snap_ID, p_DBID, p_Instance,
             ID, BUFFERS_FOR_ESTIMATE, Name, Block_Size, Advice_Status, SIZE_FOR_ESTIMATE, SIZE_FACTOR, ESTD_PHYSICAL_READS,
             NULL, /* BASE_PHYSICAL_READS origin not yet known */
             NULL, /* ACTUAL_PHYSICAL_READS origin not yet known */
             #{PanoramaConnection.db_version >= '11.2' ? "ESTD_PHYSICAL_READ_TIME, " : "NULL, "}
             p_Con_DBID,
             #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}
      FROM   v$DB_Cache_Advice
    ;
  END Snap_DB_cache_Advice;

  PROCEDURE Snap_Log(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO Panorama_Log (Snap_ID, DBID, Instance_Number, Group#, Thread#, Sequence#, Bytes, Members, Archived, Status, First_Change#, First_Time,
    Con_DBID, Con_ID
    ) SELECT p_Snap_ID, p_DBID, p_Instance, Group#, Thread#, Sequence#, Bytes, Members, Archived, Status, First_Change#, First_Time, p_Con_DBID,
             #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}
      FROM   v$Log
    ;
  END Snap_Log;

  PROCEDURE Snap_TopLevelCallName(p_DBID IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    #{ PanoramaConnection.db_version >= '11.2' ?
           "
    INSERT INTO Panorama_TopLevelCall_Name (DBID, Top_Level_Call#, Top_Level_Call_Name, Con_DBID, Con_ID)
    SELECT p_DBID, Top_Level_Call#, Top_Level_Call_Name, p_Con_DBID, Con_ID
    FROM   v$TopLevelCall s
    WHERE  NOT EXISTS (SELECT 1 FROM Panorama_TopLevelCall_Name t WHERE t.DBID = p_DBID AND t.Top_Level_Call# = s.Top_Level_Call# AND t.Con_DBID = p_Con_DBID)
    ;
           " : "NULL;"
    }
  END Snap_TopLevelCallName;

  PROCEDURE Do_Snapshot(p_Snap_ID IN NUMBER, p_Instance IN NUMBER, p_DBID IN NUMBER, p_Con_DBID IN NUMBER, p_Con_ID IN NUMBER) IS
  BEGIN
    Move_ASH_To_Snapshot_Table(p_Snap_ID,   p_DBID,     p_Con_DBID);
    Snap_DB_cache_Advice      (p_Snap_ID,   p_DBID,     p_Instance,   p_Con_DBID);
    Snap_Log                  (p_Snap_ID,   p_DBID,     p_Instance,   p_Con_DBID);
    Snap_TopLevelCallName     (p_DBID,      p_Con_DBID);
  END Do_Snapshot;

END Panorama_Sampler_Snapshot;
    "
  end


end