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
    PLSQL_SUBPROGRAM_ID       NUMBER,
    QC_INSTANCE_ID            NUMBER,
    QC_SESSION_ID             NUMBER,
    QC_SESSION_SERIAL#        NUMBER,
    PX_FLAGS                  NUMBER,
    EVENT                     VARCHAR2(64),
    EVENT_ID                  NUMBER,
    SEQ#                      NUMBER,
    P1TEXT                    VARCHAR2(64),
    P1                        NUMBER,
    P2TEXT                    VARCHAR2(64),
    P2                        NUMBER,
    P3TEXT                    VARCHAR2(64),
    P3                        NUMBER,
    WAIT_CLASS                VARCHAR2(64),
    Wait_Class_ID             NUMBER,
    Wait_Time                 NUMBER,
    SESSION_STATE             VARCHAR2(7),
    TIME_WAITED               NUMBER,
    BLOCKING_SESSION_STATUS   VARCHAR2(11),
    BLOCKING_SESSION          NUMBER,
    BLOCKING_SESSION_SERIAL#  NUMBER,
    BLOCKING_INST_ID          NUMBER,
    BLOCKING_HANGCHAIN_INFO   VARCHAR2(1),
    CURRENT_OBJ#              NUMBER,
    CURRENT_FILE#             NUMBER,
    CURRENT_Block#            NUMBER,
    CURRENT_Row#              NUMBER,
    TOP_LEVEL_CALL#           NUMBER,
    CONSUMER_GROUP_ID         NUMBER,
    XID                       RAW(8),
    REMOTE_INSTANCE#          NUMBER,
    TIME_MODEL                NUMBER,
    IN_CONNECTION_MGMT        VARCHAR2(1),
    IN_PARSE                  VARCHAR2(1),
    IN_HARD_PARSE             VARCHAR2(1),
    IN_SQL_EXECUTION          VARCHAR2(1),
    IN_PLSQL_EXECUTION        VARCHAR2(1),
    IN_PLSQL_RPC              VARCHAR2(1),
    IN_PLSQL_COMPILATION      VARCHAR2(1),
    IN_JAVA_EXECUTION         VARCHAR2(1),
    IN_BIND                   VARCHAR2(1),
    IN_CURSOR_CLOSE           VARCHAR2(1),
    IN_SEQUENCE_LOAD          VARCHAR2(1),
    IN_INMEMORY_QUERY         VARCHAR2(1),
    IN_INMEMORY_POPULATE      VARCHAR2(1),
    IN_INMEMORY_PREPOPULATE   VARCHAR2(1),
    IN_INMEMORY_REPOPULATE    VARCHAR2(1),
    IN_INMEMORY_TREPOPULATE   VARCHAR2(1),
    IN_TABLESPACE_ENCRYPTION  VARCHAR2(1),
    CAPTURE_OVERHEAD          VARCHAR2(1),
    REPLAY_OVERHEAD           VARCHAR2(1),
    IS_CAPTURED               VARCHAR2(1),
    IS_REPLAYED               VARCHAR2(1),
    SERVICE_HASH              NUMBER,
    PROGRAM                   VARCHAR2(64),
    Module                    VARCHAR2(64),
    Action                    VARCHAR2(64),
    Client_ID                 VARCHAR2(64),
    Machine                   VARCHAR2(64),
    Port                      NUMBER,
    ECID                      VARCHAR2(64),
    DBREPLAY_FILE_ID          NUMBER,
    DBREPLAY_CALL_COUNTER     NUMBER,
    TM_DELTA_TIME             NUMBER
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
             SYSTIMESTAMP,        -- Sample_Time
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
             s.PLSQL_SUBPROGRAM_ID,
             pxs.QCInst_ID,
             pxs.QCSID,
             pxs.QCSerial#,
             NULL,                -- TODO: PX_FLAGS ermitteln
             s.Event,
             s.Event#,
             s.SEQ#,
             s.P1TEXT,
             s.P1,
             s.P2TEXT,
             s.P2,
             s.P3TEXT,
             s.P3,
             s.Wait_Class,
             s.Wait_Class_ID,
             DECODE(s.State, 'WAITING', 0, s.Wait_Time_Micro),    -- Wait_Time: Time waited on last wait event in ON CPU, 0 currently waiting
             DECODE(s.State, 'WAITING', 'WAITING', 'ON CPU'),     -- Session_State
             DECODE(s.State, 'WAITING', s.Wait_Time_Micro, 0),    -- Time_waited: Current wait time if in wait, 0 if ON CPU
             s.BLOCKING_SESSION_STATUS,
             s.BLOCKING_SESSION,
             CASE WHEN s.Blocking_Session_Status = 'VALID' THEN (SELECT Serial# FROM gv$Session bs WHERE bs.Inst_ID=s.Blocking_Instance AND bs.SID=s.Blocking_Session)
             END BLOCKING_SESSION_SERIAL#,
             s.Blocking_Instance,
             'N',                 -- BLOCKING_HANGCHAIN_INFO
             s.Row_Wait_Obj#,     -- Current_Obj#
             s.Row_Wait_File#,    -- Current_File#
             s.Row_Wait_Block#,   -- Current_Block#
             s.Row_Wait_Row#,     -- Current_Row#
             #{PanoramaConnection.db_version >= '11.2' ?  "s.TOP_LEVEL_CALL#" : "NULL"  }, -- Top_Level_Call#
             cg.ID,               -- CONSUMER_GROUP_ID
             t.XID,
             NULL,                -- TODO: REMOTE_INSTANCE# ermitteln
             NULL,                -- TODO: TIME_MODEL ermitteln
             NULL,                -- TODO: ermitteln IN_CONNECTION_MGMT
             NULL,                -- TODO: ermitteln IN_PARSE
             NULL,                -- TODO: ermitteln IN_HARD_PARSE
             NULL,                -- TODO: ermitteln IN_SQL_EXECUTION
             NULL,                -- TODO: ermitteln IN_PLSQL_EXECUTION
             NULL,                -- TODO: ermitteln IN_PLSQL_RPC
             NULL,                -- TODO: ermitteln IN_PLSQL_COMPILATION
             NULL,                -- TODO: ermitteln IN_JAVA_EXECUTION
             NULL,                -- TODO: ermitteln IN_BIND
             NULL,                -- TODO: ermitteln IN_CURSOR_CLOSE
             NULL,                -- TODO: ermitteln IN_SEQUENCE_LOAD
             NULL,                -- TODO: ermitteln IN_INMEMORY_QUERY
             NULL,                -- TODO: ermitteln IN_INMEMORY_POPULATE
             NULL,                -- TODO: ermitteln IN_INMEMORY_PREPOPULATE
             NULL,                -- TODO: ermitteln IN_INMEMORY_REPOPULATE
             NULL,                -- TODO: ermitteln IN_INMEMORY_TREPOPULATE
             NULL,                -- TODO: ermitteln IN_TABLESPACE_ENCRYPTION
             NULL,                -- TODO: ermitteln CAPTURE_OVERHEAD
             NULL,                -- TODO: ermitteln REPLAY_OVERHEAD
             NULL,                -- TODO: ermitteln IS_CAPTURED
             NULL,                -- TODO: ermitteln IS_REPLAYED
             srv.Name_Hash,       -- Service_Hash
             s.Program,
             s.Module,
             s.Action,
             s.Client_Identifier, -- Client_ID
             s.Machine,
             #{PanoramaConnection.db_version >= '11.2' ?  "s.Port" : "NULL"  }, -- Port
             #{PanoramaConnection.db_version >= '11.2' ?  "s.ECID" : "NULL"  }, -- ECID
             NULL,                -- DBREPLAY_FILE_ID
             NULL,                -- DBREPLAY_CALL_COUNTER
             DECODE(ph.Sample_Time, NULL, NULL, (EXTRACT(DAY    FROM SYSTIMESTAMP-ph.Sample_Time)*86400 + EXTRACT(HOUR FROM SYSTIMESTAMP-ph.Sample_Time)*3600 +
                                                 EXTRACT(MINUTE FROM SYSTIMESTAMP-ph.Sample_Time)*60    + EXTRACT(SECOND FROM SYSTIMESTAMP-ph.Sample_Time))*1000000) -- TM_Delta_Time
      BULK COLLECT INTO AshTable4Select
      FROM   v$Session s
      LEFT OUTER JOIN v$SQLCommand c            ON c.Command_Type = s.Command #{"AND c.Con_ID = s.Con_ID" if PanoramaConnection.db_version >= '12.1'}
      LEFT OUTER JOIN v$SQL sql                 ON sql.SQL_ID = s.SQL_ID AND sql.Child_Number = s.SQL_Child_Number #{"AND sql.Con_ID = s.Con_ID" if PanoramaConnection.db_version >= '12.1'}
      LEFT OUTER JOIN v$PX_Session pxs          ON pxs.SID = s.SID AND pxs.Serial#=s.Serial#
      LEFT OUTER JOIN V$RSRC_CONSUMER_GROUP cg  ON cg.Name = s.Resource_Consumer_Group #{"AND cg.Con_ID = s.Con_ID" if PanoramaConnection.db_version >= '12.1'}
      LEFT OUTER JOIN v$Transaction t           ON t.Ses_Addr = s.SAddr
      LEFT OUTER JOIN v$Services srv            ON srv.Name = s.Service_Name #{"AND srv.Con_ID = s.Con_ID" if PanoramaConnection.db_version >= '12.1'}
      LEFT OUTER JOIN v$Sess_Time_Model stm_db  ON stm_db.SID = s.SID AND stm_db.Stat_Name = 'DB time'
      LEFT OUTER JOIN v$Sess_Time_Model stm_cp  ON stm_cp.SID = s.SID AND stm_cp.Stat_Name = 'DB CPU'
      LEFT OUTER JOIN Internal_V$Active_Sess_History ph ON ph.Instance_Number = p_Instance_Number AND ph.Sample_ID = p_Sample_ID-1 AND ph.Session_ID = s.SID
      WHERE  s.Status = 'ACTIVE'
      AND    s.Wait_Class != 'Idle'
      AND    s.SID        != USERENV('SID')  -- dont record the own session that assumes always active this way
      #{"AND s.Con_ID = p_Con_ID" if PanoramaConnection.db_version >= '12.1'}
      ;

      FOR Idx IN 1 .. AshTable4Select.COUNT LOOP
        AshTable(AshTable.COUNT+1) := AshTable4Select(Idx);
      END LOOP;

      p_Counter := p_Counter + 1;
      IF p_Counter >= p_Bulk_Size-1 THEN
        p_Counter := 0;

        FORALL Idx IN 1 .. AshTable.COUNT
        INSERT INTO Internal_V$Active_Sess_History (
          Instance_Number, Sample_ID, Sample_Time, Is_AWR_Sample, Session_ID, Session_Serial#,
          Session_Type, Flags, User_ID, SQL_ID, Is_SQLID_Current, SQL_Child_Number,
          SQL_OpCode, SQL_OpName, FORCE_MATCHING_SIGNATURE, TOP_LEVEL_SQL_ID, TOP_LEVEL_SQL_OPCODE,
          SQL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID, SQL_PLAN_OPERATION, SQL_PLAN_OPTIONS,
          SQL_EXEC_ID, SQL_EXEC_START,
          PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID,
          QC_INSTANCE_ID, QC_SESSION_ID, QC_SESSION_SERIAL#, PX_FLAGS, Event, Event_ID,
          SEQ#, P1TEXT, P1, P2TEXT, P2, P3TEXT, P3, Wait_Class, Wait_Class_ID, Wait_Time,
          Session_State, Time_Waited, BLOCKING_SESSION_STATUS, BLOCKING_SESSION, BLOCKING_SESSION_SERIAL#,
          BLOCKING_INST_ID, BLOCKING_HANGCHAIN_INFO,
          Current_Obj#, Current_File#, Current_Block#, Current_Row#,
          Top_Level_Call#, CONSUMER_GROUP_ID, XID, REMOTE_INSTANCE#, TIME_MODEL,
          IN_CONNECTION_MGMT, IN_PARSE, IN_HARD_PARSE, IN_SQL_EXECUTION, IN_PLSQL_EXECUTION,
          IN_PLSQL_RPC, IN_PLSQL_COMPILATION, IN_JAVA_EXECUTION, IN_BIND, IN_CURSOR_CLOSE,
          IN_SEQUENCE_LOAD, IN_INMEMORY_QUERY, IN_INMEMORY_POPULATE, IN_INMEMORY_PREPOPULATE,
          IN_INMEMORY_REPOPULATE, IN_INMEMORY_TREPOPULATE, IN_TABLESPACE_ENCRYPTION, CAPTURE_OVERHEAD,
          REPLAY_OVERHEAD, IS_CAPTURED, IS_REPLAYED, Service_Hash, Program,
          Module, Action, Client_ID, Machine, Port, ECID,
          DBREPLAY_FILE_ID, DBREPLAY_CALL_COUNTER, TM_Delta_Time,
          Con_ID
        ) VALUES (
          p_Instance_Number, AshTable(Idx).Sample_ID, AshTable(Idx).Sample_Time, 'N', AshTable(Idx).Session_ID, AshTable(Idx).Session_Serial#,
          AshTable(Idx).Session_Type, AshTable(Idx).Flags, AshTable(Idx).User_ID, AshTable(Idx).SQL_ID, AshTable(Idx).Is_SQLID_Current, AshTable(Idx).SQL_Child_Number,
          AshTable(Idx).SQL_OpCode, AshTable(Idx).SQL_OpName, AshTable(Idx).FORCE_MATCHING_SIGNATURE, AshTable(Idx).TOP_LEVEL_SQL_ID, AshTable(Idx).TOP_LEVEL_SQL_OPCODE,
          AshTable(Idx).SQL_PLAN_HASH_VALUE, AshTable(Idx).SQL_PLAN_LINE_ID, AshTable(Idx).SQL_PLAN_OPERATION, AshTable(Idx).SQL_PLAN_OPTIONS,
          AshTable(Idx).SQL_EXEC_ID, AshTable(Idx).SQL_EXEC_START,
          AshTable(Idx).PLSQL_ENTRY_OBJECT_ID, AshTable(Idx).PLSQL_ENTRY_SUBPROGRAM_ID, AshTable(Idx).PLSQL_OBJECT_ID, AshTable(Idx).PLSQL_SUBPROGRAM_ID,
          AshTable(Idx).QC_INSTANCE_ID, AshTable(Idx).QC_SESSION_ID, AshTable(Idx).QC_SESSION_SERIAL#, AshTable(Idx).PX_FLAGS, AshTable(Idx).Event, AshTable(Idx).Event_ID,
          AshTable(Idx).SEQ#, AshTable(Idx).P1TEXT, AshTable(Idx).P1, AshTable(Idx).P2TEXT, AshTable(Idx).P2, AshTable(Idx).P3TEXT, AshTable(Idx).P3, AshTable(Idx).Wait_Class, AshTable(Idx).Wait_Class_ID, AshTable(Idx).Wait_Time,
          AshTable(Idx).Session_State, AshTable(Idx).Time_Waited, AshTable(Idx).BLOCKING_SESSION_STATUS, AshTable(Idx).BLOCKING_SESSION, AshTable(Idx).BLOCKING_SESSION_SERIAL#,
          AshTable(Idx).BLOCKING_INST_ID, AshTable(Idx).BLOCKING_HANGCHAIN_INFO,
          AshTable(Idx).Current_Obj#, AshTable(Idx).Current_File#, AshTable(Idx).Current_Block#, AshTable(Idx).Current_Row#,
          AshTable(Idx).Top_Level_Call#, AshTable(Idx).CONSUMER_GROUP_ID, AshTable(Idx).XID, AshTable(Idx).REMOTE_INSTANCE#, AshTable(Idx).TIME_MODEL,
          AshTable(Idx).IN_CONNECTION_MGMT, AshTable(Idx).IN_PARSE, AshTable(Idx).IN_HARD_PARSE, AshTable(Idx).IN_SQL_EXECUTION, AshTable(Idx).IN_PLSQL_EXECUTION,
          AshTable(Idx).IN_PLSQL_RPC, AshTable(Idx).IN_PLSQL_COMPILATION, AshTable(Idx).IN_JAVA_EXECUTION, AshTable(Idx).IN_BIND, AshTable(Idx).IN_CURSOR_CLOSE,
          AshTable(Idx).IN_SEQUENCE_LOAD, AshTable(Idx).IN_INMEMORY_QUERY, AshTable(Idx).IN_INMEMORY_POPULATE, AshTable(Idx).IN_INMEMORY_PREPOPULATE,
          AshTable(Idx).IN_INMEMORY_REPOPULATE, AshTable(Idx).IN_INMEMORY_TREPOPULATE, AshTable(Idx).IN_TABLESPACE_ENCRYPTION, AshTable(Idx).CAPTURE_OVERHEAD,
          AshTable(Idx).REPLAY_OVERHEAD, AshTable(Idx).IS_CAPTURED, AshTable(Idx).IS_REPLAYED, AshTable(Idx).Service_Hash, AshTable(Idx).Program,
          AshTable(Idx).Module, AshTable(Idx).Action, AshTable(Idx).Client_ID, AshTable(Idx).Machine, AshTable(Idx).Port, AshTable(Idx).ECID,
          AshTable(Idx).DBREPLAY_FILE_ID, AshTable(Idx).DBREPLAY_CALL_COUNTER, AshTable(Idx).TM_Delta_Time,
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
      SELECT NVL(MAX(Sample_ID), 0) INTO v_Sample_ID FROM Internal_V$Active_Sess_History;

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