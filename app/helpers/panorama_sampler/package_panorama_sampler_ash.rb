module PanoramaSampler::PackagePanoramaSamplerAsh
  # PL/SQL-Package for snapshot creation
  def panorama_sampler_ash_spec
    "
CREATE OR REPLACE Package panorama.Panorama_Sampler_ASH AS
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME


  PROCEDURE Run_Sampler_Daemon(p_Snapshot_Cycle_Seconds IN NUMBER, p_Instance_Number IN NUMBER, p_Con_ID IN NUMBER, p_Next_Snapshot_Start_Seconds IN NUMBER);

END Panorama_Sampler_ASH;
    "
  end

  def panorama_sampler_ash_body
    "
-- Package for use by Panorama-Sampler
CREATE OR REPLACE PACKAGE BODY panorama.Panorama_Sampler_ASH AS
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME
  TYPE AshType IS RECORD (
    Sample_ID                 NUMBER,
    Sample_Time               TIMESTAMP(3),
    Session_ID                NUMBER,
    SESSION_SERIAL#           NUMBER,
    Session_Type              VARCHAR2(10),
    Flags                     NUMBER,
    User_ID                   NUMBER,
    SQL_ID                    VARCHAR2(13),
    Is_SQLID_Current          VARCHAR2(1),
    SQL_CHILD_NUMBER          NUMBER,
    SQL_OPCODE                NUMBER,
    SQL_OpName                VARCHAR2(64),
    FORCE_MATCHING_SIGNATURE  NUMBER,
    TOP_LEVEL_SQL_ID          VARCHAR2(13),
    TOP_LEVEL_SQL_OPCODE      NUMBER,
    SQL_PLAN_HASH_VALUE       NUMBER,
    SQL_PLAN_LINE_ID          NUMBER,
    SQL_PLAN_OPERATION        VARCHAR2(64),
    SQL_PLAN_OPTIONS          VARCHAR2(64),
    SQL_EXEC_ID               NUMBER,
    SQL_EXEC_START            DATE,
    PLSQL_ENTRY_OBJECT_ID     NUMBER,
    PLSQL_ENTRY_SUBPROGRAM_ID NUMBER,
    PLSQL_OBJECT_ID           NUMBER,
    PLSQL_SUBPROGRAM_ID       NUMBER
  );
  TYPE AshTableType IS TABLE OF AshType INDEX BY BINARY_INTEGER;
  AshTable                AshTableType;
  AshTable4Select         AshTableType;


  PROCEDURE CreateSample(
    p_Instance_Number IN NUMBER,
    p_Con_ID          IN NUMBER,
    p_Bulk_Size       IN INTEGER,
    p_Counter         IN OUT NUMBER,
    p_Sample_ID       IN OUT NUMBER
  ) IS
    BEGIN
      p_Sample_ID := p_Sample_ID + 1;
      AshTable4Select.DELETE;
      SELECT p_Sample_ID,
             SYSTIMESTAMP,
             s.SID,
             s.Serial#,
             s.Type,
             NULL,                -- Flags
             s.User#,
             s.SQL_ID,
             'Y',                 -- TODO: Is_SQLID_Current ermitteln
             s.SQL_Child_Number,
             s.Command,           -- SQL_OpCode
             c.Command_Name,      -- SQL_OpName
             sql.FORCE_MATCHING_SIGNATURE,
             NULL,                -- TODO: TOP_LEVEL_SQL_ID ermitteln
             NULL,                -- TODO: TOP_LEVEL_SQL_OPCODE ermitteln
             sql.PLAN_HASH_VALUE,
             NULL,                -- TODO: SQL_PLAN_LINE_ID ermitteln
             NULL,                -- TODO: SQL_PLAN_OPERATION ermitteln
             NULL,                -- TODO SQL_PLAN_OPTIONS ermitteln
             s.SQL_EXEC_ID,
             s.SQL_EXEC_START,
             s.PLSQL_ENTRY_OBJECT_ID,
             s.PLSQL_ENTRY_SUBPROGRAM_ID,
             s.PLSQL_OBJECT_ID,
             s.PLSQL_SUBPROGRAM_ID
      BULK COLLECT INTO AshTable4Select
      FROM   v$Session s
      LEFT OUTER JOIN v$SQLCommand c ON c.Command_Type = s.Command
      LEFT OUTER JOIN v$SQL sql ON sql.SQL_ID = s.SQL_ID AND sql.Child_Number = s.SQL_Child_Number
      LEFT OUTER JOIN v$PX_Session pxs ON pxs.SID = s.SID AND pxs.Serial#=s.Serial#
      WHERE  s.Status = 'ACTIVE'
      AND    s.Wait_Class != 'Idle'
      AND    s.SID        != USERENV('SID')  -- dont record the own session that assumes always active this way
      ;

      FOR Idx IN 1 .. AshTable4Select.COUNT LOOP
        AshTable(AshTable.COUNT+1) := AshTable4Select(Idx);
      END LOOP;

      p_Counter := p_Counter + 1;
      IF p_Counter >= p_Bulk_Size-1 THEN
        p_Counter := 0;

        FORALL Idx IN 1 .. AshTable.COUNT
        INSERT INTO Panorama_V$Active_Sess_History (
          Instance_Number, Sample_ID, Sample_Time, Is_AWR_Sample, Session_ID, Session_Serial#,
          Session_Type, Flags, User_ID, SQL_ID, Is_SQLID_Current, SQL_Child_Number,
          SQL_OpCode, SQL_OpName, FORCE_MATCHING_SIGNATURE, TOP_LEVEL_SQL_ID, TOP_LEVEL_SQL_OPCODE,
          SQL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID, SQL_PLAN_OPERATION, SQL_PLAN_OPTIONS,
          SQL_EXEC_ID, SQL_EXEC_START,
          PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID,
          Con_ID
        ) VALUES (
          p_Instance_Number, AshTable(Idx).Sample_ID, AshTable(Idx).Sample_Time, 'N', AshTable(Idx).Session_ID, AshTable(Idx).Session_Serial#,
          AshTable(Idx).Session_Type, AshTable(Idx).Flags, AshTable(Idx).User_ID, AshTable(Idx).SQL_ID, AshTable(Idx).Is_SQLID_Current, AshTable(Idx).SQL_Child_Number,
          AshTable(Idx).SQL_OpCode, AshTable(Idx).SQL_OpName, AshTable(Idx).FORCE_MATCHING_SIGNATURE, AshTable(Idx).TOP_LEVEL_SQL_ID, AshTable(Idx).TOP_LEVEL_SQL_OPCODE,
          AshTable(Idx).SQL_PLAN_HASH_VALUE, AshTable(Idx).SQL_PLAN_LINE_ID, AshTable(Idx).SQL_PLAN_OPERATION, AshTable(Idx).SQL_PLAN_OPTIONS,
          AshTable(Idx).SQL_EXEC_ID, AshTable(Idx).SQL_EXEC_START,
          AshTable(Idx).PLSQL_ENTRY_OBJECT_ID, AshTable(Idx).PLSQL_ENTRY_SUBPROGRAM_ID, AshTable(Idx).PLSQL_OBJECT_ID, AshTable(Idx).PLSQL_SUBPROGRAM_ID,
          p_Con_ID
        );
        COMMIT;
        AshTable.DELETE;
      END IF;
    END CreateSample;


  PROCEDURE Run_Sampler_Daemon(
    p_Snapshot_Cycle_Seconds IN NUMBER,
    p_Instance_Number IN NUMBER,
    p_Con_ID IN NUMBER,
    p_Next_Snapshot_Start_Seconds IN NUMBER
  ) IS
    v_Counter         INTEGER;
    v_Sample_ID       INTEGER;
    v_LastSampleTime  DATE;
    v_Bulk_Size       INTEGER;
    v_Seconds_Run     INTEGER := 0;
    BEGIN
      v_Counter := 0;
      -- Ensure that local database time controls end of PL/SQL-execution (allows different time zones and some seconds delay between Panorama and DB)
      -- but assumes that PL/SQL-Job is started at the exact second
      v_LastSampleTime := SYSDATE + p_Snapshot_Cycle_Seconds/86400 - 1/86400;
      SELECT NVL(MAX(Sample_ID), 0) INTO v_Sample_ID FROM Panorama_V$Active_Sess_History;

      LOOP
        v_Bulk_Size := 10; -- Number of seconds between persists/commits
        -- Reduce Bulk_Size before end of snapshot so last records are so commited that they are visible for snapshot creation and don't fall into the next snapshot
        IF v_Seconds_Run > p_Next_Snapshot_Start_Seconds - v_Bulk_Size THEN   -- less than v_Bulk_Size seconds until next snapshot
          v_Bulk_Size := p_Next_Snapshot_Start_Seconds - v_Seconds_Run;       -- reduce bulk size
          IF v_Bulk_Size < 1 THEN
            v_Bulk_Size := 1;
          END IF;
        END IF;

        CreateSample(p_Instance_Number, p_Con_ID, v_Bulk_Size, v_Counter, v_Sample_ID);
        EXIT WHEN SYSDATE >= v_LastSampleTime;

        -- Wait until current second ends
        DBMS_LOCK.SLEEP(1-MOD(EXTRACT(SECOND FROM SYSTIMESTAMP), 1));
        v_Seconds_Run := v_Seconds_Run + 1;

      END LOOP;

      EXCEPTION
        WHEN OTHERS THEN
          RAISE;
    END Run_Sampler_Daemon;

END Panorama_Sampler_ASH;
    "
  end


end