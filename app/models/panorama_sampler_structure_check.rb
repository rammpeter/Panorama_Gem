class PanoramaSamplerStructureCheck
  include ExceptionHelper

  def self.do_check(sampler_config)
    PanoramaSamplerStructureCheck.new(sampler_config).do_check_internal
  end

  def self.remove_tables(sampler_config)
    PanoramaSamplerStructureCheck.new(sampler_config).remove_tables_internal
  end

  def self.tables
    @@tables
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
              { column_name:  'Con_DBID',                       column_type:  'NUMBER' },
              { column_name:  'Con_ID',                         column_type:  'NUMBER' },
          ],
          primary_key: ['DBID', 'Snap_ID', 'Instance_Number', 'Group#', 'Thread#', 'Sequence#', 'Con_DBID']
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
              { column_name:  'CON_DBID',                       column_type:   'NUMBER' },
              { column_name:  'CON_ID',                         column_type:   'NUMBER' },
          ],
          primary_key: ['DBID', 'SNAP_ID', 'INSTANCE_NUMBER', 'SQL_ID', 'PLAN_HASH_VALUE', 'CON_DBID'],
          indexes: [ {index_name: 'Panorama_SQLStat_SQLID_IX', columns: ['SQL_ID', 'DBID', 'CON_DBID'] } ]
      },

=begin
Generator-Selects:

######### Structure
SELECT '              { column_name:  '''||Column_Name||''',     column_type:   '''||Data_Type||''''||
       CASE WHEN Nullable = 'N' THEN ', not_null: true' END ||
       CASE WHEN (Data_Type != 'NUMBER' OR Data_Length != 22) THEN ', precision: '||Data_Length  END ||
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

  ]

  # Replace DBA_Hist in SQL with corresponding Panorama-Sampler table
  def self.transform_sql_for_sampler(org_sql)
    sql = org_sql.clone
    up_sql = sql.upcase
    start_index = up_sql.index('DBA_HIST')
    while start_index
#      Rails.logger.info "######################### #{start_index} #{sql[start_index, sql.length-start_index]}"
      @@tables.each do |table|                                                  # Check if table might be replaced by Panorama-Sampler
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
    return org_table_name if PanoramaConnection.get_config[:panorama_sampler_schema].nil?   # Sampler not active
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

  # Check data structures
  def do_check_internal
    @@tables.each do |table|
      check_table(table)
    end
  end

  def remove_tables_internal
    @@tables.each do |table|
      exists = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Tables WHERE Owner = ? AND Table_Name = ?", @sampler_config[:owner].upcase, table[:table_name].upcase]
      if exists > 0
        ############# Drop Table
        sql = "DROP TABLE #{@sampler_config[:owner]}.#{table[:table_name]}"
        log(sql)
        PanoramaConnection.sql_execute(sql)
        log "Table #{table[:table_name]} dropped"
      end
    end
  end

  private

  def check_table(table)
    exists = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Tables WHERE Owner = ? AND Table_Name = ?", @sampler_config[:owner].upcase, table[:table_name].upcase]
    if exists == 0
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

    ############ Check columns
    table[:columns].each do |column|
      exists = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Tab_Columns WHERE Owner = ? AND Table_Name = ? AND Column_Name = ?", @sampler_config[:owner].upcase, table[:table_name].upcase, column[:column_name].upcase]
      if exists == 0                                                            # Column does not exists
        sql = "ALTER TABLE #{@sampler_config[:owner]}.#{table[:table_name]} ADD ("
        sql << "#{column[:column_name]} #{column[:column_type]} #{"(#{column[:precision]}#{", #{column[:scale]}" if column[:scale]})" if column[:precision]} #{column[:addition]}"
        sql << ")"
        log(sql)
        PanoramaConnection.sql_execute(sql)
      end
    end


    ############ Check Primary Key
    if table[:primary_key]
      pk_name = "#{table[:table_name][0,27]}_PK"
      exists_pk = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Constraints WHERE Owner = ? AND Table_Name = ? AND Constraint_Type='P'", @sampler_config[:owner].upcase, table[:table_name].upcase]

      if exists_pk > 0
        ########### Check columns of primary key
        table[:primary_key].each_index do |index|
          column = table[:primary_key][index]
          exists = PanoramaConnection.sql_select_one [" SELECT COUNT(*)
                                                      FROM All_Cons_Columns cc
                                                      JOIN All_Constraints c ON c.Owner = cc.Owner AND c.Table_Name = cc.Table_Name AND c.Constraint_Name = cc.Constraint_Name AND c.Constraint_Type = 'P'
                                                      WHERE cc.Owner = ? AND cc.Table_Name = ? AND cc.Column_Name = ? AND cc.Position = ?
                                                    ", @sampler_config[:owner].upcase, table[:table_name].upcase, column.upcase, index+1]
          if exists == 0
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
      exists = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Constraints WHERE Owner = ? AND Table_Name = ? AND Constraint_Type='P'", @sampler_config[:owner].upcase, table[:table_name].upcase]
      if exists == 0
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

    ############ Check Indexes
    if table[:indexes]
      table[:indexes].each do |index|
        check_index(table[:table_name], index[:index_name], index[:columns])
      end
    end

  end

  def check_index(table_name, index_name, columns)
    exists_index = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Indexes WHERE Owner = ? AND Table_Name = ? AND Index_Name = ?", @sampler_config[:owner].upcase, table_name.upcase, index_name.upcase]
    if exists_index > 0
      ########### Check columns of index
      columns.each_index do |i|
        column = columns[i]
        exists = PanoramaConnection.sql_select_one [" SELECT COUNT(*) FROM All_Ind_Columns WHERE Table_Owner = ? AND Table_Name = ? AND Index_Name = ? AND Column_Name = ? AND Column_Position = ?
                                                    ", @sampler_config[:owner].upcase, table_name.upcase, index_name.upcase, column.upcase, i+1]
        if exists == 0
          sql = "DROP INDEX #{@sampler_config[:owner]}.#{index_name}"
          log(sql)
          PanoramaConnection.sql_execute(sql)
          break
        end
      end
    end

    ########### Check existence of index
    exists = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Indexes WHERE Owner = ? AND Table_Name = ? AND Index_Name = ?", @sampler_config[:owner].upcase, table_name.upcase, index_name.upcase]
    if exists == 0
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

end