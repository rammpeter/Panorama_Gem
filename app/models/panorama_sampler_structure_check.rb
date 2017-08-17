class PanoramaSamplerStructureCheck
  include ExceptionHelper
  include PanoramaSampler::PackagePanoramaSamplerAsh
  include PanoramaSampler::PackagePanoramaSamplerSnapshot

  def self.do_check(sampler_config, only_ash_tables)
    PanoramaSamplerStructureCheck.new(sampler_config).do_check_internal(only_ash_tables)
  end

  def self.remove_tables(sampler_config)
    PanoramaSamplerStructureCheck.new(sampler_config).remove_tables_internal
  end

  def self.tables
    @@tables
  end

  # Schemas with valid Panorama-Sampler structures for start
  def self.panorama_sampler_schemas
    PanoramaConnection.sql_select_all "SELECT Owner
                                       FROM   All_Tab_Columns
                                       WHERE  Table_Name IN ('PANORAMA_SNAPSHOT', 'PANORAMA_WR_CONTROL')
                                       AND    Column_Name IN ('SNAP_ID', 'DBID', 'INSTANCE_NUMBER', 'BEGIN_INTERVAL_TIME', 'END_INTERVAL_TIME',
                                                              'SNAP_INTERVAL', 'RETENTION')
                                       GROUP BY Owner
                                       HAVING COUNT(*) = 8 /* DBID exists in both tables */
                                      "
  end

  def initialize(sampler_config)
    @sampler_config = sampler_config
  end

  def log(message)
    Rails.logger.info "PanoramaSamplerStructureCheck: #{message} for config ID=#{@sampler_config[:id]} (#{@sampler_config[:name]}) "
  end

=begin
  Expexted structure, should contain structure of highest Oracle version:
  [
      {
        table_name: ,
        columns: [
            {
              column_name:
              column_type:
              not_null:
              precision:
              scale:
            }
        ],
        primary_key: ['col1', 'col2']
      }
  ]
