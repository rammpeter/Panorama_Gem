-- Package for use by Panorama-Sampler
CREATE OR REPLACE PACKAGE BODY panorama.Panorama_Sampler_ASH AS
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME
  TYPE AshType IS RECORD (
    Sample_ID             NUMBER,
    Sample_Time           TIMESTAMP(3),
    Session_ID            NUMBER,
    SESSION_SERIAL#       NUMBER,
    Session_Type          VARCHAR2(10),
    Flags                 NUMBER,
    User_ID               NUMBER,
    SQL_ID                VARCHAR2(13)
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
             s.SQL_ID
      BULK COLLECT INTO AshTable4Select
      FROM   v$Session s
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
          Session_Type, Flags, User_ID, SQL_ID,
          Event_ID,
          Con_ID
        ) VALUES (
          p_Instance_Number, AshTable(Idx).Sample_ID, AshTable(Idx).Sample_Time, 'N', AshTable(Idx).Session_ID, AshTable(Idx).Session_Serial#,
          AshTable(Idx).Session_Type, AshTable(Idx).Flags, AshTable(Idx).User_ID, AshTable(Idx).SQL_ID,
          p_Bulk_Size,
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