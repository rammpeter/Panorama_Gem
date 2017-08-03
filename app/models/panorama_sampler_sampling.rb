class PanoramaSamplerSampling

  include ExceptionHelper


  def self.do_sampling(sampler_config)
    PanoramaSamplerSampling.new(sampler_config).do_sampling_internal
  end

  def self.do_housekeeping(sampler_config)
    PanoramaSamplerSampling.new(sampler_config).do_housekeeping_internal
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

    ## TODO: Con_DBID mit realen werten des Containers füllen, falls PDB-übergreifendes Sampling gewünscht wird

    ## DBA_Hist_Snapshot
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config[:owner]}.Panorama_Snapshot (Snap_ID, DBID, Instance_Number, Begin_Interval_Time, End_Interval_Time#{", Con_ID" if PanoramaConnection.db_version >= '12.1'}
                                    ) VALUES (?, ?, ?, ?, SYSDATE#{", ?" if PanoramaConnection.db_version >= '12.1'})",
                                    @snap_id, PanoramaConnection.dbid, PanoramaConnection.instance_number, begin_interval_time].concat(PanoramaConnection.db_version >= '12.1' ? [0] : [])

    ## DBA_Hist_Log
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config[:owner]}.Panorama_Log (Snap_ID, DBID, Instance_Number, Group#, Thread#, Sequence#, Bytes, Members, Archived, Status, First_Change#, First_Time,
                                                                                          Con_DBID #{", Con_ID" if PanoramaConnection.db_version >= '12.1'}
                                    ) SELECT ?, ?, ?,
                                             Group#, Thread#, Sequence#, Bytes, Members, Archived, Status, First_Change#, First_Time,
                                             ? #{PanoramaConnection.db_version >= '12.1' ? ", Con_ID" : ", 0"}
                                      FROM   v$Log
                                    ",  @snap_id, PanoramaConnection.dbid, PanoramaConnection.instance_number, con_dbid]

    ## DBA_Hist_SQLStat
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
                                                                                              OPTIMIZED_PHYSICAL_READS_TOTAL, OPTIMIZED_PHYSICAL_READS_DELTA, CELL_UNCOMPRESSED_BYTES_TOTAL, CELL_UNCOMPRESSED_BYTES_DELTA, IO_OFFLOAD_RETURN_BYTES_TOTAL, IO_OFFLOAD_RETURN_BYTES_DELTA,
                                                                                              BIND_DATA,
                                                                                              Con_DBID #{", Con_ID" if PanoramaConnection.db_version >= '12.1'}
                                    ) SELECT  /*+ INDEX(p, PANORAMA_SQLSTAT_PK) PUSH_PRED(ms) OPT_PARAM('_push_join_predicate' 'TRUE')  */
                                              ?, ?, ?, s.SQL_ID, s.Plan_Hash_Value, s.OPTIMIZER_COST, s.OPTIMIZER_MODE, s.OPTIMIZER_ENV_HASH_VALUE, s.SHARABLE_MEM,
                                              s.LOADED_VERSIONS, s.VERSION_COUNT, s.MODULE, s.ACTION, s.SQL_PROFILE, s.FORCE_MATCHING_SIGNATURE, s.PARSING_SCHEMA_ID, s.PARSING_SCHEMA_NAME, s.PARSING_USER_ID,
                                              s.Fetches,                            s.Fetches                         - NVL(p.Fetches_Total, 0),
                                              s.End_Of_Fetch_Count,                 s.End_Of_Fetch_Count              - NVL(p.End_Of_Fetch_Count_Total,0),
                                              s.Sorts,                              s.Sorts                           - NVL(p.Sorts_Total, 0),
                                              s.Executions,                         s.Executions                      - NVL(p.Executions_Total, 0),
                                              s.PX_Servers_Executions,              s.PX_Servers_Executions           - NVL(p.PX_Servers_Execs_Total, 0),
                                              s.Loads,                              s.Loads                           - NVL(p.Loads_Total, 0),
                                              s.Invalidations,                      s.Invalidations                   - NVL(p.Invalidations_Total, 0),
                                              s.Parse_Calls,                        s.Parse_Calls                     - NVL(p.Parse_Calls_Total, 0),
                                              s.Disk_Reads,                         s.Disk_Reads                      - NVL(p.Disk_Reads_Total, 0),
                                              s.Buffer_Gets,                        s.Buffer_Gets                     - NVL(p.Buffer_Gets_Total, 0),
                                              s.Rows_Processed,                     s.Rows_Processed                  - NVL(p.Rows_Processed_Total, 0),
                                              s.CPU_Time,                           s.CPU_Time                        - NVL(p.CPU_Time_Total, 0),
                                              s.Elapsed_Time,                       s.Elapsed_Time                    - NVL(p.Elapsed_Time_Total, 0),
                                              s.User_IO_Wait_Time,                  s.User_IO_Wait_Time               - NVL(p.IOWait_Total, 0),
                                              s.Cluster_Wait_Time,                  s.Cluster_Wait_Time               - NVL(p.CLWait_Total, 0),
                                              s.Application_Wait_Time,              s.Application_Wait_Time           - NVL(p.ApWait_Total, 0),
                                              s.Concurrency_Wait_Time,              s.Concurrency_Wait_Time           - NVL(p.CCWait_Total, 0),
                                              s.Direct_Writes,                      s.Direct_Writes                   - NVL(p.Direct_Writes_Total, 0),
                                              s.PLSQL_Exec_Time,                    s.PLSQL_Exec_Time                 - NVL(p.PLSExec_Time_Total, 0),
                                              s.Java_Exec_Time,                     s.Java_Exec_Time                  - NVL(p.JavExec_Time_Total, 0),
                                              #{"s.IO_CELL_OFFLOAD_ELIGIBLE_BYTES,  s.IO_CELL_OFFLOAD_ELIGIBLE_BYTES  - NVL(p.IO_OFFLOAD_ELIG_BYTES_Total, 0),"     if PanoramaConnection.db_version >= '12.1'}
                                              #{"s.IO_Interconnect_Bytes,           s.IO_Interconnect_Bytes           - NVL(p.IO_Interconnect_Bytes_Total, 0),"     if PanoramaConnection.db_version >= '12.1'}
                                              s.Physical_Read_Requests,             s.Physical_Read_Requests          - NVL(p.Physical_Read_Requests_Total, 0),
                                              s.Physical_Read_Bytes,                s.Physical_Read_Bytes             - NVL(p.Physical_Read_Bytes_Total, 0),
                                              s.Physical_Write_Requests,            s.Physical_Write_Requests         - NVL(p.Physical_Write_Requests_Total, 0),
                                              s.Physical_Write_Bytes,               s.Physical_Write_Bytes            - NVL(p.Physical_Write_Bytes_Total, 0),
                                              #{"s.Optimized_Phy_Read_Requests,     s.Optimized_Phy_Read_Requests     - NVL(p.Optimized_Physical_Reads_Total, 0),"  if PanoramaConnection.db_version >= '12.1'}
                                              #{"s.IO_Cell_Uncompressed_Bytes,      s.IO_Cell_Uncompressed_Bytes      - NVL(p.Cell_Uncompressed_Bytes_Total, 0),"   if PanoramaConnection.db_version >= '12.1'}
                                              #{"s.IO_Cell_Offload_Returned_Bytes,  s.IO_Cell_Offload_Returned_Bytes  - NVL(p.IO_Offload_Return_Bytes_Total, 0),"   if PanoramaConnection.db_version >= '12.2'}
                                              s.Bind_Data,
                                              ? #{PanoramaConnection.db_version >= '12.1' ? ", s.Con_ID" : ", 0"}
                                      FROM   --v$SQLArea s
                                             (SELECT SQL_ID, Plan_Hash_Value, #{"Con_ID, " if PanoramaConnection.db_version >= '12.1' } MAX(Optimizer_Cost) Optimizer_Cost, MAX(Optimizer_Mode) Optimizer_Mode, MAX(Optimizer_Env_Hash_Value) Optimizer_Env_Hash_Value,
                                                     SUM(SHARABLE_MEM) SHARABLE_MEM, SUM(LOADED_VERSIONS) LOADED_VERSIONS, COUNT(*) VERSION_COUNT, MAX(Module) Module, MAX(Action) Action, MAX(SQL_PROFILE) SQL_PROFILE, MAX(FORCE_MATCHING_SIGNATURE) FORCE_MATCHING_SIGNATURE,
                                                     MAX(PARSING_SCHEMA_ID) PARSING_SCHEMA_ID, MAX(PARSING_SCHEMA_NAME) PARSING_SCHEMA_NAME, MAX(PARSING_USER_ID) PARSING_USER_ID,
                                                     SUM(Fetches) Fetches, SUM(End_Of_Fetch_Count) End_Of_Fetch_Count, SUM(Sorts) Sorts, SUM(Executions) Executions, SUM(PX_Servers_Executions) PX_Servers_Executions, SUM(Loads) Loads, SUM(Invalidations) Invalidations,
                                                     SUM(Parse_Calls) Parse_Calls, SUM(Disk_Reads) Disk_Reads, SUM(Buffer_Gets) Buffer_Gets, SUM(Rows_Processed) Rows_Processed, SUM(CPU_Time) CPU_Time, SUM(Elapsed_Time) Elapsed_Time, SUM(User_IO_Wait_Time) User_IO_Wait_Time,
                                                     SUM(Cluster_Wait_Time) Cluster_Wait_Time, SUM(Application_Wait_Time) Application_Wait_Time, SUM(Concurrency_Wait_Time) Concurrency_Wait_Time, SUM(Direct_Writes) Direct_Writes, SUM(PLSQL_Exec_Time) PLSQL_Exec_Time, SUM(Java_Exec_Time) Java_Exec_Time,
                                                     #{"SUM(IO_CELL_OFFLOAD_ELIGIBLE_BYTES) IO_CELL_OFFLOAD_ELIGIBLE_BYTES, SUM(IO_Interconnect_Bytes) IO_Interconnect_Bytes," if PanoramaConnection.db_version >= '12.1'}
                                                     SUM(Physical_Read_Requests) Physical_Read_Requests, SUM(Physical_Read_Bytes) Physical_Read_Bytes, SUM(Physical_Write_Requests) Physical_Write_Requests, SUM(Physical_Write_Bytes) Physical_Write_Bytes,
                                                     #{"SUM(Optimized_Phy_Read_Requests) Optimized_Phy_Read_Requests, SUM(IO_Cell_Uncompressed_Bytes) IO_Cell_Uncompressed_Bytes,"  if PanoramaConnection.db_version >= '12.1'}
                                                     #{"SUM(IO_Cell_Offload_Returned_Bytes) IO_Cell_Offload_Returned_Bytes,"  if PanoramaConnection.db_version >= '12.2'}
                                                     MAX(Bind_Data) Bind_Data, MAX(Last_Active_Time) Last_Active_Time
                                              FROM   v$SQL
                                              GROUP BY SQL_ID, Plan_Hash_Value #{", Con_ID" if PanoramaConnection.db_version >= '12.1' }
                                              --WHERE
                                             ) s
                                      LEFT OUTER JOIN  (SELECT MAX(Snap_ID) Max_Snap_ID, DBID, Instance_Number, SQL_ID, Plan_Hash_Value, Con_DBID
                                                        FROM   Panorama_SQLStat
                                                        GROUP BY DBID, Instance_Number, SQL_ID, Plan_Hash_Value, Con_DBID
                                                       ) ms ON ms.DBID=? AND ms.Instance_Number=? AND ms.SQL_ID=s.SQL_ID AND ms.Plan_Hash_Value=s.Plan_Hash_Value AND ms.Con_DBID=?
                                      LEFT OUTER JOIN Panorama_SQLStat p ON  p.DBID=? AND p.Snap_ID=ms.Max_Snap_ID AND p.Instance_Number=? AND p.SQL_ID=s.SQL_ID AND p.Plan_Hash_Value=s.Plan_Hash_Value AND p.Con_DBID=?
                                      WHERE s.Last_Active_Time > ?
                                    ",  @snap_id, PanoramaConnection.dbid, PanoramaConnection.instance_number, con_dbid, PanoramaConnection.dbid, PanoramaConnection.instance_number, con_dbid, PanoramaConnection.dbid,  PanoramaConnection.instance_number, con_dbid, begin_interval_time]

    ## DBA_Hist_SQLText
    PanoramaConnection.sql_execute ["INSERT INTO #{@sampler_config[:owner]}.Panorama_SQLText (DBID, SQL_ID, SQL_Text, Command_Type, Con_DBID, Con_ID)
                                      SELECT ?, s.SQL_ID, s.SQL_FullText, s.Command_Type,
                                              ? #{PanoramaConnection.db_version >= '12.1' ? ", s.Con_ID" : ", 0"}
                                      FROM   v$SQLArea s
                                      LEFT OUTER JOIN Panorama_SQLText p ON p.DBID=? AND p.SQL_ID=s.SQL_ID AND p.Con_DBID=?
                                      WHERE p.SQL_ID IS NULL
                                    ",  PanoramaConnection.dbid, con_dbid, PanoramaConnection.dbid, con_dbid]

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


  private
  def con_dbid
    PanoramaConnection.dbid
  end

end