=end
  @@tables = [
      {
          table_name: 'Internal_V$Active_Sess_History',
          columns: [
              { column_name:  'Instance_Number',                column_type:  'NUMBER',     not_null: true  },
              { column_name:  'SAMPLE_ID',                      column_type:  'NUMBER',     not_null: true },
              { column_name:  'SAMPLE_TIME',                    column_type:  'TIMESTAMP',  not_null: true, precision: 3 },
              { column_name:  'IS_AWR_SAMPLE',                  column_type:  'VARCHAR2',   precision: 1 },
              { column_name:  'SESSION_ID',                     column_type:  'NUMBER',     not_null: true },
              { column_name:  'SESSION_SERIAL#',                column_type:  'NUMBER' },
              { column_name:  'SESSION_TYPE',                   column_type:  'VARCHAR2',  precision: 10 },
              { column_name:  'FLAGS',                          column_type:  'NUMBER' },
              { column_name:  'USER_ID',                        column_type:  'NUMBER' },
              { column_name:  'SQL_ID',                         column_type:  'VARCHAR2', precision: 13 },
              { column_name:  'IS_SQLID_CURRENT',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'SQL_CHILD_NUMBER',               column_type:  'NUMBER' },
              { column_name:  'SQL_OPCODE',                     column_type:  'NUMBER' },
              { column_name:  'SQL_OPNAME',                     column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'FORCE_MATCHING_SIGNATURE',       column_type:  'NUMBER' },
              { column_name:  'TOP_LEVEL_SQL_ID',               column_type:  'VARCHAR2', precision: 13 },
              { column_name:  'TOP_LEVEL_SQL_OPCODE',           column_type:  'NUMBER' },
              #{ column_name:  'SQL_ADAPTIVE_PLAN_RESOLVED',     column_type:  'NUMBER' },
              #{ column_name:  'SQL_FULL_PLAN_HASH_VALUE',       column_type:  'NUMBER' },
              { column_name:  'SQL_PLAN_HASH_VALUE',            column_type:  'NUMBER' },
              { column_name:  'SQL_PLAN_LINE_ID',               column_type:  'NUMBER' },
              { column_name:  'SQL_PLAN_OPERATION',             column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'SQL_PLAN_OPTIONS',               column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'SQL_EXEC_ID',                    column_type:  'NUMBER' },
              { column_name:  'SQL_EXEC_START',                 column_type:  'DATE' },
              { column_name:  'PLSQL_ENTRY_OBJECT_ID',          column_type:  'NUMBER' },
              { column_name:  'PLSQL_ENTRY_SUBPROGRAM_ID',      column_type:  'NUMBER' },
              { column_name:  'PLSQL_OBJECT_ID',                column_type:  'NUMBER' },
              { column_name:  'PLSQL_SUBPROGRAM_ID',            column_type:  'NUMBER' },
              { column_name:  'QC_INSTANCE_ID',                 column_type:  'NUMBER' },
              { column_name:  'QC_SESSION_ID',                  column_type:  'NUMBER' },
              { column_name:  'QC_SESSION_SERIAL#',             column_type:  'NUMBER' },
              { column_name:  'PX_FLAGS',                       column_type:  'NUMBER' },
              { column_name:  'EVENT',                          column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'EVENT_ID',                       column_type:  'NUMBER' },
              #{ column_name:  'EVENT#',                         column_type:  'NUMBER' },
              { column_name:  'SEQ#',                           column_type:  'NUMBER' },
              { column_name:  'P1TEXT',                         column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'P1',                             column_type:  'NUMBER' },
              { column_name:  'P2TEXT',                         column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'P2',                             column_type:  'NUMBER' },
              { column_name:  'P3TEXT',                         column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'P3',                             column_type:  'NUMBER' },
              { column_name:  'WAIT_CLASS',                     column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'WAIT_CLASS_ID',                  column_type:  'NUMBER' },
              { column_name:  'WAIT_TIME',                      column_type:  'NUMBER' },
              { column_name:  'SESSION_STATE',                  column_type:  'VARCHAR2', precision: 7 },
              { column_name:  'TIME_WAITED',                    column_type:  'NUMBER' },
              { column_name:  'BLOCKING_SESSION_STATUS',        column_type:  'VARCHAR2', precision: 11 },
              { column_name:  'BLOCKING_SESSION',               column_type:  'NUMBER' },
              { column_name:  'BLOCKING_SESSION_SERIAL#',       column_type:  'NUMBER' },
              { column_name:  'BLOCKING_INST_ID',               column_type:  'NUMBER' },
              { column_name:  'BLOCKING_HANGCHAIN_INFO',        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'CURRENT_OBJ#',                   column_type:  'NUMBER' },
              { column_name:  'CURRENT_FILE#',                  column_type:  'NUMBER' },
              { column_name:  'CURRENT_BLOCK#',                 column_type:  'NUMBER' },
              { column_name:  'CURRENT_ROW#',                   column_type:  'NUMBER' },
              { column_name:  'TOP_LEVEL_CALL#',                column_type:  'NUMBER' },
              { column_name:  'CONSUMER_GROUP_ID',              column_type:  'NUMBER' },
              { column_name:  'XID',                            column_type:  'RAW', precision: 8 },
              { column_name:  'REMOTE_INSTANCE#',               column_type:  'NUMBER' },
              { column_name:  'TIME_MODEL',                     column_type:  'NUMBER' },
              { column_name:  'IN_CONNECTION_MGMT',             column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PARSE',                       column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_HARD_PARSE',                  column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_SQL_EXECUTION',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PLSQL_EXECUTION',             column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PLSQL_RPC',                   column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PLSQL_COMPILATION',           column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_JAVA_EXECUTION',              column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_BIND',                        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_CURSOR_CLOSE',                column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_SEQUENCE_LOAD',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_QUERY',              column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_POPULATE',           column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_PREPOPULATE',        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_REPOPULATE',         column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_TREPOPULATE',        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_TABLESPACE_ENCRYPTION',       column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'CAPTURE_OVERHEAD',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'REPLAY_OVERHEAD',                column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IS_CAPTURED',                    column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IS_REPLAYED',                    column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'SERVICE_HASH',                   column_type:  'NUMBER' },
              { column_name:  'PROGRAM',                        column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'MODULE',                         column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'ACTION',                         column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'CLIENT_ID',                      column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'MACHINE',                        column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'PORT',                           column_type:  'NUMBER' },
              { column_name:  'ECID',                           column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'DBREPLAY_FILE_ID',               column_type:  'NUMBER' },
              { column_name:  'DBREPLAY_CALL_COUNTER',          column_type:  'NUMBER' },
              { column_name:  'TM_DELTA_TIME',                  column_type:  'NUMBER' },
              { column_name:  'TM_DELTA_CPU_TIME',              column_type:  'NUMBER' },
              { column_name:  'TM_DELTA_DB_TIME',               column_type:  'NUMBER' },
              { column_name:  'DELTA_TIME',                     column_type:  'NUMBER' },
              { column_name:  'DELTA_READ_IO_REQUESTS',         column_type:  'NUMBER' },
              { column_name:  'DELTA_WRITE_IO_REQUESTS',        column_type:  'NUMBER' },
              { column_name:  'DELTA_READ_IO_BYTES',            column_type:  'NUMBER' },
              { column_name:  'DELTA_WRITE_IO_BYTES',           column_type:  'NUMBER' },
              { column_name:  'DELTA_INTERCONNECT_IO_BYTES',    column_type:  'NUMBER' },
              { column_name:  'PGA_ALLOCATED',                  column_type:  'NUMBER' },
              { column_name:  'TEMP_SPACE_ALLOCATED',           column_type:  'NUMBER' },
              { column_name:  'Con_ID',                         column_type:  'NUMBER', not_null: true  },
              #{ column_name:  'DBOP_NAME',                      column_type:  'VARCHAR2', precision: 30 },
              #{ column_name:  'DBOP_EXEC_ID',                   column_type:  'NUMBER' },
          ],
          primary_key: ['INSTANCE_NUMBER', 'SAMPLE_ID', 'SESSION_ID'],    # ensure that copying data into Panorama_Active_Sess_History does never rails PK-violation
      },
      {
          table_name: 'Internal_Active_Sess_History',
          columns: [
              { column_name:  'Snap_ID',                        column_type:  'NUMBER',     not_null: true },
              { column_name:  'DBID',                           column_type:  'NUMBER',     not_null: true },
              { column_name:  'Instance_Number',                column_type:  'NUMBER',     not_null: true  },
              { column_name:  'SAMPLE_ID',                      column_type:  'NUMBER',     not_null: true },
              { column_name:  'SAMPLE_TIME',                    column_type:  'TIMESTAMP',  not_null: true, precision: 3 },
              { column_name:  'SESSION_ID',                     column_type:  'NUMBER',     not_null: true },
              { column_name:  'SESSION_SERIAL#',                column_type:  'NUMBER' },
              { column_name:  'SESSION_TYPE',                   column_type:  'VARCHAR2',  precision: 10 },
              { column_name:  'FLAGS',                          column_type:  'NUMBER' },
              { column_name:  'USER_ID',                        column_type:  'NUMBER' },
              { column_name:  'SQL_ID',                         column_type:  'VARCHAR2', precision: 13 },
              { column_name:  'IS_SQLID_CURRENT',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'SQL_CHILD_NUMBER',               column_type:  'NUMBER' },
              { column_name:  'SQL_OPCODE',                     column_type:  'NUMBER' },
              { column_name:  'SQL_OPNAME',                     column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'FORCE_MATCHING_SIGNATURE',       column_type:  'NUMBER' },
              { column_name:  'TOP_LEVEL_SQL_ID',               column_type:  'VARCHAR2', precision: 13 },
              { column_name:  'TOP_LEVEL_SQL_OPCODE',           column_type:  'NUMBER' },
              { column_name:  'SQL_PLAN_HASH_VALUE',            column_type:  'NUMBER' },
              { column_name:  'SQL_PLAN_LINE_ID',               column_type:  'NUMBER' },
              { column_name:  'SQL_PLAN_OPERATION',             column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'SQL_PLAN_OPTIONS',               column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'SQL_EXEC_ID',                    column_type:  'NUMBER' },
              { column_name:  'SQL_EXEC_START',                 column_type:  'DATE' },
              { column_name:  'PLSQL_ENTRY_OBJECT_ID',          column_type:  'NUMBER' },
              { column_name:  'PLSQL_ENTRY_SUBPROGRAM_ID',      column_type:  'NUMBER' },
              { column_name:  'PLSQL_OBJECT_ID',                column_type:  'NUMBER' },
              { column_name:  'PLSQL_SUBPROGRAM_ID',            column_type:  'NUMBER' },
              { column_name:  'QC_INSTANCE_ID',                 column_type:  'NUMBER' },
              { column_name:  'QC_SESSION_ID',                  column_type:  'NUMBER' },
              { column_name:  'QC_SESSION_SERIAL#',             column_type:  'NUMBER' },
              { column_name:  'PX_FLAGS',                       column_type:  'NUMBER' },
              { column_name:  'EVENT',                          column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'EVENT_ID',                       column_type:  'NUMBER' },
              { column_name:  'SEQ#',                           column_type:  'NUMBER' },
              { column_name:  'P1TEXT',                         column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'P1',                             column_type:  'NUMBER' },
              { column_name:  'P2TEXT',                         column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'P2',                             column_type:  'NUMBER' },
              { column_name:  'P3TEXT',                         column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'P3',                             column_type:  'NUMBER' },
              { column_name:  'WAIT_CLASS',                     column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'WAIT_CLASS_ID',                  column_type:  'NUMBER' },
              { column_name:  'WAIT_TIME',                      column_type:  'NUMBER' },
              { column_name:  'SESSION_STATE',                  column_type:  'VARCHAR2', precision: 7 },
              { column_name:  'TIME_WAITED',                    column_type:  'NUMBER' },
              { column_name:  'BLOCKING_SESSION_STATUS',        column_type:  'VARCHAR2', precision: 11 },
              { column_name:  'BLOCKING_SESSION',               column_type:  'NUMBER' },
              { column_name:  'BLOCKING_SESSION_SERIAL#',       column_type:  'NUMBER' },
              { column_name:  'BLOCKING_INST_ID',               column_type:  'NUMBER' },
              { column_name:  'BLOCKING_HANGCHAIN_INFO',        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'CURRENT_OBJ#',                   column_type:  'NUMBER' },
              { column_name:  'CURRENT_FILE#',                  column_type:  'NUMBER' },
              { column_name:  'CURRENT_BLOCK#',                 column_type:  'NUMBER' },
              { column_name:  'CURRENT_ROW#',                   column_type:  'NUMBER' },
              { column_name:  'TOP_LEVEL_CALL#',                column_type:  'NUMBER' },
              { column_name:  'CONSUMER_GROUP_ID',              column_type:  'NUMBER' },
              { column_name:  'XID',                            column_type:  'RAW', precision: 8 },
              { column_name:  'REMOTE_INSTANCE#',               column_type:  'NUMBER' },
              { column_name:  'TIME_MODEL',                     column_type:  'NUMBER' },
              { column_name:  'IN_CONNECTION_MGMT',             column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PARSE',                       column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_HARD_PARSE',                  column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_SQL_EXECUTION',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PLSQL_EXECUTION',             column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PLSQL_RPC',                   column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_PLSQL_COMPILATION',           column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_JAVA_EXECUTION',              column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_BIND',                        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_CURSOR_CLOSE',                column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_SEQUENCE_LOAD',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_QUERY',              column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_POPULATE',           column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_PREPOPULATE',        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_REPOPULATE',         column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_INMEMORY_TREPOPULATE',        column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IN_TABLESPACE_ENCRYPTION',       column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'CAPTURE_OVERHEAD',               column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'REPLAY_OVERHEAD',                column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IS_CAPTURED',                    column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'IS_REPLAYED',                    column_type:  'VARCHAR2', precision: 1 },
              { column_name:  'SERVICE_HASH',                   column_type:  'NUMBER' },
              { column_name:  'PROGRAM',                        column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'MODULE',                         column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'ACTION',                         column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'CLIENT_ID',                      column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'MACHINE',                        column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'PORT',                           column_type:  'NUMBER' },
              { column_name:  'ECID',                           column_type:  'VARCHAR2', precision: 64 },
              { column_name:  'DBREPLAY_FILE_ID',               column_type:  'NUMBER' },
              { column_name:  'DBREPLAY_CALL_COUNTER',          column_type:  'NUMBER' },
              { column_name:  'TM_DELTA_TIME',                  column_type:  'NUMBER' },
              { column_name:  'TM_DELTA_CPU_TIME',              column_type:  'NUMBER' },
              { column_name:  'TM_DELTA_DB_TIME',               column_type:  'NUMBER' },
              { column_name:  'DELTA_TIME',                     column_type:  'NUMBER' },
              { column_name:  'DELTA_READ_IO_REQUESTS',         column_type:  'NUMBER' },
              { column_name:  'DELTA_WRITE_IO_REQUESTS',        column_type:  'NUMBER' },
              { column_name:  'DELTA_READ_IO_BYTES',            column_type:  'NUMBER' },
              { column_name:  'DELTA_WRITE_IO_BYTES',           column_type:  'NUMBER' },
              { column_name:  'DELTA_INTERCONNECT_IO_BYTES',    column_type:  'NUMBER' },
              { column_name:  'PGA_ALLOCATED',                  column_type:  'NUMBER' },
              { column_name:  'TEMP_SPACE_ALLOCATED',           column_type:  'NUMBER' },
              { column_name:  'Con_DBID',                       column_type:  'NUMBER',     not_null: true },
              { column_name:  'Con_ID',                         column_type:  'NUMBER',     not_null: true },
          ],
          primary_key: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'SAMPLE_ID', 'SESSION_ID', 'Con_DBID'],
      },
      {
          table_name: 'Panorama_DB_Cache_Advice',
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'BPID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'BUFFERS_FOR_ESTIMATE',           column_type:   'NUMBER',    not_null: true },
              { column_name:  'NAME',                           column_type:   'VARCHAR2',  precision: 20 },
              { column_name:  'BLOCK_SIZE',                     column_type:   'NUMBER' },
              { column_name:  'ADVICE_STATUS',                  column_type:   'VARCHAR2',  precision: 3 },
              { column_name:  'SIZE_FOR_ESTIMATE',              column_type:   'NUMBER' },
              { column_name:  'SIZE_FACTOR',                    column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READS',                 column_type:   'NUMBER' },
              { column_name:  'BASE_PHYSICAL_READS',            column_type:   'NUMBER' },
              { column_name:  'ACTUAL_PHYSICAL_READS',          column_type:   'NUMBER' },
              { column_name:  'ESTD_PHYSICAL_READ_TIME',        column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER', not_null: true  },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'BPID', 'BUFFERS_FOR_ESTIMATE', 'CON_DBID'],
      },
      {
          table_name: 'Panorama_Log',
          columns: [
              { column_name:  'Snap_ID',                        column_type:  'NUMBER',     not_null: true },
              { column_name:  'DBID',                           column_type:  'NUMBER',     not_null: true },
              { column_name:  'Instance_Number',                column_type:  'NUMBER',     not_null: true },
              { column_name:  'Group#',                         column_type:  'NUMBER',     not_null: true },
              { column_name:  'Thread#',                        column_type:  'NUMBER',     not_null: true },
              { column_name:  'Sequence#',                      column_type:  'NUMBER',     not_null: true },
              { column_name:  'Bytes',                          column_type:  'NUMBER' },
              { column_name:  'Members',                        column_type:  'NUMBER' },
              { column_name:  'Archived',                       column_type:  'VARCHAR2', precision: 3 },
              { column_name:  'Status',                         column_type:  'VARCHAR2', precision: 16 },
              { column_name:  'First_Change#',                  column_type:  'NUMBER' },
              { column_name:  'First_Time',                     column_type:  'DATE' },
              { column_name:  'Con_DBID',                       column_type:  'NUMBER',     not_null: true  },
              { column_name:  'Con_ID',                         column_type:  'NUMBER' },
          ],
          primary_key: ['DBID', 'Snap_ID', 'Instance_Number', 'Group#', 'Thread#', 'Sequence#', 'Con_DBID']
      },
      {
          table_name: 'Panorama_Service_Name',
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'SERVICE_NAME_HASH',              column_type:   'NUMBER',    not_null: true },
              { column_name:  'SERVICE_NAME',                   column_type:   'VARCHAR2',  not_null: true, precision: 64 },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER',    not_null: true },
          ],
          primary_key: ['DBID', 'Service_Name', 'Con_DBID'],
      },
      {
          table_name: 'Panorama_Snapshot',
          columns: [
              { column_name:  'Snap_ID',                        column_type:  'NUMBER',     not_null: true },
              { column_name:  'DBID',                           column_type:  'NUMBER',     not_null: true },
              { column_name:  'Instance_Number',                column_type:  'NUMBER',     not_null: true  },
              { column_name:  'Begin_Interval_Time',            column_type:  'TIMESTAMP',  not_null: true, precision: 3  },
              { column_name:  'End_Interval_Time',              column_type:  'TIMESTAMP',  not_null: true, precision: 3  },
              { column_name:  'Con_ID',                         column_type:  'NUMBER' },
          ],
          primary_key: ['DBID', 'Snap_ID', 'Instance_Number'],
          indexes: [ {index_name: 'Panorama_Snapshot_MaxID_IX', columns: ['DBID', 'Instance_Number'] } ]
      },
      {
          table_name: 'Panorama_SQLStat',
          columns: [
              { column_name:  'SNAP_ID',                        column_type:   'NUMBER',    not_null: true },
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'INSTANCE_NUMBER',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'SQL_ID',                         column_type:   'VARCHAR2',  not_null: true, precision: 13 },
              { column_name:  'PLAN_HASH_VALUE',                column_type:   'NUMBER',    not_null: true },
              { column_name:  'OPTIMIZER_COST',                 column_type:   'NUMBER' },
              { column_name:  'OPTIMIZER_MODE',                 column_type:   'VARCHAR2',  precision: 10 },
              { column_name:  'OPTIMIZER_ENV_HASH_VALUE',       column_type:   'NUMBER' },
              { column_name:  'SHARABLE_MEM',                   column_type:   'NUMBER' },
              { column_name:  'LOADED_VERSIONS',                column_type:   'NUMBER' },
              { column_name:  'VERSION_COUNT',                  column_type:   'NUMBER' },
              { column_name:  'MODULE',                         column_type:   'VARCHAR2',  precision: 64 },
              { column_name:  'ACTION',                         column_type:   'VARCHAR2',  precision: 64 },
              { column_name:  'SQL_PROFILE',                    column_type:   'VARCHAR2',  precision: 64 },
              { column_name:  'FORCE_MATCHING_SIGNATURE',       column_type:   'NUMBER' },
              { column_name:  'PARSING_SCHEMA_ID',              column_type:   'NUMBER' },
              { column_name:  'PARSING_SCHEMA_NAME',            column_type:   'VARCHAR2',  precision: 128 },
              { column_name:  'PARSING_USER_ID',                column_type:   'NUMBER' },
              { column_name:  'FETCHES_TOTAL',                  column_type:   'NUMBER' },
              { column_name:  'FETCHES_DELTA',                  column_type:   'NUMBER' },
              { column_name:  'END_OF_FETCH_COUNT_TOTAL',       column_type:   'NUMBER' },
              { column_name:  'END_OF_FETCH_COUNT_DELTA',       column_type:   'NUMBER' },
              { column_name:  'SORTS_TOTAL',                    column_type:   'NUMBER' },
              { column_name:  'SORTS_DELTA',                    column_type:   'NUMBER' },
              { column_name:  'EXECUTIONS_TOTAL',               column_type:   'NUMBER' },
              { column_name:  'EXECUTIONS_DELTA',               column_type:   'NUMBER' },
              { column_name:  'PX_SERVERS_EXECS_TOTAL',         column_type:   'NUMBER' },
              { column_name:  'PX_SERVERS_EXECS_DELTA',         column_type:   'NUMBER' },
              { column_name:  'LOADS_TOTAL',                    column_type:   'NUMBER' },
              { column_name:  'LOADS_DELTA',                    column_type:   'NUMBER' },
              { column_name:  'INVALIDATIONS_TOTAL',            column_type:   'NUMBER' },
              { column_name:  'INVALIDATIONS_DELTA',            column_type:   'NUMBER' },
              { column_name:  'PARSE_CALLS_TOTAL',              column_type:   'NUMBER' },
              { column_name:  'PARSE_CALLS_DELTA',              column_type:   'NUMBER' },
              { column_name:  'DISK_READS_TOTAL',               column_type:   'NUMBER' },
              { column_name:  'DISK_READS_DELTA',               column_type:   'NUMBER' },
              { column_name:  'BUFFER_GETS_TOTAL',              column_type:   'NUMBER' },
              { column_name:  'BUFFER_GETS_DELTA',              column_type:   'NUMBER' },
              { column_name:  'ROWS_PROCESSED_TOTAL',           column_type:   'NUMBER' },
              { column_name:  'ROWS_PROCESSED_DELTA',           column_type:   'NUMBER' },
              { column_name:  'CPU_TIME_TOTAL',                 column_type:   'NUMBER' },
              { column_name:  'CPU_TIME_DELTA',                 column_type:   'NUMBER' },
              { column_name:  'ELAPSED_TIME_TOTAL',             column_type:   'NUMBER' },
              { column_name:  'ELAPSED_TIME_DELTA',             column_type:   'NUMBER' },
              { column_name:  'IOWAIT_TOTAL',                   column_type:   'NUMBER' },
              { column_name:  'IOWAIT_DELTA',                   column_type:   'NUMBER' },
              { column_name:  'CLWAIT_TOTAL',                   column_type:   'NUMBER' },
              { column_name:  'CLWAIT_DELTA',                   column_type:   'NUMBER' },
              { column_name:  'APWAIT_TOTAL',                   column_type:   'NUMBER' },
              { column_name:  'APWAIT_DELTA',                   column_type:   'NUMBER' },
              { column_name:  'CCWAIT_TOTAL',                   column_type:   'NUMBER' },
              { column_name:  'CCWAIT_DELTA',                   column_type:   'NUMBER' },
              { column_name:  'DIRECT_WRITES_TOTAL',            column_type:   'NUMBER' },
              { column_name:  'DIRECT_WRITES_DELTA',            column_type:   'NUMBER' },
              { column_name:  'PLSEXEC_TIME_TOTAL',             column_type:   'NUMBER' },
              { column_name:  'PLSEXEC_TIME_DELTA',             column_type:   'NUMBER' },
              { column_name:  'JAVEXEC_TIME_TOTAL',             column_type:   'NUMBER' },
              { column_name:  'JAVEXEC_TIME_DELTA',             column_type:   'NUMBER' },
              { column_name:  'IO_OFFLOAD_ELIG_BYTES_TOTAL',    column_type:   'NUMBER' },
              { column_name:  'IO_OFFLOAD_ELIG_BYTES_DELTA',    column_type:   'NUMBER' },
              { column_name:  'IO_INTERCONNECT_BYTES_TOTAL',    column_type:   'NUMBER' },
              { column_name:  'IO_INTERCONNECT_BYTES_DELTA',    column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READ_REQUESTS_TOTAL',   column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READ_REQUESTS_DELTA',   column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READ_BYTES_TOTAL',      column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_READ_BYTES_DELTA',      column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITE_REQUESTS_TOTAL',  column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITE_REQUESTS_DELTA',  column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITE_BYTES_TOTAL',     column_type:   'NUMBER' },
              { column_name:  'PHYSICAL_WRITE_BYTES_DELTA',     column_type:   'NUMBER' },
              { column_name:  'OPTIMIZED_PHYSICAL_READS_TOTAL', column_type:   'NUMBER' },
              { column_name:  'OPTIMIZED_PHYSICAL_READS_DELTA', column_type:   'NUMBER' },
              { column_name:  'CELL_UNCOMPRESSED_BYTES_TOTAL',  column_type:   'NUMBER' },
              { column_name:  'CELL_UNCOMPRESSED_BYTES_DELTA',  column_type:   'NUMBER' },
              { column_name:  'IO_OFFLOAD_RETURN_BYTES_TOTAL',  column_type:   'NUMBER' },
              { column_name:  'IO_OFFLOAD_RETURN_BYTES_DELTA',  column_type:   'NUMBER' },
              { column_name:  'BIND_DATA',                      column_type:   'RAW',       precision: 2000 },
              { column_name:  'FLAG',                           column_type:   'NUMBER' },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'SQL_ID', 'PLAN_HASH_VALUE', 'CON_DBID'],
          indexes: [ {index_name: 'Panorama_SQLStat_SQLID_IX', columns: ['SQL_ID', 'DBID', 'CON_DBID'] } ]
      },
      {
          table_name: 'Panorama_SQLText',
          columns: [
              { column_name:  'DBID',                           column_type:  'NUMBER',     not_null: true },
              { column_name:  'SQL_ID',                         column_type:  'VARCHAR2',   not_null: true, precision: 13  },
              { column_name:  'SQL_Text',                       column_type:  'CLOB'    },
              { column_name:  'Command_Type',                   column_type:  'NUMBER'    },
              { column_name:  'CON_DBID',                       column_type:  'NUMBER',     not_null: true },
              { column_name:  'Con_ID',                         column_type:  'NUMBER' },
          ],
          primary_key: ['DBID', 'SQL_ID', 'Con_DBID'],
      },
      {
          table_name: 'Panorama_TopLevelCall_Name',
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',    not_null: true },
              { column_name:  'Top_Level_Call#',                column_type:   'NUMBER',    not_null: true},
              { column_name:  'Top_Level_Call_Name',            column_type:   'VARCHAR2',  precision: 64 },
              { column_name:  'CON_DBID',                       column_type:   'NUMBER',    not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER',    not_null: true },
          ],
          primary_key: ['DBID', 'Top_Level_Call#', 'Con_DBID'],
      },
      {
          table_name: 'Panorama_WR_Control',
          columns: [
              { column_name:  'DBID',                           column_type:   'NUMBER',                        not_null: true },
              { column_name:  'SNAP_INTERVAL',                  column_type:   'INTERVAL DAY(5) TO SECOND(1)',  not_null: true},
              { column_name:  'RETENTION',                      column_type:   'INTERVAL DAY(5) TO SECOND(1)',  not_null: true },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },          ],
          primary_key: ['DBID'],
      },


  ]

