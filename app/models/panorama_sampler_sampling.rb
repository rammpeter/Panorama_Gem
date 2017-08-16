class PanoramaSamplerSampling

  include ExceptionHelper


  def self.do_sampling(sampler_config)
    PanoramaSamplerSampling.new(sampler_config).do_sampling_internal
  end

  def self.do_housekeeping(sampler_config)
    PanoramaSamplerSampling.new(sampler_config).do_housekeeping_internal
  end

  def self.run_ash_daemon(sampler_config, snapshot_time)
    PanoramaSamplerSampling.new(sampler_config).run_ash_daemon_internal(snapshot_time)
  rescue Exception => e
    # try second time to fix error ORA-04068 existing state of package has changed ...
    PanoramaSamplerSampling.new(sampler_config).run_ash_daemon_internal(snapshot_time)
  end

  def initialize(sampler_config)
    @sampler_config = sampler_config
  end

  def do_sampling_internal
    last_snap = PanoramaConnection.sql_select_first_row ["SELECT Snap_ID, End_Interval_Time
                                                    FROM   #{@sampler_config[:owner]}.Panorama_Snapshot
                                                    WHERE  DBID=? AND Instance_Number=?
                                                    AND    Snap_ID = (SELECT MAX(Snap_ID) FROM #{@sampler_config[:owner]}.Panorama_Snapshot WHERE DBID=? AND Instance_Number=?)
                                                   ", PanoramaConnection.dbid, PanoramaConnection.instance_number, PanoramaConnection.dbid, PanoramaConnection.instance_number]

    if last_snap.nil?                                                           # First access
      @snap_id = 1
      begin_interval_time = (PanoramaConnection.sql_select_one "SELECT SYSDATE FROM Dual") - (@sampler_config[:snapshot_cycle]).minutes
    else
      @snap_id            = last_snap.snap_id + 1
      begin_interval_time = last_snap.end_interval_time
    end

    ## DBA_Hist_Snapshot, must be the first atomic transaction to ensure that next snap_id is exactly incremented
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config[:owner]}.Panorama_Snapshot (Snap_ID, DBID, Instance_Number, Begin_Interval_Time, End_Interval_Time, Con_ID
                                    ) VALUES (?, ?, ?, ?, SYSDATE, ?)",
                                    @snap_id, PanoramaConnection.dbid, PanoramaConnection.instance_number, begin_interval_time, PanoramaConnection.con_id]

    ## TODO: Con_DBID mit realen werten des Containers füllen, falls PDB-übergreifendes Sampling gewünscht wird
    PanoramaConnection.sql_execute [" BEGIN #{@sampler_config[:owner]}.Panorama_Sampler_Snapshot.Do_Snapshot(?, ?, ?, ?, ?); END;",
                                    @snap_id, PanoramaConnection.instance_number, PanoramaConnection.dbid, con_dbid, PanoramaConnection.con_id]





    ## DBA_Hist_SQLStat
=begin
    Child cursors created in this snapshot period should count full in delta because they are not counted in previous snapshot's total values
    Child cursors created in former snapshots shoud only count with the difference new total - old total, but not smaller than 0
