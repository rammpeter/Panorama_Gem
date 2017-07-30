class PanoramaSamplerStructureCheck
  include ExceptionHelper

  def self.do_check(sampler_config)
    PanoramaSamplerStructureCheck.new(sampler_config).do_check_internal
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
      }

  ]

  # Replace
  def self.transform_sql_for_sampler(org_sql)
    sql = org_sql.clone

    sql
  end

  # Check existence of DBA_Hist-alternative in Panorama
  def self.replacement_table(dba_hist_tablename)
    search_table_name = dba_hist_tablename.upcase
    search_table_name['DBA_HIST'] = 'PANORAMA'
    @@tables.each do |table|
      return table[:table_name]  if table[:table_name].upcase == search_table_name
    end
    nil
  end

  # Check data structures
  def do_check_internal
    @@tables.each do |table|
      check_table(table)
    end
  end

  private

  def check_table(table)
    exists = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Tables WHERE Owner = ? AND Table_Name = ?", @sampler_config[:owner].upcase, table[:table_name].upcase]
    if exists == 0
      ############# Check Table
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

    ############ Check Primary Key
    if table[:primary_key]
      pk_name = "#{table[:table_name][0,27]}_PK"
      ########### Check PK-Index
      exists = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Indexes WHERE Owner = ? AND Table_Name = ? AND Index_Name = ?", @sampler_config[:owner].upcase, table[:table_name].upcase, pk_name.upcase]
      if exists == 0
        sql = "CREATE INDEX #{@sampler_config[:owner]}.#{pk_name} ON #{@sampler_config[:owner]}.#{table[:table_name]}("
        table[:primary_key].each do |pk|
          sql << "#{pk},"
        end
        sql[(sql.length) - 1] = ' '                                               # remove last ,
        sql << ") PCTFREE 10"
        log(sql)
        PanoramaConnection.sql_execute(sql)
      end
      ########PK-Constraint
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
        exists = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Indexes WHERE Owner = ? AND Table_Name = ? AND Index_Name = ?", @sampler_config[:owner].upcase, table[:table_name].upcase, index[:index_name].upcase]
        if exists == 0
          sql = "CREATE INDEX #{@sampler_config[:owner]}.#{index[:index_name]} ON #{@sampler_config[:owner]}.#{table[:table_name]}("
          index[:columns].each do |column|
            sql << "#{column},"
          end
          sql[(sql.length) - 1] = ' '                                               # remove last ,
          sql << ") PCTFREE 10"
          log(sql)
          PanoramaConnection.sql_execute(sql)
        end
      end
    end

  end

end