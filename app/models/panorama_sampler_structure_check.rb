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
          primary_key: ['DBID', 'Snap_ID', 'Instance_Number']
      }

  ]
  # Check data structures
  def do_check_internal
    @@tables.each do |table|
      check_table(table)
    end
  end

  private

  def check_table(table)
    exists = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM User_Tables WHERE Table_Name = ?", table[:table_name].upcase]
    if exists == 0
      log "Table #{table[:table_name]} does not exist"
      sql = "CREATE TABLE #{table[:table_name]} ("
      table[:columns].each do |column|
        sql << "#{column[:column_name]} #{column[:column_type]} #{"(#{column[:precision]}#{", #{column[:scale]}" if column[:scale]})" if column[:precision]} #{column[:addition]} ,"
      end
      sql[(sql.length) - 1] = ' '                                               # remove last ,
      sql << ") PCTFREE 10"
      log(sql)
      PanoramaConnection.sql_execute(sql)
      log "Table #{table[:table_name]} created"

      pk_name = "#{table[:table_name][0,27]}_PK"
      sql = "CREATE INDEX #{pk_name} ON #{table[:table_name]}("
      table[:primary_key].each do |pk|
        sql << "#{pk},"
      end
      sql[(sql.length) - 1] = ' '                                               # remove last ,
      sql << ") PCTFREE 10"
      log(sql)
      PanoramaConnection.sql_execute(sql)
    else
      # Check structure
    end

  end

end