=end
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config[:owner]}.Panorama_SQLStat (Snap_ID, DBID, Instance_Number, SQL_ID, Plan_Hash_Value, OPTIMIZER_COST, OPTIMIZER_MODE, OPTIMIZER_ENV_HASH_VALUE, SHARABLE_MEM,
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
                                              ?, ?, ?, s.SQL_ID, s.Plan_Hash_Value, s.OPTIMIZER_COST, s.OPTIMIZER_MODE, s.OPTIMIZER_ENV_HASH_VALUE, s.SHARABLE_MEM,
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
                                              ? #{PanoramaConnection.db_version >= '12.1' ? ", s.Con_ID" : ", 0"}
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
                                              CROSS JOIN (SELECT ? Begin FROM DUAL) i
                                              GROUP BY SQL_ID, Plan_Hash_Value #{", Con_ID" if PanoramaConnection.db_version >= '12.1' }
                                              HAVING MAX(Last_Active_time) > MAX(i.Begin)  -- Count all childs if one child is active in period
                                             ) s
                                      LEFT OUTER JOIN  (SELECT MAX(Snap_ID) Max_Snap_ID, DBID, Instance_Number, SQL_ID, Plan_Hash_Value, Con_DBID
                                                        FROM   Panorama_SQLStat
                                                        GROUP BY DBID, Instance_Number, SQL_ID, Plan_Hash_Value, Con_DBID
                                                       ) ms ON ms.DBID=? AND ms.Instance_Number=? AND ms.SQL_ID=s.SQL_ID AND ms.Plan_Hash_Value=s.Plan_Hash_Value AND ms.Con_DBID=?
                                      LEFT OUTER JOIN Panorama_SQLStat p ON  p.DBID=? AND p.Snap_ID=ms.Max_Snap_ID AND p.Instance_Number=? AND p.SQL_ID=s.SQL_ID AND p.Plan_Hash_Value=s.Plan_Hash_Value AND p.Con_DBID=?
                                    ",  @snap_id, PanoramaConnection.dbid, PanoramaConnection.instance_number, con_dbid, begin_interval_time, PanoramaConnection.dbid, PanoramaConnection.instance_number, con_dbid, PanoramaConnection.dbid,  PanoramaConnection.instance_number, con_dbid]

    ## DBA_Hist_SQLText
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config[:owner]}.Panorama_SQLText (DBID, SQL_ID, SQL_Text, Command_Type, Con_DBID, Con_ID)
                                      SELECT ?, s.SQL_ID, s.SQL_FullText, s.Command_Type,
                                              ? #{PanoramaConnection.db_version >= '12.1' ? ", s.Con_ID" : ", 0"}
                                      FROM   v$SQLArea s
                                      LEFT OUTER JOIN Panorama_SQLText p ON p.DBID=? AND p.SQL_ID=s.SQL_ID AND p.Con_DBID=?
                                      WHERE p.SQL_ID IS NULL
                                    ",  PanoramaConnection.dbid, con_dbid, PanoramaConnection.dbid, con_dbid]


    ## DBA_Hist_WR_Control
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config[:owner]}.Panorama_WR_Control (DBID, SNAP_INTERVAL, RETENTION, Con_ID)
                                      SELECT ?, NUMTODSINTERVAL(?, 'MINUTE'), NUMTODSINTERVAL(?, 'DAY')
                                              #{PanoramaConnection.db_version >= '12.1' ? ", Con_ID" : ", 0"}
                                      FROM   v$Instance
                                      WHERE  NOT EXISTS (SELECT 1 FROM #{@sampler_config[:owner]}.Panorama_WR_Control WHERE DBID = ?)
                                    ",  PanoramaConnection.dbid, @sampler_config[:snapshot_cycle], @sampler_config[:snapshot_retention], PanoramaConnection.dbid]   # Create record if not exists
    PanoramaConnection.sql_execute ["UPDATE #{@sampler_config[:owner]}.Panorama_WR_Control SET SNAP_INTERVAL = NUMTODSINTERVAL(?, 'MINUTE'),
                                                                                               RETENTION = NUMTODSINTERVAL(?, 'DAY'),
                                                                                               Con_ID = (SELECT  #{PanoramaConnection.db_version >= '12.1' ? "Con_ID" : "0"} FROM   v$Instance)
                                     WHERE DBID = ?
                                    ",  @sampler_config[:snapshot_cycle], @sampler_config[:snapshot_retention], PanoramaConnection.dbid]
  end

  def do_housekeeping_internal
    snapshots_to_delete = PanoramaConnection.sql_select_all ["SELECT Snap_ID FROM Panorama_Snapshot WHERE DBID = ? AND Begin_Interval_Time < SYSDATE - ?", PanoramaConnection.dbid, @sampler_config[:snapshot_retention]]

    # Delete from tables with columns DBID and SNAP_ID
    snapshots_to_delete.each do |snapshot|
      PanoramaSamplerStructureCheck.tables.each do |table|
        if PanoramaSamplerStructureCheck.has_column?(table[:table_name], 'Snap_ID')
          PanoramaConnection.sql_execute ["DELETE FROM #{@sampler_config[:owner]}.#{table[:table_name]} WHERE DBID = ? AND Snap_ID <= ?", PanoramaConnection.dbid, snapshot.snap_id]
        end
      end
    end
    # Delete from tables without columns DBID and SNAP_ID

  end

  # Run daemon, daeomon returns 1 second before next snapshot timestamp
  def run_ash_daemon_internal(snapshot_time)
    start_delay_from_snapshot = Time.now - snapshot_time
    snapshot_cycle_seconds = @sampler_config[:snapshot_cycle] * 60
    if start_delay_from_snapshot > 30                                           # ASH-daemon starts more than 30 seconds after snapshot due to structure-check before
      snapshot_cycle_seconds -= start_delay_from_snapshot.to_i - 30             # Limit delay so that ASH-daemon terminates max. 30 seconds after next snapshot
    end
    next_snapshot_start_seconds = @sampler_config[:snapshot_cycle] * 60 - start_delay_from_snapshot # Number of seconds until next snapshot start
    PanoramaConnection.sql_execute [" BEGIN #{@sampler_config[:owner]}.Panorama_Sampler_ASH.Run_Sampler_Daemon(?, ?, ?, ?); END;",
                                    snapshot_cycle_seconds, PanoramaConnection.instance_number, PanoramaConnection.con_id, next_snapshot_start_seconds]
  end

  private
  def con_dbid
    PanoramaConnection.dbid
  end

end