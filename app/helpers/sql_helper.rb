# encoding: utf-8

require 'connection_holder'

# Fix uninitialized constant Application if used as engine
#require_relative '../../config/engine_config'

# Methods added to this helper will be available to class and instance
module SqlHelper

  private

  def sql_prepare_binds(sql)
    binds = []
    if sql.class == Array
      stmt =sql[0].clone      # Kopieren, da im Stmt nachfolgend Ersetzung von ? durch :A1 .. :A<n> durchgeführt wird
      # Aufbereiten SQL: Ersetzen Bind-Aliases
      bind_index = 0
      while stmt['?']                   # Iteration über Binds
        bind_index = bind_index + 1
        bind_alias = ":A#{bind_index}"
        stmt['?'] = bind_alias          # Ersetzen ? durch Host-Variable
        unless sql[bind_index]
          raise "bind value at position #{bind_index} is NULL for '#{bind_alias}' in binds-array for sql: #{stmt}"
        end
        raise "bind value at position #{bind_index} missing for '#{bind_alias}' in binds-array for sql: #{stmt}" if sql.count <= bind_index
        binds << ActiveRecord::Relation::QueryAttribute.new(bind_alias, sql[bind_index], ActiveRecord::Type::Value.new)   # Ab Rails 5
        # binds << [ ActiveRecord::ConnectionAdapters::Column.new(bind_alias, nil, ActiveRecord::Type::Value.new), sql[bind_index]] # Neu ab Rails 4.2.0, Abstrakter Typ muss angegeben werden
      end
    else
      if sql.class == String
        stmt = sql
      else
        raise "Unsupported Parameter-Class '#{sql.class.name}' for parameter sql of sql_select_all(sql)"
      end
    end
    [stmt, binds]
  end

  # Translate text in SQL-statement
  def translate_sql(stmt)
    stmt.gsub!(/\n[ \n]*\n/, "\n")                                                  # Remove empty lines in SQL-text
    stmt
  end

  public
  # Helper fuer Ausführung SQL-Select-Query,
  # Parameter: sql = String mit Statement oder Array mit Statement und Bindevariablen
  #            modifier = proc für Anwendung auf die fertige Row
  # return Array of Hash mit Columns des Records
  def sql_select_all(sql, modifier=nil, query_name = 'sql_select_all')   # Parameter String mit SQL oder Array mit SQL und Bindevariablen
    #### alte standalone-Lösung
    # stmt, binds = sql_prepare_binds(sql)
    # result = ConnectionHolder.connection().select_all(stmt, 'sql_select_all', binds)
    # result.each do |h|
    #   h.each do |key, value|
    #     h[key] = value.strip if value.class == String   # Entfernen eines eventuellen 0x00 am Ende des Strings, dies führt zu Fehlern im Internet Explorer
    #   end
    #   h.extend SelectHashHelper    # erlaubt, dass Element per Methode statt als Hash-Element zugegriffen werden können
    #   modifier.call(h) unless modifier.nil?             # Anpassen der Record-Werte
    # end
    # result.to_ary                                                               # Ab Rails 4 ist result nicht mehr vom Typ Array, sondern ActiveRecord::Result

    # Mapping auf sql_select_iterator

    result = []
    sql_select_iterator(sql, modifier, query_name).each do |r|
      result << r
    end
    result
  end

  # Analog sql_select all, jedoch return ResultIterator mit each-Method
  # liefert Objekt zur späteren Iteration per each, erst dann wird SQL-Select ausgeführt (jedesmal erneut)
  # Parameter: sql = String mit Statement oder Array mit Statement und Bindevariablen
  #            modifier = proc für Anwendung auf die fertige Row
  def sql_select_iterator(sql, modifier=nil, query_name = 'sql_select_iterator')
    ConnectionHolder.check_for_open_connection(self)                            # ensure opened Oracle-connection
    stmt, binds = sql_prepare_binds(sql)
    SqlSelectIterator.new(translate_sql(stmt), binds, modifier, get_current_database[:query_timeout], query_name)      # kann per Aufruf von each die einzelnen Records liefern
  end


  # Select genau erste Zeile
  def sql_select_first_row(sql, query_name = 'sql_select_first_row')
    result = sql_select_all(sql, nil, query_name)
    return nil if result.empty?
    result[0]     #.extend SelectHashHelper      # Erweitern Hash um Methodenzugriff auf Elemente
  end

  # Select genau einen Wert der ersten Zeile des Result
  def sql_select_one(sql, query_name = 'sql_select_one')
    result = sql_select_first_row(sql, query_name)
    return nil unless result
    result.first[1]           # Value des Key/Value-Tupels des ersten Elememtes im Hash
  end


end