=begin

Generator-Selects:

######### Structure
SELECT '              { column_name:  '''||Column_Name||''',     column_type:   '''||Data_Type||''''||
       CASE WHEN Nullable = 'N' THEN ', not_null: true' END ||
       CASE WHEN (Data_Type != 'NUMBER' OR Data_Length != 22) AND Data_Type NOT IN ('DATE') THEN ', precision: '||Data_Length  END ||
       ' },'
FROM   DBA_Tab_Columns
WHERE  Table_Name = 'DBA_HIST_SQLSTAT'
ORDER BY Column_ID
;

######### Field-List
SELECT Column_Name||','
FROM   DBA_Tab_Columns
WHERE  Table_Name = 'DBA_HIST_SQLSTAT'
ORDER BY Column_ID
;

=end


=begin
  Expexted structure, should contain structure of highest Oracle version:
 [
     {
         view_name: ,
         view_select: ""
     }
 ]
=end
  # Dynamic declaration of views to allow adjustment to current database version
  def self.view_declaration
    [
        {
            view_name: 'Panorama_V$Active_Sess_History',
            view_select: "SELECT h.INSTANCE_NUMBER, h.SAMPLE_ID, h.SAMPLE_TIME, h.IS_AWR_SAMPLE, h.SESSION_ID, h.SESSION_SERIAL#, h.SESSION_TYPE, h.FLAGS, h.USER_ID, h.SQL_ID, h.IS_SQLID_CURRENT, h.SQL_CHILD_NUMBER,
                                 h.SQL_OPCODE, h.SQL_OPNAME, h.FORCE_MATCHING_SIGNATURE, h.TOP_LEVEL_SQL_ID, h.TOP_LEVEL_SQL_OPCODE, h.SQL_PLAN_HASH_VALUE, h.SQL_PLAN_LINE_ID, h.SQL_PLAN_OPERATION, h.SQL_PLAN_OPTIONS,
                                 h.SQL_EXEC_ID, h.SQL_EXEC_START, h.PLSQL_ENTRY_OBJECT_ID, h.PLSQL_ENTRY_SUBPROGRAM_ID, h.PLSQL_OBJECT_ID, h.PLSQL_SUBPROGRAM_ID, h.QC_INSTANCE_ID, h.QC_SESSION_ID, h.QC_SESSION_SERIAL#, h.PX_FLAGS,
                                 h.EVENT, h.EVENT_ID, h.SEQ#, h.P1TEXT, h.P1, h.P2TEXT, h.P2, h.P3TEXT, h.P3,h.WAIT_CLASS, h.WAIT_CLASS_ID, h.WAIT_TIME, h.SESSION_STATE, h.TIME_WAITED,
                                 h.BLOCKING_SESSION_STATUS, h.BLOCKING_SESSION, h.BLOCKING_SESSION_SERIAL#, h.BLOCKING_INST_ID, h.BLOCKING_HANGCHAIN_INFO, h.CURRENT_OBJ#, h.CURRENT_FILE#, h.CURRENT_BLOCK#, h.CURRENT_ROW#,
                                 h.TOP_LEVEL_CALL#,
                                 #{PanoramaConnection.db_version >= '11.2' ? "tlcn.Top_Level_Call_Name" : "NULL Top_Level_Call_Name"},
                                 h.CONSUMER_GROUP_ID, h.XID,h.REMOTE_INSTANCE#, h.TIME_MODEL, h.IN_CONNECTION_MGMT, h.IN_PARSE, h.IN_HARD_PARSE, h.IN_SQL_EXECUTION, h.IN_PLSQL_EXECUTION,
                                 h.IN_PLSQL_RPC, h.IN_PLSQL_COMPILATION, h.IN_JAVA_EXECUTION, h.IN_BIND, h.IN_CURSOR_CLOSE, h.IN_SEQUENCE_LOAD, h.IN_INMEMORY_QUERY, h.IN_INMEMORY_POPULATE, h.IN_INMEMORY_PREPOPULATE, h.IN_INMEMORY_REPOPULATE,
                                 h.IN_INMEMORY_TREPOPULATE, h.IN_TABLESPACE_ENCRYPTION, h.CAPTURE_OVERHEAD, h.REPLAY_OVERHEAD, h.IS_CAPTURED, h.IS_REPLAYED, h.SERVICE_HASH, h.PROGRAM,h.MODULE, h.ACTION, h.CLIENT_ID, h.MACHINE, h.PORT,
                                 h.ECID, h.DBREPLAY_FILE_ID, h.DBREPLAY_CALL_COUNTER, h.TM_DELTA_TIME, h.TM_DELTA_CPU_TIME, h.TM_DELTA_DB_TIME, h.DELTA_TIME, h.DELTA_READ_IO_REQUESTS, h.DELTA_WRITE_IO_REQUESTS, h.DELTA_READ_IO_BYTES,
                                 h.DELTA_WRITE_IO_BYTES, h.DELTA_INTERCONNECT_IO_BYTES, h.PGA_ALLOCATED, h.TEMP_SPACE_ALLOCATED, h.CON_ID
                          FROM   Internal_V$Active_Sess_History h
                          #{"LEFT OUTER JOIN Panorama_TopLevelCall_Name tlcn ON tlcn.DBID = #{PanoramaConnection.dbid} AND tlcn.Top_Level_Call# = h.Top_Level_Call# AND tlcn.Con_DBID = #{PanoramaConnection.dbid}" if PanoramaConnection.db_version >= '11.2'}
                         "
        },
        {
            view_name: 'Panorama_Active_Sess_History',
            view_select: "SELECT h.SNAP_ID, h.DBID, h.INSTANCE_NUMBER, h.CON_DBID, h.CON_ID, h.SAMPLE_ID, h.SAMPLE_TIME, h.SESSION_ID, h.SESSION_SERIAL#, h.SESSION_TYPE, h.FLAGS, h.USER_ID, h.SQL_ID, h.IS_SQLID_CURRENT, h.SQL_CHILD_NUMBER, h.SQL_OPCODE, h.SQL_OPNAME,
                                 h.FORCE_MATCHING_SIGNATURE, h.TOP_LEVEL_SQL_ID, h.TOP_LEVEL_SQL_OPCODE, h.SQL_PLAN_HASH_VALUE, h.SQL_PLAN_LINE_ID, h.SQL_PLAN_OPERATION, h.SQL_PLAN_OPTIONS, h.SQL_EXEC_ID, h.SQL_EXEC_START, h.PLSQL_ENTRY_OBJECT_ID,
                                 h.PLSQL_ENTRY_SUBPROGRAM_ID, h.PLSQL_OBJECT_ID, h.PLSQL_SUBPROGRAM_ID, h.QC_INSTANCE_ID, h.QC_SESSION_ID, h.QC_SESSION_SERIAL#, h.PX_FLAGS, h.EVENT, h.EVENT_ID, h.SEQ#, h.P1TEXT, h.P1, h.P2TEXT, h.P2, h.P3TEXT, h.P3, h.WAIT_CLASS,
                                 h.WAIT_CLASS_ID, h.WAIT_TIME, h.SESSION_STATE, h.TIME_WAITED, h.BLOCKING_SESSION_STATUS, h.BLOCKING_SESSION, h.BLOCKING_SESSION_SERIAL#, h.BLOCKING_INST_ID, h.BLOCKING_HANGCHAIN_INFO, h.CURRENT_OBJ#, h.CURRENT_FILE#,
                                 h.CURRENT_BLOCK#, h.CURRENT_ROW#, h.TOP_LEVEL_CALL#,
                                 #{PanoramaConnection.db_version >= '11.2' ? "tlcn.Top_Level_Call_Name" : "NULL Top_Level_Call_Name"},
                                 h.CONSUMER_GROUP_ID, h.XID, h.REMOTE_INSTANCE#, h.TIME_MODEL, h.IN_CONNECTION_MGMT, h.IN_PARSE, h.IN_HARD_PARSE, h.IN_SQL_EXECUTION, h.IN_PLSQL_EXECUTION,
                                 h.IN_PLSQL_RPC, h.IN_PLSQL_COMPILATION, h.IN_JAVA_EXECUTION, h.IN_BIND, h.IN_CURSOR_CLOSE, h.IN_SEQUENCE_LOAD, h.CAPTURE_OVERHEAD, h.REPLAY_OVERHEAD, h.IS_CAPTURED, h.IS_REPLAYED, h.SERVICE_HASH, h.PROGRAM, h.MODULE, h.ACTION, h.CLIENT_ID,
                                 h.MACHINE, h.PORT, h.ECID, h.DBREPLAY_FILE_ID, h.DBREPLAY_CALL_COUNTER, h.TM_DELTA_TIME, h.TM_DELTA_CPU_TIME, h.TM_DELTA_DB_TIME, h.DELTA_TIME, h.DELTA_READ_IO_REQUESTS, h.DELTA_WRITE_IO_REQUESTS, h.DELTA_READ_IO_BYTES,
                                 h.DELTA_WRITE_IO_BYTES, h.DELTA_INTERCONNECT_IO_BYTES, h.PGA_ALLOCATED, h.TEMP_SPACE_ALLOCATED, h.IN_INMEMORY_QUERY, h.IN_INMEMORY_POPULATE, h.IN_INMEMORY_PREPOPULATE, h.IN_INMEMORY_REPOPULATE, h.IN_INMEMORY_TREPOPULATE,
                                 h.IN_TABLESPACE_ENCRYPTION
                          FROM   Internal_Active_Sess_History h
                          #{"LEFT OUTER JOIN Panorama_TopLevelCall_Name tlcn ON tlcn.DBID = h.DBID AND tlcn.Top_Level_Call# = h.Top_Level_Call# AND tlcn.Con_DBID = h.Con_DBID" if PanoramaConnection.db_version >= '11.2'}
                         "
        },
    ]
  end



  # Replace DBA_Hist in SQL with corresponding Panorama-Sampler table
  def self.transform_sql_for_sampler(org_sql)
    sql = org_sql.clone

    # fake gv$Active_Session_History in SQL so translation will hit it
    sql.gsub!(/gv\$Active_Session_History/i, 'DBA_HIST_V$Active_Sess_History')

    up_sql = sql.upcase

    compare_objects = @@tables.clone                                            # Add tables to compare-objects
    PanoramaSamplerStructureCheck.view_declaration.each do |view|                                             # Add views to compare-objects
      compare_objects << { :table_name => view[:view_name]}
    end

    start_index = up_sql.index('DBA_HIST')
    while start_index
#      Rails.logger.info "######################### #{start_index} #{sql[start_index, sql.length-start_index]}"
      compare_objects.each do |table|                                                  # Check if table might be replaced by Panorama-Sampler
        if table[:table_name].upcase == up_sql[start_index, table[:table_name].length].gsub(/DBA_HIST/, 'PANORAMA')
          sql   .insert(start_index, "#{PanoramaConnection.get_config[:panorama_sampler_schema]}.")       # Add schema name before table_name
          up_sql.insert(start_index, "#{PanoramaConnection.get_config[:panorama_sampler_schema]}.")       # Increase size synchronously with sql
          start_index += PanoramaConnection.get_config[:panorama_sampler_schema].length+1                 # Increase Pointer by schemaname
          7.downto(0) do |pos|                                                                            # Copy replacement table_name char by char into sql (DBA_HIST -> Panorama)
            sql[start_index+pos] = table[:table_name][pos]
          end
        end
      end


      start_index = up_sql.index('DBA_HIST', start_index + 8)                   # Look for next occurrence
    end
    sql
  end

  # Replace DBA_Hist tablename in HTML-templates with corresponding Panorama-Sampler table and schema
  def self.adjust_table_name(org_table_name)
    return org_table_name if PanoramaConnection.get_config[:management_pack_license] != :panorama_sampler   # Sampler not active
    replacement = replacement_table(org_table_name)
    return org_table_name if replacement.nil?
    "#{PanoramaConnection.get_config[:panorama_sampler_schema]}.#{replacement}" # Table replaced by sampler
  end

  # Check existence of DBA_Hist-alternative in Panorama
  def self.replacement_table(dba_hist_tablename)
    search_table_name = dba_hist_tablename.upcase
    return nil if dba_hist_tablename.length < 8
    search_table_name['DBA_HIST'] = 'PANORAMA'
    @@tables.each do |table|
      return table[:table_name]  if table[:table_name].upcase == search_table_name
    end
    nil
  end

  def self.has_column?(table_name, column_name)
    @@tables.each do |table|
      if table[:table_name].upcase == table_name.upcase                         # table exists
        table[:columns].each do |column|
          return true if column[:column_name].upcase == column_name.upcase
        end
      end
    end
    false
  end

  # Check data structures, for ASH-Thread or snapshot thread
  def do_check_internal(only_ash_tables)

    @ora_tables       = PanoramaConnection.sql_select_all ["SELECT Table_Name FROM All_Tables WHERE Owner = ?",  @sampler_config[:owner].upcase]
    @ora_tab_privs    = PanoramaConnection.sql_select_all ["SELECT Table_Name FROM ALL_TAB_PRIVS WHERE Table_Schema = ?  AND Privilege = 'SELECT'  AND Grantee = 'PUBLIC'",  @sampler_config[:owner].upcase]

    @@tables.each do |table|
      check_table_existence(table) if check_table_in_this_thread?(table[:table_name], only_ash_tables)
    end

    @ora_tab_columns  = PanoramaConnection.sql_select_all ["SELECT Table_Name, Column_Name FROM All_Tab_Columns WHERE Owner = ? ORDER BY Table_Name, Column_ID", @sampler_config[:owner].upcase]
    @ora_tab_colnull  = PanoramaConnection.sql_select_all ["SELECT Table_Name, Column_Name, Nullable FROM All_Tab_Columns WHERE Owner = ? ORDER BY Table_Name, Column_ID", @sampler_config[:owner].upcase]
    @@tables.each do |table|
      check_table_columns(table) if check_table_in_this_thread?(table[:table_name], only_ash_tables)
    end

    @ora_tab_pkeys    = PanoramaConnection.sql_select_all ["SELECT Table_Name FROM All_Constraints WHERE Owner = ? AND Constraint_Type='P'", @sampler_config[:owner].upcase]
    @ora_tab_pk_cols  = PanoramaConnection.sql_select_all ["SELECT cc.Table_Name, cc.Column_Name, cc.Position
                                                            FROM All_Cons_Columns cc
                                                            JOIN All_Constraints c ON c.Owner = cc.Owner AND c.Table_Name = cc.Table_Name AND c.Constraint_Name = cc.Constraint_Name AND c.Constraint_Type = 'P'
                                                            WHERE cc.Owner = ?
                                                          ", @sampler_config[:owner].upcase]
    @ora_indexes      = PanoramaConnection.sql_select_all ["SELECT Table_Name, Index_Name FROM All_Indexes WHERE Owner = ?", @sampler_config[:owner].upcase]
    @ora_ind_columns  = PanoramaConnection.sql_select_all ["SELECT Table_Name, Index_Name, Column_Name, Column_Position FROM All_Ind_Columns WHERE Table_Owner = ?", @sampler_config[:owner].upcase]
    @@tables.each do |table|
      check_table_pkey(table) if check_table_in_this_thread?(table[:table_name], only_ash_tables)
    end

    @@tables.each do |table|
      check_table_indexes(table) if check_table_in_this_thread?(table[:table_name], only_ash_tables)
    end


    @ora_views        = PanoramaConnection.sql_select_all ["SELECT View_Name FROM All_Views WHERE Owner = ?",  @sampler_config[:owner].upcase]
    @ora_view_texts   = PanoramaConnection.sql_select_all ["SELECT View_Name, Text FROM All_Views WHERE Owner = ?",  @sampler_config[:owner].upcase]
    @ora_tables       = PanoramaConnection.sql_select_all ["SELECT Table_Name FROM All_Tables WHERE Owner = ?",  @sampler_config[:owner].upcase]
    PanoramaSamplerStructureCheck.view_declaration.each do |view|
      check_view(view) if check_view_in_this_thread?(view[:view_name], only_ash_tables)
    end

    if only_ash_tables
      # Check PL/SQL package

      # Get Path to this model class as base for sql files
      # source_dir = Pathname(PanoramaSamplerStructureCheck.instance_method(:do_check_internal).source_location[0]).dirname.join('../helpers/panorama_sampler')

      filename = PanoramaSampler::PackagePanoramaSamplerAsh.instance_method(:panorama_sampler_ash_spec).source_location[0]

      create_or_check_package(filename, panorama_sampler_ash_spec, 'PANORAMA_SAMPLER_ASH', :spec)
      create_or_check_package(filename, panorama_sampler_ash_body, 'PANORAMA_SAMPLER_ASH', :body)
    else                                                                        # for snapshot thread
      filename = PanoramaSampler::PackagePanoramaSamplerSnapshot.instance_method(:panorama_sampler_snapshot_spec).source_location[0]

      create_or_check_package(filename, panorama_sampler_snapshot_spec, 'PANORAMA_SAMPLER_SNAPSHOT', :spec)
      create_or_check_package(filename, panorama_sampler_snapshot_body, 'PANORAMA_SAMPLER_SNAPSHOT', :body)
    end
  end

  def remove_tables_internal
    packages = PanoramaConnection.sql_select_all [ "SELECT Object_Name
                                                    FROM   All_Objects
                                                    WHERE  Owner=? AND Object_Type = 'PACKAGE'
                                                    AND    Object_Name IN ('PANORAMA_SAMPLER_SNAPSHOT', 'PANORAMA_SAMPLER_ASH')
                                                   ", @sampler_config[:owner].upcase]
    packages.each do |package|
      PanoramaConnection.sql_execute("DROP PACKAGE #{@sampler_config[:owner]}.#{package.object_name}")
    end

    ora_tables = PanoramaConnection.sql_select_all ["SELECT Table_Name FROM All_Tables WHERE Owner = ?",  @sampler_config[:owner].upcase]
    @@tables.each do |table|
      if ora_tables.include?({'table_name' => table[:table_name].upcase})
        begin
          ############# Drop Table
          sql = "DROP TABLE #{@sampler_config[:owner]}.#{table[:table_name]}"
          log(sql)
          PanoramaConnection.sql_execute(sql)
          log "Table #{table[:table_name]} dropped"
        rescue Exception => e
          Rails.logger.error "Error #{e.message} dropping table #{@sampler_config[:owner]}.#{table[:table_name]}"
          log_exception_backtrace(e, 40)
          raise e
        end
      end
    end
  end

  private

  def get_package_obj(package_name, type)
    PanoramaConnection.sql_select_first_row [ "SELECT Status, Last_DDL_Time
                                               FROM   All_Objects
                                               WHERE  Object_Type = ?
                                               AND    Owner       = ?
                                               AND    Object_Name = ?
                                              ", (type == :spec ? 'PACKAGE' : 'PACKAGE BODY'), @sampler_config[:owner].upcase, package_name.upcase]
  end

  # type :spec or :body
  def create_or_check_package(file_for_time_check, source_buffer, package_name, type)
    package_obj = get_package_obj(package_name, type)

    if package_obj.nil? || package_obj.last_ddl_time < File.ctime(file_for_time_check) || package_obj.status != 'VALID'
      # Compile package
      Rails.logger.info "Package #{'body ' if type==:body}#{@sampler_config[:owner].upcase}.#{package_name} needs #{package_obj.nil? ? 'creation' : 'recompile'}"
      translated_source_buffer = source_buffer.gsub(/PANORAMA\./i, "#{@sampler_config[:owner].upcase}.")    # replace PANORAMA with the real owner
      translated_source_buffer.gsub!(/COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME/, Time.now.to_s) # change source to provocate change of LAST_DDL_TIME

      PanoramaConnection.sql_execute translated_source_buffer
      package_obj = get_package_obj(package_name, type)                         # repeat check on ALL_Objects
      if package_obj.status != 'VALID'
        errors = PanoramaConnection.sql_select_all ["SELECT * FROM User_Errors WHERE Name = ? AND Type = ? ORDER BY Sequence", package_name.upcase, (type==:spec ? 'PACKAGE' : 'PACKAGE BODY')]
        errors.each do |e|
          Rails.logger.error "Line=#{e.line} position=#{e.position}: #{e.text}"
        end
        raise "Error compiling package #{'body ' if type==:body}#{@sampler_config[:owner].upcase}.#{package_name}. See previous lines"
      end
    end
  end

  # Check if this table check belongs to ash or snapshot
  def check_table_in_this_thread?(table_name, only_ash_tables)
    ash_tables = ['Internal_V$Active_Sess_History'.upcase, 'Panorama_TopLevelCall_Name'.upcase, 'Panorama_Service_Name'.upcase]
    (only_ash_tables && ash_tables.include?(table_name.upcase)) ||  (!only_ash_tables && !ash_tables.include?(table_name.upcase))
  end

  def check_view_in_this_thread?(view_name, only_ash_tables)
    ash_views = ['Panorama_V$Active_Sess_History'.upcase]
    (only_ash_tables && ash_views.include?(view_name.upcase)) ||  (!only_ash_tables && !ash_views.include?(view_name.upcase))
  end

  def check_table_existence(table)
    if !@ora_tables.include?({'table_name' => table[:table_name].upcase})
      ############# Check Table existence
      log "Table #{table[:table_name]} does not exist"
      sql = "CREATE TABLE #{@sampler_config[:owner]}.#{table[:table_name]} ("
      table[:columns].each do |column|
        sql << "#{column[:column_name]} #{column[:column_type]} #{"(#{column[:precision]}#{", #{column[:scale]}" if column[:scale]})" if column[:precision]} #{column[:addition]} ,"
      end
      sql[(sql.length) - 1] = ' '                                               # remove last ,
      sql << ") PCTFREE 10"
      log(sql)
      PanoramaConnection.sql_execute(sql)
      log "Table #{table[:table_name]} created"
    end

    ############ Check table privileges
    check_object_privs(table[:table_name])                                      # check SELECT grant to PUBLIC
  end

  def check_table_columns(table)
    table[:columns].each do |column|
      # Check column existence
      if !@ora_tab_columns.include?({'table_name' => table[:table_name].upcase, 'column_name' => column[:column_name].upcase})
        sql = "ALTER TABLE #{@sampler_config[:owner]}.#{table[:table_name]} ADD ("
        sql << "#{column[:column_name]} #{column[:column_type]} #{"(#{column[:precision]}#{", #{column[:scale]}" if column[:scale]})" if column[:precision]} #{column[:addition]}"
        sql << ")"
        log(sql)
        PanoramaConnection.sql_execute(sql)
      end

      # check column null state
      if !@ora_tab_colnull.include?({'table_name' => table[:table_name].upcase, 'column_name' => column[:column_name].upcase, 'nullable' => (column[:not_null] ? 'N' : 'Y')})
        sql = "ALTER TABLE #{@sampler_config[:owner]}.#{table[:table_name]} MODIFY ("
        sql << "#{column[:column_name]} #{column[:not_null] ? 'NOT NULL' : 'NULL'}"
        sql << ")"
        log(sql)
        PanoramaConnection.sql_execute(sql)
      end
    end

    # Check existencwe of obsolete columns
    @ora_tab_columns.each do |tcol|
      if tcol.table_name == table[:table_name].upcase
        should_exist = false
        table[:columns].each do |column|
          if tcol.column_name == column[:column_name].upcase
            should_exist = true
            break
          end
        end
        if !should_exist
          sql = "ALTER TABLE #{@sampler_config[:owner]}.#{table[:table_name]} DROP COLUMN #{tcol.column_name}"
          log(sql)
          PanoramaConnection.sql_execute(sql)
        end
      end
    end
  end

  def check_table_pkey(table)
    ############ Check Primary Key
    if table[:primary_key]
      pk_name = "#{table[:table_name][0,27]}_PK"
      if @ora_tab_pkeys.include?({'table_name' => table[:table_name].upcase})   # PKey exists
        ########### Check columns of primary key
        existing_pk_columns_count = 0
        @ora_tab_pk_cols.each {|pk| existing_pk_columns_count += 1 if pk.table_name == table[:table_name].upcase }

        table[:primary_key].each_index do |index|
          column = table[:primary_key][index]
          if !@ora_tab_pk_cols.include?({'table_name' => table[:table_name].upcase, 'column_name' => column.upcase, 'position' => index+1}) || existing_pk_columns_count != table[:primary_key].count
            sql = "ALTER TABLE #{@sampler_config[:owner]}.#{table[:table_name]} DROP CONSTRAINT #{pk_name}"
            log(sql)
            PanoramaConnection.sql_execute(sql)

            sql = "DROP INDEX #{@sampler_config[:owner]}.#{pk_name}"
            log(sql)
            PanoramaConnection.sql_execute(sql)
            break
          end
        end
      end


      ########### Check PK-Index existence
      check_index(table[:table_name], pk_name, table[:primary_key])

      ######## Check existence of PK-Constraint
      if !@ora_tab_pkeys.include?({'table_name' => table[:table_name].upcase})   # PKey does not exist
        sql = "ALTER TABLE #{@sampler_config[:owner]}.#{table[:table_name]} ADD CONSTRAINT #{pk_name} PRIMARY KEY ("
        table[:primary_key].each do |pk|
          sql << "#{pk},"
        end
        sql[(sql.length) - 1] = ' '                                               # remove last ,
        sql << ") USING INDEX #{pk_name}"
        log(sql)
        PanoramaConnection.sql_execute(sql)
      end
    end
  end

  def check_table_indexes(table)
  ############ Check Indexes
    if table[:indexes]
      table[:indexes].each do |index|
        check_index(table[:table_name], index[:index_name], index[:columns])
      end
    end

  end

  def check_index(table_name, index_name, columns)
    if @ora_indexes.include?({'table_name' => table_name.upcase, 'index_name' => index_name.upcase})  # Index exists
      ########### Check columns of index
      existing_index_columns_count = 0
      @ora_ind_columns.each do |col|
        existing_index_columns_count += 1 if col.table_name == table_name.upcase && col.index_name == index_name.upcase
      end

      columns.each_index do |i|
        column = columns[i]
        if !@ora_ind_columns.include?({'table_name' => table_name.upcase, 'index_name' => index_name.upcase, 'column_name' => column.upcase, 'column_position' => i+1}) || existing_index_columns_count != columns.count
          sql = "DROP INDEX #{@sampler_config[:owner]}.#{index_name}"
          log(sql)
          PanoramaConnection.sql_execute(sql)
          break
        end
      end
    end

    ########### Check existence of index
    if !@ora_indexes.include?({'table_name' => table_name.upcase, 'index_name' => index_name.upcase}) # Index does not exists
      sql = "CREATE INDEX #{@sampler_config[:owner]}.#{index_name} ON #{@sampler_config[:owner]}.#{table_name}("
      columns.each do |column|
        sql << "#{column},"
      end
      sql[(sql.length) - 1] = ' '                                               # remove last ,
      sql << ") PCTFREE 10"
      log(sql)
      PanoramaConnection.sql_execute(sql)
    end
  end

  # Check existence and structure of view
  def check_view(view)
    if @ora_tables.include?({'table_name' => view[:view_name].upcase})
      sql = "DROP TABLE #{@sampler_config[:owner]}.#{view[:view_name]}"         # Remove table from previous releases with same name
      log(sql)
      PanoramaConnection.sql_execute(sql)
    end

    if @ora_views.include?({'view_name' => view[:view_name].upcase})            # View already exists
      index = @ora_view_texts.find_index { |view_text| view_text.view_name ==  view[:view_name].upcase}
      select = @ora_view_texts[index].text
      if select != view[:view_select]                                             # Recreate view
        sql = "DROP VIEW #{@sampler_config[:owner]}.#{view[:view_name]}"
        log(sql)
        PanoramaConnection.sql_execute(sql)
        create_view(view)
      end
    else                                                                        # View dow not exist
      create_view(view)
    end
    check_object_privs(view[:view_name])                                        # check SELECT grant to PUBLIC
  end

  def create_view(view)
    sql = "CREATE VIEW #{@sampler_config[:owner]}.#{view[:view_name]} AS\n#{view[:view_select]}"
    log(sql)
    PanoramaConnection.sql_execute(sql)
  end

  def check_object_privs(object_name)
    ############ Check table or view privileges
    if !@ora_tab_privs.include?({'table_name' => object_name.upcase})
      sql = "GRANT SELECT ON #{@sampler_config[:owner]}.#{object_name} TO PUBLIC"
      log(sql)
      PanoramaConnection.sql_execute(sql)
    end

  end


end