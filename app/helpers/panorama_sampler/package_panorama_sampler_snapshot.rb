module PanoramaSampler::PackagePanoramaSamplerSnapshot
  # PL/SQL-Package for snapshot creation
  def panorama_sampler_snapshot_spec
    "
CREATE OR REPLACE PACKAGE panorama.Panorama_Sampler_Snapshot IS
  -- Panorama-Version: PANORAMA_VERSION
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME

  PROCEDURE Do_Snapshot(p_Snap_ID IN NUMBER, p_Instance IN NUMBER, p_DBID IN NUMBER, p_Con_DBID IN NUMBER, p_Con_ID IN NUMBER,
                        p_Begin_Interval_Time IN DATE, p_Snapshot_Cycle IN NUMBER, p_Snapshot_Retention IN NUMBER);
END Panorama_Sampler_Snapshot;
    "


  end

  def panorama_sampler_snapshot_code
    "
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
      Current_Obj#, Current_File#, Current_Block#, Current_Row#, Top_Level_Call#, CONSUMER_GROUP_ID, XID, REMOTE_INSTANCE#, TIME_MODEL,
      IN_CONNECTION_MGMT, IN_PARSE, IN_HARD_PARSE, IN_SQL_EXECUTION, IN_PLSQL_EXECUTION,
      IN_PLSQL_RPC, IN_PLSQL_COMPILATION, IN_JAVA_EXECUTION, IN_BIND, IN_CURSOR_CLOSE,
      IN_SEQUENCE_LOAD, IN_INMEMORY_QUERY, IN_INMEMORY_POPULATE, IN_INMEMORY_PREPOPULATE,
      IN_INMEMORY_REPOPULATE, IN_INMEMORY_TREPOPULATE, IN_TABLESPACE_ENCRYPTION, CAPTURE_OVERHEAD,
      REPLAY_OVERHEAD, IS_CAPTURED, IS_REPLAYED, Service_Hash, Program, Module, Action, Client_ID, Machine, Port, ECID, DBREPLAY_FILE_ID, DBREPLAY_CALL_COUNTER,
      TM_Delta_Time, TM_DELTA_CPU_TIME, TM_DELTA_DB_TIME, Delta_Time, DELTA_READ_IO_REQUESTS, DELTA_WRITE_IO_REQUESTS, DELTA_READ_IO_BYTES,
      DELTA_WRITE_IO_BYTES, DELTA_INTERCONNECT_IO_BYTES, PGA_Allocated, Temp_Space_Allocated,
      Con_DBID, Con_ID
    ) SELECT p_Snap_ID, p_DBID, Instance_Number, Sample_ID, Sample_Time, Session_ID, Session_Type, Flags, User_ID, SQL_ID, Is_SQLID_Current, SQL_Child_Number,
             SQL_OpCode, SQL_OpName, FORCE_MATCHING_SIGNATURE, TOP_LEVEL_SQL_ID, TOP_LEVEL_SQL_OPCODE, SQL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID,
             SQL_PLAN_OPERATION, SQL_PLAN_OPTIONS, SQL_EXEC_ID, SQL_EXEC_START, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID,
             QC_INSTANCE_ID, QC_SESSION_ID, QC_SESSION_SERIAL#, PX_FLAGS, Event, Event_ID, SEQ#, P1TEXT, P1, P2TEXT, P2, P3TEXT, P3, Wait_Class, Wait_Class_ID, Wait_Time,
             Session_State, Time_waited, BLOCKING_SESSION_STATUS, BLOCKING_SESSION, BLOCKING_SESSION_SERIAL#, BLOCKING_INST_ID, BLOCKING_HANGCHAIN_INFO,
             Current_Obj#, Current_File#, Current_Block#, Current_Row#, Top_Level_Call#, CONSUMER_GROUP_ID, XID, REMOTE_INSTANCE#, TIME_MODEL,
             IN_CONNECTION_MGMT, IN_PARSE, IN_HARD_PARSE, IN_SQL_EXECUTION, IN_PLSQL_EXECUTION,
             IN_PLSQL_RPC, IN_PLSQL_COMPILATION, IN_JAVA_EXECUTION, IN_BIND, IN_CURSOR_CLOSE,
             IN_SEQUENCE_LOAD, IN_INMEMORY_QUERY, IN_INMEMORY_POPULATE, IN_INMEMORY_PREPOPULATE,
             IN_INMEMORY_REPOPULATE, IN_INMEMORY_TREPOPULATE, IN_TABLESPACE_ENCRYPTION, CAPTURE_OVERHEAD,
             REPLAY_OVERHEAD, IS_CAPTURED, IS_REPLAYED, Service_Hash, Program, Module, Action, Client_ID, Machine, Port, ECID, DBREPLAY_FILE_ID, DBREPLAY_CALL_COUNTER,
             TM_Delta_Time, TM_DELTA_CPU_TIME, TM_DELTA_DB_TIME, Delta_Time, DELTA_READ_IO_REQUESTS, DELTA_WRITE_IO_REQUESTS, DELTA_READ_IO_BYTES,
             DELTA_WRITE_IO_BYTES, DELTA_INTERCONNECT_IO_BYTES, PGA_Allocated, Temp_Space_Allocated,
             p_Con_DBID, Con_ID
      FROM   Internal_V$Active_Sess_History
      WHERE  Sample_ID <= v_Max_Sample_ID
      AND    Preserve_10Secs = 'Y'
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

  PROCEDURE Snap_Seg_Stat(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO Panorama_Seg_Stat (SNAP_ID, DBID, INSTANCE_NUMBER, TS#, OBJ#, DATAOBJ#,
                                   LOGICAL_READS_TOTAL, LOGICAL_READS_DELTA,
                                   BUFFER_BUSY_WAITS_TOTAL, BUFFER_BUSY_WAITS_DELTA,
                                   DB_BLOCK_CHANGES_TOTAL, DB_BLOCK_CHANGES_DELTA,
                                   PHYSICAL_READS_TOTAL, PHYSICAL_READS_DELTA,
                                   PHYSICAL_WRITES_TOTAL, PHYSICAL_WRITES_DELTA,
                                   PHYSICAL_READS_DIRECT_TOTAL, PHYSICAL_READS_DIRECT_DELTA,
                                   PHYSICAL_WRITES_DIRECT_TOTAL, PHYSICAL_WRITES_DIRECT_DELTA,
                                   ITL_WAITS_TOTAL, ITL_WAITS_DELTA,
                                   ROW_LOCK_WAITS_TOTAL, ROW_LOCK_WAITS_DELTA,
                                   GC_CR_BLOCKS_SERVED_TOTAL, GC_CR_BLOCKS_SERVED_DELTA,
                                   GC_CU_BLOCKS_SERVED_TOTAL, GC_CU_BLOCKS_SERVED_DELTA,
                                   GC_BUFFER_BUSY_TOTAL, GC_BUFFER_BUSY_DELTA,
                                   GC_CR_BLOCKS_RECEIVED_TOTAL, GC_CR_BLOCKS_RECEIVED_DELTA,
                                   GC_CU_BLOCKS_RECEIVED_TOTAL, GC_CU_BLOCKS_RECEIVED_DELTA,
                                   SPACE_USED_TOTAL, SPACE_USED_DELTA,
                                   SPACE_ALLOCATED_TOTAL, SPACE_ALLOCATED_DELTA,
                                   TABLE_SCANS_TOTAL, TABLE_SCANS_DELTA,
                                   CHAIN_ROW_EXCESS_TOTAL, CHAIN_ROW_EXCESS_DELTA,
                                   PHYSICAL_READ_REQUESTS_TOTAL, PHYSICAL_READ_REQUESTS_DELTA,
                                   PHYSICAL_WRITE_REQUESTS_TOTAL, PHYSICAL_WRITE_REQUESTS_DELTA,
                                   OPTIMIZED_PHYSICAL_READS_TOTAL, OPTIMIZED_PHYSICAL_READS_DELTA,
                                   CON_DBID, CON_ID
    )
    SELECT *
    FROM   (
            SELECT p_SNAP_ID, p_DBID, p_INSTANCE, vs.TS#, vs.OBJ#, vs.DATAOBJ#,
                   vs.LOGICAL_READS_TOTAL,            vs.LOGICAL_READS_TOTAL            - NVL(s.LOGICAL_READS_TOTAL,            vs.LOGICAL_READS_TOTAL)             LOGICAL_READS_DELTA,
                   vs.BUFFER_BUSY_WAITS_TOTAL,        vs.BUFFER_BUSY_WAITS_TOTAL        - NVL(s.BUFFER_BUSY_WAITS_TOTAL,        vs.BUFFER_BUSY_WAITS_TOTAL)         BUFFER_BUSY_WAITS_DELTA,
                   vs.DB_BLOCK_CHANGES_TOTAL,         vs.DB_BLOCK_CHANGES_TOTAL         - NVL(s.DB_BLOCK_CHANGES_TOTAL,         vs.DB_BLOCK_CHANGES_TOTAL)          DB_BLOCK_CHANGES_DELTA,
                   vs.PHYSICAL_READS_TOTAL,           vs.PHYSICAL_READS_TOTAL           - NVL(s.PHYSICAL_READS_TOTAL,           vs.PHYSICAL_READS_TOTAL)            PHYSICAL_READS_DELTA,
                   vs.PHYSICAL_WRITES_TOTAL,          vs.PHYSICAL_WRITES_TOTAL          - NVL(s.PHYSICAL_WRITES_TOTAL,          vs.PHYSICAL_WRITES_TOTAL)           PHYSICAL_WRITES_DELTA,
                   vs.PHYSICAL_READS_DIRECT_TOTAL,    vs.PHYSICAL_READS_DIRECT_TOTAL    - NVL(s.PHYSICAL_READS_DIRECT_TOTAL,    vs.PHYSICAL_READS_DIRECT_TOTAL)     PHYSICAL_READS_DIRECT_DELTA,
                   vs.PHYSICAL_WRITES_DIRECT_TOTAL,   vs.PHYSICAL_WRITES_DIRECT_TOTAL   - NVL(s.PHYSICAL_WRITES_DIRECT_TOTAL,   vs.PHYSICAL_WRITES_DIRECT_TOTAL)    PHYSICAL_WRITES_DIRECT_DELTA,
                   vs.ITL_WAITS_TOTAL,                vs.ITL_WAITS_TOTAL                - NVL(s.ITL_WAITS_TOTAL,                vs.ITL_WAITS_TOTAL)                 ITL_WAITS_DELTA,
                   vs.ROW_LOCK_WAITS_TOTAL,           vs.ROW_LOCK_WAITS_TOTAL           - NVL(s.ROW_LOCK_WAITS_TOTAL,           vs.ROW_LOCK_WAITS_TOTAL)            ROW_LOCK_WAITS_DELTA,
                   vs.GC_CR_BLOCKS_SERVED_TOTAL,      vs.GC_CR_BLOCKS_SERVED_TOTAL      - NVL(s.GC_CR_BLOCKS_SERVED_TOTAL,      vs.GC_CR_BLOCKS_SERVED_TOTAL)       GC_CR_BLOCKS_SERVED_DELTA,
                   vs.GC_CU_BLOCKS_SERVED_TOTAL,      vs.GC_CU_BLOCKS_SERVED_TOTAL      - NVL(s.GC_CU_BLOCKS_SERVED_TOTAL,      vs.GC_CU_BLOCKS_SERVED_TOTAL)       GC_CU_BLOCKS_SERVED_DELTA,
                   vs.GC_BUFFER_BUSY_TOTAL,           vs.GC_BUFFER_BUSY_TOTAL           - NVL(s.GC_BUFFER_BUSY_TOTAL,           vs.GC_BUFFER_BUSY_TOTAL)            GC_BUFFER_BUSY_DELTA,
                   vs.GC_CR_BLOCKS_RECEIVED_TOTAL,    vs.GC_CR_BLOCKS_RECEIVED_TOTAL    - NVL(s.GC_CR_BLOCKS_RECEIVED_TOTAL,    vs.GC_CR_BLOCKS_RECEIVED_TOTAL)     GC_CR_BLOCKS_RECEIVED_DELTA,
                   vs.GC_CU_BLOCKS_RECEIVED_TOTAL,    vs.GC_CU_BLOCKS_RECEIVED_TOTAL    - NVL(s.GC_CU_BLOCKS_RECEIVED_TOTAL,    vs.GC_CU_BLOCKS_RECEIVED_TOTAL)     GC_CU_BLOCKS_RECEIVED_DELTA,
                   vs.SPACE_USED_TOTAL,               vs.SPACE_USED_TOTAL               - NVL(s.SPACE_USED_TOTAL,               vs.SPACE_USED_TOTAL)                SPACE_USED_DELTA,
                   vs.SPACE_ALLOCATED_TOTAL,          vs.SPACE_ALLOCATED_TOTAL          - NVL(s.SPACE_ALLOCATED_TOTAL,          vs.SPACE_ALLOCATED_TOTAL)           SPACE_ALLOCATED_DELTA,
                   vs.TABLE_SCANS_TOTAL,              vs.TABLE_SCANS_TOTAL              - NVL(s.TABLE_SCANS_TOTAL,              vs.TABLE_SCANS_TOTAL)               TABLE_SCANS_DELTA,
                   vs.CHAIN_ROW_EXCESS_TOTAL,         vs.CHAIN_ROW_EXCESS_TOTAL         - NVL(s.CHAIN_ROW_EXCESS_TOTAL,         vs.CHAIN_ROW_EXCESS_TOTAL)          CHAIN_ROW_EXCESS_DELTA,
                   vs.PHYSICAL_READ_REQUESTS_TOTAL,   vs.PHYSICAL_READ_REQUESTS_TOTAL   - NVL(s.PHYSICAL_READ_REQUESTS_TOTAL,   vs.PHYSICAL_READ_REQUESTS_TOTAL)    PHYSICAL_READ_REQUESTS_DELTA,
                   vs.PHYSICAL_WRITE_REQUESTS_TOTAL,  vs.PHYSICAL_WRITE_REQUESTS_TOTAL  - NVL(s.PHYSICAL_WRITE_REQUESTS_TOTAL,  vs.PHYSICAL_WRITE_REQUESTS_TOTAL)   PHYSICAL_WRITE_REQUESTS_DELTA,
                   vs.OPTIMIZED_PHYSICAL_READS_TOTAL, vs.OPTIMIZED_PHYSICAL_READS_TOTAL - NVL(s.OPTIMIZED_PHYSICAL_READS_TOTAL, vs.OPTIMIZED_PHYSICAL_READS_TOTAL)  OPTIMIZED_PHYSICAL_READS_DELTA,
                   p_CON_DBID, #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}
            FROM   (SELECT /*+ NO_MERGE */ TS#, Obj#, DataObj#,
                           SUM(CASE WHEN Statistic_Name = 'logical reads'               THEN Value END) LOGICAL_READS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'buffer busy waits'           THEN Value END) BUFFER_BUSY_WAITS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'db_block_changes'            THEN Value END) DB_BLOCK_CHANGES_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'physical reads'              THEN Value END) PHYSICAL_READS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'physical writes'             THEN Value END) PHYSICAL_WRITES_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'physical reads direct'       THEN Value END) PHYSICAL_READS_DIRECT_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'physical writes direct'      THEN Value END) PHYSICAL_WRITES_DIRECT_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'ITL waits'                   THEN Value END) ITL_WAITS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'row lock waits'              THEN Value END) ROW_LOCK_WAITS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'gc cr blocks served'         THEN Value END) GC_CR_BLOCKS_SERVED_TOTAL,    -- not found in v$Segment_stastistics
                           SUM(CASE WHEN Statistic_Name = 'gc current blocks served'    THEN Value END) GC_CU_BLOCKS_SERVED_TOTAL,    -- not found in v$Segment_stastistics
                           SUM(CASE WHEN Statistic_Name = 'gc buffer busy'              THEN Value END) GC_BUFFER_BUSY_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'gc cr blocks received'       THEN Value END) GC_CR_BLOCKS_RECEIVED_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'gc current blocks received'  THEN Value END) GC_CU_BLOCKS_RECEIVED_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'space used'                  THEN Value END) SPACE_USED_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'space allocated'             THEN Value END) SPACE_ALLOCATED_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'segment scans'               THEN Value END) TABLE_SCANS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'chain row excess'            THEN Value END) CHAIN_ROW_EXCESS_TOTAL,       -- not found in v$Segment_stastistics
                           SUM(CASE WHEN Statistic_Name = 'physical read requests'      THEN Value END) PHYSICAL_READ_REQUESTS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'physical write requests'     THEN Value END) PHYSICAL_WRITE_REQUESTS_TOTAL,
                           SUM(CASE WHEN Statistic_Name = 'optimized physical reads'    THEN Value END) OPTIMIZED_PHYSICAL_READS_TOTAL
                    FROM   v$SegStat
                    GROUP BY TS#, Obj#, DataObj#
                   ) vs
            -- Last Sanpshot for each object
            LEFT OUTER JOIN  (SELECT MAX(Snap_ID) Max_Snap_ID, DBID, INSTANCE_NUMBER, TS#, OBJ#, DATAOBJ#, CON_DBID
                              FROM   Panorama_Seg_Stat
                              GROUP BY DBID, INSTANCE_NUMBER, TS#, OBJ#, DATAOBJ#, CON_DBID
                             ) ms ON ms.DBID=p_DBID AND ms.Instance_Number=p_Instance AND ms.TS#=vs.TS# AND ms.Obj#=vs.Obj# AND ms.DataObj#=vs.DataObj# AND ms.Con_DBID=p_Con_DBID
            -- Complete record of last snapshot for each object
            LEFT OUTER JOIN Panorama_Seg_Stat s ON  s.DBID=p_DBID AND s.Snap_ID=ms.Max_Snap_ID AND s.Instance_Number=p_Instance AND s.TS#=vs.TS# AND s.DataObj#=vs.DataObj# AND s.Obj#=vs.Obj# AND s.Con_DBID=p_Con_DBID
           )
    WHERE      LOGICAL_READS_DELTA            > 0
            OR BUFFER_BUSY_WAITS_DELTA        > 0
            OR DB_BLOCK_CHANGES_DELTA         > 0
            OR PHYSICAL_READS_DELTA           > 0
            OR PHYSICAL_WRITES_DELTA          > 0
            OR PHYSICAL_READS_DIRECT_DELTA    > 0
            OR PHYSICAL_WRITES_DIRECT_DELTA   > 0
            OR ITL_WAITS_DELTA                > 0
            OR ROW_LOCK_WAITS_DELTA           > 0
            OR GC_CR_BLOCKS_SERVED_DELTA      > 0
            OR GC_CU_BLOCKS_SERVED_DELTA      > 0
            OR GC_BUFFER_BUSY_DELTA           > 0
            OR GC_CR_BLOCKS_RECEIVED_DELTA    > 0
            OR GC_CU_BLOCKS_RECEIVED_DELTA    > 0
            OR SPACE_USED_DELTA               > 0
            OR SPACE_ALLOCATED_DELTA          > 0
            OR TABLE_SCANS_DELTA              > 0
            OR CHAIN_ROW_EXCESS_DELTA         > 0
            OR PHYSICAL_READ_REQUESTS_DELTA   > 0
            OR PHYSICAL_WRITE_REQUESTS_DELTA  > 0
            OR OPTIMIZED_PHYSICAL_READS_DELTA > 0
    ;
  END Snap_Seg_Stat;


  PROCEDURE Snap_Service_Name(p_DBID IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO Panorama_Service_Name (DBID, Service_Name_Hash, Service_Name, Con_DBID, Con_ID
    ) SELECT p_DBID, Name_Hash, Name, p_Con_DBID, #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}
      FROM   v$Services s
      WHERE  NOT EXISTS (SELECT 1 FROM Panorama_Service_Name ps WHERE ps.DBID = p_DBID AND ps.Service_Name = s.Name AND ps.Con_DBID = p_Con_DBID)
    ;
  END Snap_Service_Name;

  PROCEDURE Snap_SQLBind(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO Panorama_SQLBind(
      SNAP_ID, DBID, INSTANCE_NUMBER, SQL_ID, NAME, POSITION, DUP_POSITION, DATATYPE, DATATYPE_STRING, CHARACTER_SID,
      PRECISION, SCALE, MAX_LENGTH, WAS_CAPTURED, LAST_CAPTURED, VALUE_STRING, VALUE_ANYDATA,
      CON_DBID, CON_ID
    )
    SELECT p_Snap_ID, p_DBID, p_Instance, b.SQL_ID, b.Name, b.Position, b.Dup_Position, b.DATATYPE, b.DATATYPE_STRING, b.CHARACTER_SID,
           b.PRECISION, b.SCALE, b.MAX_LENGTH, b.WAS_CAPTURED, b.LAST_CAPTURED, b.VALUE_STRING, b.VALUE_ANYDATA,
           p_CON_DBID, #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}
    FROM   v$SQL_Bind_Capture b
    -- Select only the plan of last captured child with that SQL_ID
    JOIN   (SELECT /*+ NO_MERGE */ SQL_ID, MAX(Child_Number) KEEP (DENSE_RANK LAST ORDER BY Last_Captured) Max_Child_Number
            FROM   v$SQL_Bind_Capture
            GROUP BY SQL_ID
           ) bm ON bm.SQL_ID = b.SQL_ID AND bm.Max_Child_Number = b.Child_Number
    ;
  END Snap_SQLBind;

  PROCEDURE Snap_SQL_Plan(p_DBID IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO Panorama_SQL_Plan (
      DBID, SQL_ID, PLAN_HASH_VALUE, ID, OPERATION, OPTIONS, OBJECT_NODE, OBJECT#, OBJECT_OWNER, OBJECT_NAME, OBJECT_ALIAS, OBJECT_TYPE, OPTIMIZER,
      PARENT_ID, DEPTH, POSITION, SEARCH_COLUMNS, COST, CARDINALITY, BYTES, OTHER_TAG, PARTITION_START, PARTITION_STOP, PARTITION_ID, OTHER,
      DISTRIBUTION, CPU_COST, IO_COST, TEMP_SPACE, ACCESS_PREDICATES, FILTER_PREDICATES, PROJECTION, TIME, QBLOCK_NAME,
      REMARKS, TIMESTAMP, OTHER_XML, CON_DBID, CON_ID
    )
    SELECT /*+ ORDERED */
           p_DBID, p.SQL_ID, p.Plan_Hash_Value, p.ID, p.OPERATION, p.OPTIONS, p.OBJECT_NODE, p.OBJECT#, p.OBJECT_OWNER, p.OBJECT_NAME, p.OBJECT_ALIAS, p.OBJECT_TYPE, p.OPTIMIZER,
           p.PARENT_ID, p.DEPTH, p.POSITION, p.SEARCH_COLUMNS, p.COST, p.CARDINALITY, p.BYTES, p.OTHER_TAG, p.PARTITION_START, p.PARTITION_STOP, p.PARTITION_ID, p.OTHER,
           p.DISTRIBUTION, p.CPU_COST, p.IO_COST, p.TEMP_SPACE, p.ACCESS_PREDICATES, p.FILTER_PREDICATES, p.PROJECTION, p.TIME, p.QBLOCK_NAME,
           p.REMARKS, p.TIMESTAMP, p.OTHER_XML, p_CON_DBID, #{PanoramaConnection.db_version >= '12.1' ? "p.Con_ID" : "0"}
    FROM   v$SQL_Plan p
    -- Select only the plan of last parsed child with that plan_hash_value
    JOIN   (SELECT /*+ NO_MERGE */ SQL_ID, Plan_Hash_Value, MAX(Child_Number) KEEP (DENSE_RANK LAST ORDER BY Timestamp) Max_Child_Number
            FROM   v$SQL_Plan
            GROUP BY SQL_ID, Plan_Hash_Value
           ) pm ON pm.SQL_ID = p.SQL_ID AND pm.Plan_Hash_Value = p.Plan_Hash_Value AND pm.Max_Child_Number = p.Child_Number
    LEFT OUTER JOIN PANORAMA_SQL_PLAN e on e.DBID = p_DBID AND e.SQL_ID = p.SQL_ID AND e.Plan_Hash_Value = p.Plan_Hash_Value AND e.ID = p.ID AND e.Con_DBID = p_Con_DBID
    WHERE  e.DBID IS NULL   -- New records does not yet exists in table
    ;
  END Snap_SQL_Plan;

  PROCEDURE Snap_SQLStat(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER, p_Con_DBID IN NUMBER, p_Begin_Interval_Time IN DATE) IS
  BEGIN
    -- Child cursors created in this snapshot period should count full in delta because they are not counted in previous snapshot's total values
    -- Child cursors created in former snapshots shoud only count with the difference new total - old total, but not smaller than 0
    INSERT INTO Panorama_SQLStat (Snap_ID, DBID, Instance_Number, SQL_ID, Plan_Hash_Value, OPTIMIZER_COST, OPTIMIZER_MODE, OPTIMIZER_ENV_HASH_VALUE, SHARABLE_MEM,
        LOADED_VERSIONS, VERSION_COUNT, MODULE, ACTION, SQL_PROFILE, FORCE_MATCHING_SIGNATURE, PARSING_SCHEMA_ID, PARSING_SCHEMA_NAME, PARSING_USER_ID,
        FETCHES_TOTAL, FETCHES_DELTA, END_OF_FETCH_COUNT_TOTAL, END_OF_FETCH_COUNT_DELTA, SORTS_TOTAL, SORTS_DELTA, EXECUTIONS_TOTAL, EXECUTIONS_DELTA,
        PX_SERVERS_EXECS_TOTAL, PX_SERVERS_EXECS_DELTA, LOADS_TOTAL, LOADS_DELTA, INVALIDATIONS_TOTAL, INVALIDATIONS_DELTA, PARSE_CALLS_TOTAL, PARSE_CALLS_DELTA,
        DISK_READS_TOTAL, DISK_READS_DELTA, BUFFER_GETS_TOTAL, BUFFER_GETS_DELTA, ROWS_PROCESSED_TOTAL, ROWS_PROCESSED_DELTA, CPU_TIME_TOTAL, CPU_TIME_DELTA,
        ELAPSED_TIME_TOTAL, ELAPSED_TIME_DELTA, IOWAIT_TOTAL, IOWAIT_DELTA, CLWAIT_TOTAL, CLWAIT_DELTA, APWAIT_TOTAL, APWAIT_DELTA, CCWAIT_TOTAL, CCWAIT_DELTA,
        DIRECT_WRITES_TOTAL, DIRECT_WRITES_DELTA, PLSEXEC_TIME_TOTAL, PLSEXEC_TIME_DELTA, JAVEXEC_TIME_TOTAL, JAVEXEC_TIME_DELTA,
        #{"IO_OFFLOAD_ELIG_BYTES_TOTAL, IO_OFFLOAD_ELIG_BYTES_DELTA," if PanoramaConnection.db_version >= '12.1'}
        #{"IO_INTERCONNECT_BYTES_TOTAL, IO_INTERCONNECT_BYTES_DELTA," if PanoramaConnection.db_version >= '12.1'}
        PHYSICAL_READ_REQUESTS_TOTAL, PHYSICAL_READ_REQUESTS_DELTA, PHYSICAL_READ_BYTES_TOTAL, PHYSICAL_READ_BYTES_DELTA,
        PHYSICAL_WRITE_REQUESTS_TOTAL, PHYSICAL_WRITE_REQUESTS_DELTA, PHYSICAL_WRITE_BYTES_TOTAL, PHYSICAL_WRITE_BYTES_DELTA,
        #{"OPTIMIZED_PHYSICAL_READS_TOTAL, OPTIMIZED_PHYSICAL_READS_DELTA, "  if PanoramaConnection.db_version >= '12.1'}
        #{"CELL_UNCOMPRESSED_BYTES_TOTAL, CELL_UNCOMPRESSED_BYTES_DELTA, "    if PanoramaConnection.db_version >= '12.1'}
        #{"IO_OFFLOAD_RETURN_BYTES_TOTAL, IO_OFFLOAD_RETURN_BYTES_DELTA, "    if PanoramaConnection.db_version >= '12.2'}
        BIND_DATA,
        Con_DBID, Con_ID
    ) SELECT  /*+ INDEX(p, PANORAMA_SQLSTAT_PK) PUSH_PRED(ms) OPT_PARAM('_push_join_predicate' 'TRUE')  */
              p_Snap_ID, p_DBID, p_Instance, s.SQL_ID, s.Plan_Hash_Value, s.OPTIMIZER_COST, s.OPTIMIZER_MODE, s.OPTIMIZER_ENV_HASH_VALUE, s.SHARABLE_MEM,
              s.LOADED_VERSIONS, s.VERSION_COUNT, s.MODULE, s.ACTION, s.SQL_PROFILE, s.FORCE_MATCHING_SIGNATURE, s.PARSING_SCHEMA_ID, s.PARSING_SCHEMA_NAME, s.PARSING_USER_ID,
              s.Fetches,                            GREATEST(NVL(s.Fetches_O                   , 0) - NVL(p.Fetches_Total,                  0), 0) + NVL(s.Fetches_N,                     0),
              s.End_Of_Fetch_Count,                 GREATEST(NVL(s.End_Of_Fetch_Count_O        , 0) - NVL(p.End_Of_Fetch_Count_Total,       0), 0) + NVL(s.End_Of_Fetch_Count_N,          0),
              s.Sorts,                              GREATEST(NVL(s.Sorts_O                     , 0) - NVL(p.Sorts_Total,                    0), 0) + NVL(s.Sorts_N,                       0),
              s.Executions,                         GREATEST(NVL(s.Executions_O                , 0) - NVL(p.Executions_Total,               0), 0) + NVL(s.Executions_N,                  0),
              s.PX_Servers_Execs,                   GREATEST(NVL(s.PX_Servers_Execs_O          , 0) - NVL(p.PX_Servers_Execs_Total,         0), 0) + NVL(s.PX_Servers_Execs_N,            0),
              s.Loads,                              GREATEST(NVL(s.Loads_O                     , 0) - NVL(p.Loads_Total,                    0), 0) + NVL(s.Loads_N,                       0),
              s.Invalidations,                      GREATEST(NVL(s.Invalidations_O             , 0) - NVL(p.Invalidations_Total,            0), 0) + NVL(s.Invalidations_N,               0),
              s.Parse_Calls,                        GREATEST(NVL(s.Parse_Calls_O               , 0) - NVL(p.Parse_Calls_Total,              0), 0) + NVL(s.Parse_Calls_N,                 0),
              s.Disk_Reads,                         GREATEST(NVL(s.Disk_Reads_O                , 0) - NVL(p.Disk_Reads_Total,               0), 0) + NVL(s.Disk_Reads_N,                  0),
              s.Buffer_Gets,                        GREATEST(NVL(s.Buffer_Gets_O               , 0) - NVL(p.Buffer_Gets_Total,              0), 0) + NVL(s.Buffer_Gets_N,                 0),
              s.Rows_Processed,                     GREATEST(NVL(s.Rows_Processed_O            , 0) - NVL(p.Rows_Processed_Total,           0), 0) + NVL(s.Rows_Processed_N,              0),
              s.CPU_Time,                           GREATEST(NVL(s.CPU_Time_O                  , 0) - NVL(p.CPU_Time_Total,                 0), 0) + NVL(s.CPU_Time_N,                    0),
              s.Elapsed_Time,                       GREATEST(NVL(s.Elapsed_Time_O              , 0) - NVL(p.Elapsed_Time_Total,             0), 0) + NVL(s.Elapsed_Time_N,                0),
              s.User_IO_Wait_Time,                  GREATEST(NVL(s.User_IO_Wait_Time_O         , 0) - NVL(p.IOWait_Total,                   0), 0) + NVL(s.User_IO_Wait_Time_N,           0),
              s.Cluster_Wait_Time,                  GREATEST(NVL(s.Cluster_Wait_Time_O         , 0) - NVL(p.CLWait_Total,                   0), 0) + NVL(s.Cluster_Wait_Time_N,           0),
              s.Application_Wait_Time,              GREATEST(NVL(s.Application_Wait_Time_O     , 0) - NVL(p.ApWait_Total,                   0), 0) + NVL(s.Application_Wait_Time_N,       0),
              s.Concurrency_Wait_Time,              GREATEST(NVL(s.Concurrency_Wait_Time_O     , 0) - NVL(p.CCWait_Total,                   0), 0) + NVL(s.Concurrency_Wait_Time_N,       0),
              s.Direct_Writes,                      GREATEST(NVL(s.Direct_Writes_O             , 0) - NVL(p.Direct_Writes_Total,            0), 0) + NVL(s.Direct_Writes_N,               0),
              s.PLSQL_Exec_Time,                    GREATEST(NVL(s.PLSQL_Exec_Time_O           , 0) - NVL(p.PLSExec_Time_Total,             0), 0) + NVL(s.PLSQL_Exec_Time_N,             0),
              s.Java_Exec_Time,                     GREATEST(NVL(s.Java_Exec_Time_O            , 0) - NVL(p.JavExec_Time_Total,             0), 0) + NVL(s.Java_Exec_Time_N,              0),
              #{"s.IO_OFFLOAD_ELIG_BYTES,           GREATEST(NVL(s.IO_OFFLOAD_ELIG_BYTES_O     , 0) - NVL(p.IO_OFFLOAD_ELIG_BYTES_Total,    0), 0) + NVL(s.IO_OFFLOAD_ELIG_BYTES_N,       0), " if PanoramaConnection.db_version >= '12.1'}
              #{"s.IO_Interconnect_Bytes,           GREATEST(NVL(s.IO_Interconnect_Bytes_O     , 0) - NVL(p.IO_Interconnect_Bytes_Total,    0), 0) + NVL(s.IO_Interconnect_Bytes_N,       0), " if PanoramaConnection.db_version >= '12.1'}
              s.Physical_Read_Requests,             GREATEST(NVL(s.Physical_Read_Requests_O    , 0) - NVL(p.Physical_Read_Requests_Total,   0), 0) + NVL(s.Physical_Read_Requests_N,      0),
              s.Physical_Read_Bytes,                GREATEST(NVL(s.Physical_Read_Bytes_O       , 0) - NVL(p.Physical_Read_Bytes_Total,      0), 0) + NVL(s.Physical_Read_Bytes_N,         0),
              s.Physical_Write_Requests,            GREATEST(NVL(s.Physical_Write_Requests_O   , 0) - NVL(p.Physical_Write_Requests_Total,  0), 0) + NVL(s.Physical_Write_Requests_N,     0),
              s.Physical_Write_Bytes,               GREATEST(NVL(s.Physical_Write_Bytes_O      , 0) - NVL(p.Physical_Write_Bytes_Total,     0), 0) + NVL(s.Physical_Write_Bytes_N,        0),
              #{"s.Optimized_Physical_Reads,        GREATEST(NVL(s.Optimized_Physical_Reads_O  , 0) - NVL(p.Optimized_Physical_Reads_Total, 0), 0) + NVL(s.Optimized_Physical_Reads_N,    0), "  if PanoramaConnection.db_version >= '12.1'}
              #{"s.IO_Cell_Uncompressed_Bytes,      GREATEST(NVL(s.IO_Cell_Uncompressed_Bytes_O, 0) - NVL(p.Cell_Uncompressed_Bytes_Total,  0), 0) + NVL(s.IO_Cell_Uncompressed_Bytes_N,  0), "  if PanoramaConnection.db_version >= '12.1'}
              #{"s.IO_Offload_Return_Bytes,         GREATEST(NVL(s.IO_Offload_Return_Bytes_O   , 0) - NVL(p.IO_Offload_Return_Bytes_Total,  0), 0) + NVL(s.IO_Offload_Return_Bytes_N,     0), "  if PanoramaConnection.db_version >= '12.2'}
              s.Bind_Data,
              p_Con_DBID,
              #{PanoramaConnection.db_version >= '12.1' ? "s.Con_ID" : "0"}
      FROM   --v$SQLArea s
             (SELECT SQL_ID, Plan_Hash_Value, #{"Con_ID, " if PanoramaConnection.db_version >= '12.1' } MAX(Optimizer_Cost) Optimizer_Cost, MAX(Optimizer_Mode) Optimizer_Mode, MAX(Optimizer_Env_Hash_Value) Optimizer_Env_Hash_Value,
                     SUM(SHARABLE_MEM) SHARABLE_MEM, SUM(LOADED_VERSIONS) LOADED_VERSIONS, COUNT(*) VERSION_COUNT, MAX(Module) Module, MAX(Action) Action, MAX(SQL_PROFILE) SQL_PROFILE, MAX(FORCE_MATCHING_SIGNATURE) FORCE_MATCHING_SIGNATURE,
                     MAX(PARSING_SCHEMA_ID) PARSING_SCHEMA_ID, MAX(PARSING_SCHEMA_NAME) PARSING_SCHEMA_NAME, MAX(PARSING_USER_ID) PARSING_USER_ID,
                     SUM(Fetches) Fetches,                                            SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Fetches END) Fetches_N,                                        SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Fetches END) Fetches_O,
                     SUM(End_Of_Fetch_Count) End_Of_Fetch_Count,                      SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN End_Of_Fetch_Count END) End_Of_Fetch_Count_N,                  SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN End_Of_Fetch_Count END) End_Of_Fetch_Count_O,
                     SUM(Sorts) Sorts,                                                SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Sorts END) Sorts_N,                                            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Sorts END) Sorts_O,
                     SUM(Executions) Executions,                                      SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Executions END) Executions_N,                                  SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Executions END) Executions_O,
                     SUM(PX_Servers_Executions) PX_Servers_Execs,                     SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN PX_Servers_Executions END) PX_Servers_Execs_N,                 SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN PX_Servers_Executions END) PX_Servers_Execs_O,
                     SUM(Loads) Loads,                                                SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Loads END) Loads_N,                                            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Loads END) Loads_O,
                     SUM(Invalidations) Invalidations,                                SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Invalidations END) Invalidations_N,                            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Executions END) Invalidations_O,
                     SUM(Parse_Calls) Parse_Calls,                                    SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Parse_Calls END) Parse_Calls_N,                                SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Parse_Calls END) Parse_Calls_O,
                     SUM(Disk_Reads) Disk_Reads,                                      SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Disk_Reads END) Disk_Reads_N,                                  SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Disk_Reads END) Disk_Reads_O,
                     SUM(Buffer_Gets) Buffer_Gets,                                    SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Buffer_Gets END) Buffer_Gets_N,                                SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Buffer_Gets END) Buffer_Gets_O,
                     SUM(Rows_Processed) Rows_Processed,                              SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Rows_Processed END) Rows_Processed_N,                          SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Rows_Processed END) Rows_Processed_O,
                     SUM(CPU_Time) CPU_Time,                                          SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN CPU_Time END) CPU_Time_N,                                      SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN CPU_Time END) CPU_Time_O,
                     SUM(Elapsed_Time) Elapsed_Time,                                  SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Elapsed_Time END) Elapsed_Time_N,                              SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Elapsed_Time END) Elapsed_Time_O,
                     SUM(User_IO_Wait_Time) User_IO_Wait_Time,                        SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN User_IO_Wait_Time END) User_IO_Wait_Time_N,                    SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN User_IO_Wait_Time END) User_IO_Wait_Time_O,
                     SUM(Cluster_Wait_Time) Cluster_Wait_Time,                        SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Cluster_Wait_Time END) Cluster_Wait_Time_N,                    SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Cluster_Wait_Time END) Cluster_Wait_Time_O,
                     SUM(Application_Wait_Time) Application_Wait_Time,                SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Application_Wait_Time END) Application_Wait_Time_N,            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Application_Wait_Time END) Application_Wait_Time_O,
                     SUM(Concurrency_Wait_Time) Concurrency_Wait_Time,                SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Concurrency_Wait_Time END) Concurrency_Wait_Time_N,            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Concurrency_Wait_Time END) Concurrency_Wait_Time_O,
                     SUM(Direct_Writes) Direct_Writes,                                SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Direct_Writes END) Direct_Writes_N,                            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Direct_Writes END) Direct_Writes_O,
                     SUM(PLSQL_Exec_Time) PLSQL_Exec_Time,                            SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN PLSQL_Exec_Time END) PLSQL_Exec_Time_N,                        SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN PLSQL_Exec_Time END) PLSQL_Exec_Time_O,
                     SUM(Java_Exec_Time) Java_Exec_Time,                              SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Java_Exec_Time END) Java_Exec_Time_N,                          SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Java_Exec_Time END) Java_Exec_Time_O,
                     #{"SUM(IO_CELL_OFFLOAD_ELIGIBLE_BYTES) IO_OFFLOAD_ELIG_BYTES,    SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN IO_CELL_OFFLOAD_ELIGIBLE_BYTES END) IO_OFFLOAD_ELIG_BYTES_N,   SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN IO_CELL_OFFLOAD_ELIGIBLE_BYTES END) IO_OFFLOAD_ELIG_BYTES_O,
                        SUM(IO_Interconnect_Bytes) IO_Interconnect_Bytes,             SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN IO_Interconnect_Bytes END) IO_Interconnect_Bytes_N,            SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN IO_Interconnect_Bytes END) IO_Interconnect_Bytes_O," if PanoramaConnection.db_version >= '12.1'}
                     SUM(Physical_Read_Requests) Physical_Read_Requests,              SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Physical_Read_Requests END) Physical_Read_Requests_N,          SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Physical_Read_Requests END) Physical_Read_Requests_O,
                     SUM(Physical_Read_Bytes) Physical_Read_Bytes,                    SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Physical_Read_Bytes END) Physical_Read_Bytes_N,                SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Physical_Read_Bytes END) Physical_Read_Bytes_O,
                     SUM(Physical_Write_Requests) Physical_Write_Requests,            SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Physical_Write_Requests END) Physical_Write_Requests_N,        SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Physical_Write_Requests END) Physical_Write_Requests_O,
                     SUM(Physical_Write_Bytes) Physical_Write_Bytes,                  SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Physical_Write_Bytes END) Physical_Write_Bytes_N,              SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Physical_Write_Bytes END) Physical_Write_Bytes_O,
                     #{"SUM(Optimized_Phy_Read_Requests) Optimized_Physical_Reads,    SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN Optimized_Phy_Read_Requests END) Optimized_Physical_Reads_N,   SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN Optimized_Phy_Read_Requests END) Optimized_Physical_Reads_O,
                        SUM(IO_Cell_Uncompressed_Bytes) IO_Cell_Uncompressed_Bytes,   SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN IO_Cell_Uncompressed_Bytes END) IO_Cell_Uncompressed_Bytes_N,  SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN IO_Cell_Uncompressed_Bytes END) IO_Cell_Uncompressed_Bytes_O,"  if PanoramaConnection.db_version >= '12.1'}
                     #{"SUM(IO_Cell_Offload_Returned_Bytes) IO_Offload_Return_Bytes,  SUM(CASE WHEN dLast_Load_Time >  i.Begin THEN IO_Cell_Offload_Returned_Bytes END) IO_Offload_Return_Bytes_N, SUM(CASE WHEN dLast_Load_Time <= i.Begin THEN IO_Cell_Offload_Returned_Bytes END) IO_Offload_Return_Bytes_O,"  if PanoramaConnection.db_version >= '12.2'}
                     MAX(Bind_Data) Bind_Data
              FROM   (SELECT v.*, TO_DATE(Last_Load_time, 'YYYY-MM-DD/HH24:MI:SS') dLast_Load_Time FROM v$SQL v)
              CROSS JOIN (SELECT p_Begin_Interval_Time Begin FROM DUAL) i
              GROUP BY SQL_ID, Plan_Hash_Value #{", Con_ID" if PanoramaConnection.db_version >= '12.1' }
              HAVING MAX(Last_Active_time) > MAX(i.Begin)  -- Count all childs if one child is active in period
             ) s
      LEFT OUTER JOIN  (SELECT MAX(Snap_ID) Max_Snap_ID, DBID, Instance_Number, SQL_ID, Plan_Hash_Value, Con_DBID
                        FROM   Panorama_SQLStat
                        GROUP BY DBID, Instance_Number, SQL_ID, Plan_Hash_Value, Con_DBID
                       ) ms ON ms.DBID=p_DBID AND ms.Instance_Number=p_Instance AND ms.SQL_ID=s.SQL_ID AND ms.Plan_Hash_Value=s.Plan_Hash_Value AND ms.Con_DBID=p_Con_DBID
      LEFT OUTER JOIN Panorama_SQLStat p ON  p.DBID=p_DBID AND p.Snap_ID=ms.Max_Snap_ID AND p.Instance_Number=p_Instance AND p.SQL_ID=s.SQL_ID AND p.Plan_Hash_Value=s.Plan_Hash_Value AND p.Con_DBID=p_Con_DBID
    ;
  END Snap_SQLStat;

  PROCEDURE Snap_SQLText(p_DBID IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO Panorama_SQLText (DBID, SQL_ID, SQL_Text, Command_Type, Con_DBID, Con_ID)
    SELECT p_DBID, s.SQL_ID, s.SQL_FullText, s.Command_Type, p_Con_DBID,
           #{PanoramaConnection.db_version >= '12.1' ? "s.Con_ID" : "0"}
    FROM   v$SQLArea s
    LEFT OUTER JOIN Panorama_SQLText p ON p.DBID=p_DBID AND p.SQL_ID=s.SQL_ID AND p.Con_DBID=p_Con_DBID
    WHERE p.SQL_ID IS NULL
    ;
  END Snap_SQLText;

  PROCEDURE Snap_StatName(p_DBID IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO Internal_StatName(DBID, STAT_ID, Name, Con_DBID, Con_ID)
    SELECT p_DBID, Stat_ID, Name, p_Con_DBID, 0
    FROM   V$StatName n
    WHERE  n.Stat_ID NOT IN (SELECT Stat_ID FROM Internal_StatName)
    ;
  END Snap_StatName;

  PROCEDURE Snap_System_Event(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO Panorama_System_Event(SNAP_ID, DBID, INSTANCE_NUMBER, EVENT_ID, EVENT_NAME, WAIT_CLASS_ID, WAIT_CLASS,
                                      TOTAL_WAITS, TOTAL_TIMEOUTS, TIME_WAITED_MICRO, TOTAL_WAITS_FG, TOTAL_TIMEOUTS_FG, TIME_WAITED_MICRO_FG,
                                      CON_DBID, CON_ID
                                     )
    SELECT p_SNAP_ID, p_DBID, p_INSTANCE, EVENT_ID, EVENT, WAIT_CLASS_ID, WAIT_CLASS,
           TOTAL_WAITS, TOTAL_TIMEOUTS, TIME_WAITED_MICRO, TOTAL_WAITS_FG, TOTAL_TIMEOUTS_FG, TIME_WAITED_MICRO_FG,
           p_CON_DBID, #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}
    FROM   V$System_Event
    ;
  END Snap_System_Event;

  PROCEDURE Snap_SysStat(p_Snap_ID IN NUMBER, p_DBID IN NUMBER, p_Instance IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    INSERT INTO Internal_SysStat(SNAP_ID, DBID, INSTANCE_NUMBER, STAT_ID, VALUE, CON_DBID, CON_ID)
    SELECT p_Snap_ID, p_DBID, p_Instance, Stat_ID, Value, p_Con_DBID,  #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}
    FROM   V$SysStat
    ;
  END Snap_SysStat;

  PROCEDURE Snap_TopLevelCallName(p_DBID IN NUMBER, p_Con_DBID IN NUMBER) IS
  BEGIN
    #{ PanoramaConnection.db_version >= '11.2' ?
           "
    INSERT INTO Panorama_TopLevelCall_Name (DBID, Top_Level_Call#, Top_Level_Call_Name, Con_DBID, Con_ID)
    SELECT p_DBID, Top_Level_Call#, Top_Level_Call_Name, p_Con_DBID, #{PanoramaConnection.db_version >= '12.1' ? "s.Con_ID" : "0"}
    FROM   v$TopLevelCall s
    WHERE  NOT EXISTS (SELECT 1 FROM Panorama_TopLevelCall_Name t WHERE t.DBID = p_DBID AND t.Top_Level_Call# = s.Top_Level_Call# AND t.Con_DBID = p_Con_DBID)
    ;
           " : "NULL;"
    }
  END Snap_TopLevelCallName;

  PROCEDURE Snap_WR_Control(p_DBID IN NUMBER, p_Snapshot_Cycle IN NUMBER, p_Snapshot_Retention IN NUMBER) IS
  BEGIN
    -- Create record if not exists
    INSERT INTO Panorama_WR_Control (DBID, SNAP_INTERVAL, RETENTION, Con_ID)
    SELECT p_DBID, NUMTODSINTERVAL(p_Snapshot_Cycle, 'MINUTE'), NUMTODSINTERVAL(p_Snapshot_Retention, 'DAY'),
           #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"}
    FROM   v$Instance
    WHERE  NOT EXISTS (SELECT 1 FROM Panorama_WR_Control WHERE DBID = p_DBID)
    ;

    UPDATE Panorama_WR_Control SET SNAP_INTERVAL  = NUMTODSINTERVAL(p_Snapshot_Cycle,     'MINUTE'),
                                   RETENTION      = NUMTODSINTERVAL(p_Snapshot_Retention, 'DAY'),
                                   Con_ID = (SELECT  #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"} FROM   v$Instance)
    WHERE DBID = p_DBID
    ;
  END Snap_WR_Control;

  PROCEDURE Do_Snapshot(p_Snap_ID IN NUMBER, p_Instance IN NUMBER, p_DBID IN NUMBER, p_Con_DBID IN NUMBER, p_Con_ID IN NUMBER,
                        p_Begin_Interval_Time IN DATE, p_Snapshot_Cycle IN NUMBER, p_Snapshot_Retention IN NUMBER) IS
  BEGIN
    Move_ASH_To_Snapshot_Table(p_Snap_ID,   p_DBID,     p_Con_DBID);
    Snap_DB_cache_Advice      (p_Snap_ID,   p_DBID,     p_Instance,   p_Con_DBID);
    Snap_Log                  (p_Snap_ID,   p_DBID,     p_Instance,   p_Con_DBID);
    Snap_Service_Name         (p_DBID,      p_Con_DBID);
    Snap_Seg_Stat             (p_Snap_ID,   p_DBID,     p_Instance,   p_Con_DBID);
    Snap_SQLBind              (p_Snap_ID,   p_DBID,     p_Instance,   p_Con_DBID);
    Snap_SQL_Plan             (p_DBID,      p_Con_DBID);
    Snap_SQLStat              (p_Snap_ID,   p_DBID,     p_Instance,   p_Con_DBID,    p_Begin_Interval_Time);
    Snap_SQLText              (p_DBID,      p_Con_DBID);
    Snap_StatName             (p_DBID,      p_Con_DBID);
    Snap_System_Event         (p_Snap_ID,   p_DBID,     p_Instance,   p_Con_DBID);
    Snap_SysStat              (p_Snap_ID,   p_DBID,     p_Instance,   p_Con_DBID);
    Snap_TopLevelCallName     (p_DBID,      p_Con_DBID);
    Snap_WR_Control           (p_DBID,      p_Snapshot_Cycle, p_Snapshot_Retention);
  END Do_Snapshot;
    "
  end

  def panorama_sampler_snapshot_body
    "
CREATE OR REPLACE PACKAGE BODY panorama.Panorama_Sampler_Snapshot IS
  -- Panorama-Version: PANORAMA_VERSION
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME
#{panorama_sampler_snapshot_code}
END Panorama_Sampler_Snapshot;
    "
  end

end