-- Package for use by Panorama-Sampler
CREATE OR REPLACE PACKAGE BODY panorama.Panorama_Sampler AS
  TYPE AshType IS RECORD (
    Sample_ID             NUMBER,
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

  v_Sample_ID       INTEGER;
  v_Counter         INTEGER;

  PROCEDURE CreateSample(p_Instance_Number IN NUMBER, p_Con_ID IN NUMBER) IS
    BEGIN
      v_Sample_ID := v_Sample_ID + 1;
      AshTable4Select.DELETE;
      SELECT v_Sample_ID,
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

      v_Counter := v_Counter + 1;
      IF v_Counter >= 10 THEN
        v_Counter := 0;

        FORALL Idx IN 1 .. AshTable.COUNT
        INSERT INTO Panorama_V$Active_Sess_History (
          Instance_Number, Sample_ID, Sample_Time, Is_AWR_Sample, Session_ID, Session_Serial#,
          Session_Type, Flags, User_ID, SQL_ID,
          Con_ID
        ) VALUES (
          p_Instance_Number, AshTable(Idx).Sample_ID, SYSTIMESTAMP, 'N', AshTable(Idx).Session_ID, AshTable(Idx).Session_Serial#,
          AshTable(Idx).Session_Type, AshTable(Idx).Flags, AshTable(Idx).User_ID, AshTable(Idx).SQL_ID,
          p_Con_ID
        );
        COMMIT;
        AshTable.DELETE;
      END IF;
    END CreateSample;


  PROCEDURE Run_Sampler_Daemon(p_Snapshot_Cycle_Minutes IN NUMBER, p_Instance_Number IN NUMBER, p_Con_ID IN NUMBER) IS
    v_LastSampleTime  DATE;
    BEGIN
      v_Counter := 0;
      -- Ensure that local database time controls end of PL/SQL-execution (allows different time zones and some seconds delay between Panorama and DB)
      -- but assumes that PL/SQL-Job is started at the exact second
      v_LastSampleTime := SYSDATE + p_Snapshot_Cycle_Minutes/1440 - 1/86400;
      SELECT NVL(MAX(Sample_ID), 0) INTO v_Sample_ID FROM Panorama_V$Active_Sess_History;

      LOOP
        CreateSample(p_Instance_Number, p_Con_ID);
        EXIT WHEN SYSDATE >= v_LastSampleTime;

        -- Wait until current second ends
        DBMS_LOCK.SLEEP(1-MOD(EXTRACT(SECOND FROM SYSTIMESTAMP), 1));

      END LOOP;

      EXCEPTION
        WHEN OTHERS THEN
          RAISE;
    END Run_Sampler_Daemon;

END Panorama_Sampler;