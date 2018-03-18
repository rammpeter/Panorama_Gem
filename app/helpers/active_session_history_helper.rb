# encoding: utf-8

module ActiveSessionHistoryHelper


  def session_statistics_key_rules
    # Regelwerk zur Verwendung der jeweiligen Gruppierungen und Verdichtungskriterien
    if !defined?(@session_statistics_key_rules_hash) || @session_statistics_key_rules_hash.nil?
      @session_statistics_key_rules_hash = {}

      # Performant access on gv$SQLArea ist unfortunately not possible here
      sql_id_info_sql = "(SELECT TO_CHAR(SUBSTR(t.SQL_Text,1,40))
                          FROM   DBA_Hist_SQLText t
                          WHERE  t.DBID=s.DBID AND t.SQL_ID=s.SQL_ID AND RowNum < 2
                         )"


      @session_statistics_key_rules_hash["Event"]           = {:sql => "NVL(s.Event, s.Session_State)", :sql_alias => "event",    :Name => 'Wait-Event',    :Title => 'Event (Session-State, if Event = NULL)', :info_sql  => "MIN(s.Wait_Class)", :info_caption => "Wait-Class", :Data_Title => '#{explain_wait_event(rec.event)}' }
      @session_statistics_key_rules_hash["Wait-Class"]      = {:sql => "NVL(s.Wait_Class, 'CPU')", :sql_alias => "wait_class",    :Name => 'Wait-Class',    :Title => 'Wait-Class' }
      @session_statistics_key_rules_hash["Instance"]    = {:sql => "s.Instance_Number",   :sql_alias => "instance_number",    :Name => 'Inst.',         :Title => 'RAC-Instance' }
      @session_statistics_key_rules_hash["Con-ID"]      = {:sql => "s.Con_ID",            :sql_alias => "con_id",             :Name => 'Con.-ID',       :Title => 'Container-ID for pluggable database', :info_sql=>"(SELECT MIN(Name) FROM gv$Containers i WHERE i.Con_ID=s.Con_ID)", :info_caption=>'Container name' } if get_current_database[:cdb]
      if get_db_version >= "11.2"
        @session_statistics_key_rules_hash["Session/Sn."] = {:sql => "DECODE(s.QC_instance_ID, NULL, s.Session_ID||', '||s.Session_Serial_No, s.QC_Session_ID||', '||s.QC_Session_Serial#)",        :sql_alias => "session_sn",        :Name => 'Session / Sn.',    :Title => 'Session-ID, SerialNo. (if executed in parallel query this is SID/sn of PQ-coordinator session)',  :info_sql  => "MIN(s.Session_Type)", :info_caption => "Session-Type" }
      else
        @session_statistics_key_rules_hash["Session/Sn."] = {:sql => "s.Session_ID||', '||s.Session_Serial_No",        :sql_alias => "session_sn",        :Name => 'Session / Sn.',    :Title => 'Session-ID, SerialNo.',  :info_sql  => "MIN(s.Session_Type)", :info_caption => "Session-Type" }
      end
      @session_statistics_key_rules_hash["Session-Type"]    = {:sql => "SUBSTR(s.Session_Type,1,1)", :sql_alias => "session_type",              :Name => 'S-T',          :Title      => "Session-type: (U)SER, (F)OREGROUND or (B)ACKGROUND" }
      @session_statistics_key_rules_hash["Transaction"]     = {:sql => "RawToHex(s.XID)",     :sql_alias => "transaction",        :Name => 'Tx.',           :Title => 'Transaction-ID' } if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["User"]            = {:sql => "u.UserName",          :sql_alias => "username",           :Name => "User",          :Title => "User" }
      @session_statistics_key_rules_hash["SQL-ID"]          = {:sql => "s.SQL_ID",            :sql_alias => "sql_id",             :Name => 'SQL-ID',        :Title => 'SQL-ID', :info_sql  => sql_id_info_sql, :info_caption => "SQL-Text (first chars)" }
      @session_statistics_key_rules_hash["SQL Exec-ID"]     = {:sql => "s.SQL_Exec_ID",       :sql_alias => "sql_exec_id",        :Name => 'SQL Exec-ID',   :Title => 'SQL Execution ID', :info_sql  => "MIN(SQL_Exec_Start)", :info_caption => "Exec. start time"} if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["Operation"]       = {:sql => "RTRIM(s.SQL_Plan_Operation||' '||s.SQL_Plan_Options)", :sql_alias => "operation", :Name => 'Operation', :Title => 'Operation of explain plan line' } if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["Module"]          = {:sql => "TRIM(s.Module)",      :sql_alias => "module",             :Name => 'Module',        :Title => 'Module set by DBMS_APPLICATION_INFO.Set_Module', :info_caption => 'Info' }
      @session_statistics_key_rules_hash["Action"]          = {:sql => "TRIM(s.Action)",      :sql_alias => "action",             :Name => 'Action',        :Title => 'Action set by DBMS_APPLICATION_INFO.Set_Module', :info_caption => 'Info' }
      @session_statistics_key_rules_hash["DB-Object"]       = {:sql => "CASE WHEN o.Object_ID IS NOT NULL THEN LOWER(o.Owner)||'.'||o.Object_Name ELSE '[Unknown] TS='||NVL(f.Tablespace_Name, 'none') END", :sql_alias  => "current_object", :Name => 'DB-Object',
                                                           :Title => "DB-Object #{I18n.t(:active_session_history_helper_db_object_title, :default=>" from gv$Session.Row_Wait_Obj#. If p2Text=object#, than this will be used instead of  row_wait_obj#. Attention: May contain object of previous action!")}", :info_sql   => "MIN(o.Object_Type)", :info_caption => "Object-Type" }
      @session_statistics_key_rules_hash["DB-Sub-Object"]   = {:sql=> "CASE WHEN o.Object_ID IS NOT NULL THEN LOWER(o.Owner)||'.'||o.Object_Name|| CASE WHEN o.SubObject_Name IS NULL THEN '' ELSE ' ('||o.SubObject_Name||')' END ELSE '[Unknown] TS='||NVL(f.Tablespace_Name, 'none') END",
                                                            :sql_alias  => "current_subobject", :Name => 'DB-Sub-Object',
                                                            :Title      => "DB-Sub-Object / Partition #{I18n.t(:active_session_history_helper_db_object_title, :default=>" from gv$Session.Row_Wait_Obj#. If p2Text=object#, than this will be used instead of  row_wait_obj#. Attention: May contain object of previous action!")}",
                                                            :info_sql   => "MIN(o.Object_Type)", :info_caption => "Object-Type" }
      @session_statistics_key_rules_hash["Entry-PL/SQL"]    = {:sql => "peo.Object_Type||CASE WHEN peo.Owner IS NOT NULL THEN ' ' END||peo.Owner||CASE WHEN peo.Object_Name IS NOT NULL THEN '.' END||peo.Object_Name||CASE WHEN peo.Procedure_Name IS NOT NULL THEN '.' END||peo.Procedure_Name",
                                                               :sql_alias => "entry_plsql_module", :Name => 'Entry-PL/SQL',      :Title => 'outermost PL/SQL module' }
      @session_statistics_key_rules_hash["PL/SQL"]          = {:sql => "po.Object_Type||CASE WHEN po.Owner IS NOT NULL THEN ' ' END||po.Owner||CASE WHEN po.Object_Name IS NOT NULL THEN '.' END||po.Object_Name||CASE WHEN po.Procedure_Name IS NOT NULL THEN '.' END||po.Procedure_Name",
                                                               :sql_alias => "plsql_module",       :Name => 'PL/SQL',        :Title => 'currently executed PL/SQL module' }
      @session_statistics_key_rules_hash["Service"]         = {:sql => "sv.Service_Name",     :sql_alias => "service",            :Name => 'Service',       :Title =>'TNS-Service' }
      @session_statistics_key_rules_hash["Tablespace"]      = {:sql => "f.TableSpace_Name",   :sql_alias => "ts_name",            :Name => 'TS-name',       :Title => "Tablespace name" }
      @session_statistics_key_rules_hash["Data-File"]       = {:sql => "s.Current_File_No",   :sql_alias => "file_no",            :Name => 'Data-file#',    :Title => "Data-file number", :info_sql => "MIN(f.File_Name)||' TS='||MIN(f.Tablespace_Name)", :info_caption => "Tablespace-Name" }
      @session_statistics_key_rules_hash["Program"]         = {:sql => "TRIM(s.Program)",     :sql_alias => "program",            :Name => 'Program',       :Title      => "Client program" }
      @session_statistics_key_rules_hash["Machine"]         = {:sql => "TRIM(s.Machine)",     :sql_alias => "machine",            :Name => 'Machine',       :Title      => "Client machine" } if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["Modus"]           = {:sql => "s.Modus",             :sql_alias => "modus",              :Name => 'Mode',          :Title      => "Mode in which session is executed" } if get_db_version >= "11.2"
      @session_statistics_key_rules_hash["PQ"]              = {:sql => "DECODE(s.QC_Instance_ID, NULL, 'NO', s.Instance_Number||':'||s.Session_ID||', '||s.Session_Serial_No)",  :sql_alias => "pq",  :Name => 'Parallel query',  :Title => 'PQ instance and session if executed in parallel query (NO if not executed in parallel or session is PQ-coordinator)' }
      @session_statistics_key_rules_hash["Plan-Hash-Value"] = {:sql => "s.SQL_Plan_Hash_Value", :sql_alias => "plan_hash_value",  :Name => 'Plan-Hash-Value', :Title => "Plan hash value, uniquely identifies execution plan of SQL" }
      @session_statistics_key_rules_hash['Remote-Instance'] = {:sql => "s.Remote_Instance_No",   :sql_alias => 'remote_instance',   :Name => 'R. I.',       :Title      => "Remote instance identifier that will serve the block that this session is waiting for.\nThis information is only available if the session was waiting for cluster events." } if get_db_version >= "11.2"
    end
    @session_statistics_key_rules_hash
  end

  def session_statistics_key_rule(key)
    retval = session_statistics_key_rules[key]
    raise "session_statistics_key_rule: unknown key '#{key}'" unless retval
    retval
  end

  # Übersetzen des SQL_Opcode in Text
  def translate_opcode(opcode)
    case opcode
      when 0 then 'No operation'
      when 1 then "CREATE TABLE"
      when 2 then "INSERT"
      when 3 then "SELECT"
      when 6 then "UPDATE"
      when 7 then "DELETE"
      when 9 then "CREATE INDEX"
      when 11 then "ALTER INDEX"
      when 15 then "ALTER TABLE"
      when 44 then "COMMIT"
      when 45 then "ROLLBACK"
      when 47 then "PL/SQL EXECUTE"
      else "Unknown, see http://download.oracle.com/docs/cd/B19306_01/server.102/b14237/dynviews_2088.htm#g1432037"
    end
  end


  # Ermitteln des SQL für NOT NULL oder NULL
  def groupfilter_value(key, value=nil)
    retval = case key.to_sym
      when :Blocking_Instance           then {:name => 'Blocking_Instance',           :sql => "s.Blocking_Inst_ID"}
      when :Blocking_Session            then {:name => 'Blocking_Session',            :sql => "s.Blocking_Session"}
      when :Blocking_Session_Serial_No  then {:name => 'Blocking_Session_Serial_No',  :sql => "s.Blocking_Session_Serial_No"}
      when :Blocking_Session_Status     then {:name => 'Blocking_Session_Status',     :sql => "s.Blocking_Session_Status"}
      when :DBID                        then {:name => 'DBID',                        :sql => "s.DBID",                          :hide_content => true}
      when :Min_Snap_ID                 then {:name => 'Min_Snap_ID',                 :sql => "s.snap_id >= ?",                  :hide_content => true, :already_bound => true  }
      when :Max_Snap_ID                 then {:name => 'Max_Snap_ID',                 :sql => "s.snap_id <= ?",                  :hide_content => true, :already_bound => true  }
      when :Plan_Line_ID                then {:name => 'Plan-Line-ID',                :sql => "s.SQL_Plan_Line_ID" }
      when :Plan_Hash_Value             then {:name => 'Plan-Hash-Value',             :sql => "s.SQL_Plan_Hash_Value"}
      when :Session_ID                  then {:name => 'Session-ID',                  :sql => "s.Session_ID"}
      when :SerialNo                    then {:name => 'SerialNo',                    :sql => "s.Session_Serial_No"}
      when :time_selection_start        then {:name => 'time_selection_start',        :sql => "s.Sample_Time >= TO_TIMESTAMP(?, '#{sql_datetime_mask(value)}')", :already_bound => true }
      when :time_selection_end          then {:name => 'time_selection_end',          :sql => "s.Sample_Time <  TO_TIMESTAMP(?, '#{sql_datetime_mask(value)}')", :already_bound => true }
      when :Idle_Wait1                  then {:name => 'Idle_Wait1',                  :sql => "NVL(s.Event, s.Session_State) != ?", :hide_content =>true, :already_bound => true}
      when :Owner                       then {:name => 'Owner',                       :sql => "UPPER(o.Owner)"}
      when :Object_Name                 then {:name => 'Object_Name',                 :sql => "o.Object_Name"}
      when :SubObject_Name              then {:name => 'SubObject_Name',              :sql => "o.SubObject_Name"}
      when :Current_Obj_No              then {:name => 'Current_Obj_No',              :sql => "s.Current_Obj_No"}
      when :User_ID                     then {:name => 'User-ID',                     :sql => "s.User_ID"}
      when :Additional_Filter           then {:name => 'Additional Filter',           :sql => "UPPER(u.UserName||s.Session_ID||s.SQL_ID||s.Module||s.Action||o.Object_Name||s.Program#{get_db_version >= '11.2' ? '|| s.Machine' : ''}||s.SQL_Plan_Hash_Value) LIKE UPPER('%'||?||'%')", :already_bound => true }  # Such-Filter
      when :Temp_Usage_MB_greater       then {:name => 'TEMP-usage (MB) > x',         :sql => "s.Temp_Space_Allocated > ?*(1024*1024)", :already_bound => true}
      else                              { :name => session_statistics_key_rule(key.to_s)[:Name], :sql => session_statistics_key_rule(key.to_s)[:sql] }                              # 2. Versuch aus Liste der Gruppierungskriterien
    end
    
    raise "groupfilter_value: unknown key '#{key}' of class #{key.class.name}" unless retval
    retval = retval.clone                                                       # Entkoppeln von Quelle so dass Änderungen lokal bleiben
    unless retval[:already_bound]                                               # Muss Bindung noch hinzukommen?
      if value && value != ''
        retval[:sql] = "#{retval[:sql]} = ?"
      else
        #if retval[:sql]["?"]
        #  puts retval.to_s
        #end
        retval[:sql] = "#{retval[:sql]} IS NULL"
      end
    end

    retval
  end

  private
  # Ermitteln der Min- und Max-Abgrenzungen auf Basis Snap_ID für Zeitraum über alle Instanzen hinweg
  def get_min_max_snap_ids(time_selection_start, time_selection_end, dbid)
    @min_snap_id = sql_select_one ["SELECT /*+ Panorama-Tool Ramm */ MIN(Snap_ID)
                                    FROM   (SELECT MAX(Snap_ID) Snap_ID
                                            FROM   DBA_Hist_Snapshot
                                            WHERE DBID = ?
                                            AND Begin_Interval_Time <= TO_DATE(?, '#{sql_datetime_mask(time_selection_start)}')
                                            GROUP BY Instance_Number
                                           )
                                   ", dbid, time_selection_start
                                  ]
    unless @min_snap_id   # Start vor Beginn der Aufzeichnungen, dann kleinste existierende Snap-ID
      @min_snap_id = sql_select_one ['SELECT /*+ Panorama-Tool Ramm */ MIN(Snap_ID)
                                      FROM   DBA_Hist_Snapshot
                                      WHERE DBID = ?
                                     ', dbid
                                    ]
    end

    @max_snap_id = sql_select_one ["SELECT /*+ Panorama-Tool Ramm */ MAX(Snap_ID)
                                    FROM   (SELECT MIN(Snap_ID) Snap_ID
                                            FROM   DBA_Hist_Snapshot
                                            WHERE DBID = ?
                                            AND End_Interval_Time >= TO_DATE(?, '#{sql_datetime_mask(time_selection_end)}')
                                            GROUP BY Instance_Number
                                          )
                                   ", dbid, time_selection_end
                                  ]
    unless @max_snap_id       # Letzten bekannten Snapshot werten, wenn End-Zeitpunkt in der Zukunft liegt
      @max_snap_id = sql_select_one ['SELECT /*+ Panorama-Tool Ramm */ MAX(Snap_ID)
                                      FROM   DBA_Hist_Snapshot
                                      WHERE DBID = ?
                                     ', dbid
                                    ]
    end
  end

  public


  # Belegen des WHERE-Statements aus Hash mit Filter-Bedingungen und setzen Variablen
  def where_from_groupfilter (groupfilter, groupby)
    @groupfilter = groupfilter             # Instanzvariablen zur nachfolgenden Nutzung
    @groupfilter = @groupfilter.to_unsafe_h.to_h.symbolize_keys  if @groupfilter.class == ActionController::Parameters
    raise "Parameter groupfilter should be of class Hash or ActionController::Parameters" if @groupfilter.class != Hash
    @groupby    = groupby                  # Instanzvariablen zur nachfolgenden Nutzung
    @global_where_string  = ""             # Filter-Text für nachfolgendes Statement mit AND-Erweiterung für alle Union-Tabellen
    @global_where_values = []              # Filter-werte für nachfolgendes Statement für alle Union-Tabellen
    @dba_hist_where_string  = ""             # Filter-Text für nachfolgendes Statement mit AND-Erweiterung für DBA_Hist_Active_Sess_History
    @dba_hist_where_values = []              # Filter-werte für nachfolgendes Statement für DBA_Hist_Active_Sess_History

    @groupfilter.each do |key,value|
      @groupfilter.delete(key) if value.nil? || key == 'NULL'   # '' zulassen, da dies NULL signalisiert, Dummy-Werte ausblenden
      @groupfilter.delete(key) if value == '' && [:Min_Snap_ID, :Max_Snap_ID].include?(key)   # delete empty entries for keys without NULL-meaning
      @groupfilter[key] = value.strip if key == 'time_selection_start' || key == 'time_selection_end'                   # Whitespaces entfernen vom Rand des Zeitstempels
    end

    # Set Filter on Snap_ID for partition pruning on DBA_Hist_Active_Sess_History (if not already set)
    if !@groupfilter.has_key?(:Min_Snap_ID) || !@groupfilter.has_key?(:Max_Snap_ID)
      get_min_max_snap_ids(@groupfilter[:time_selection_start], @groupfilter[:time_selection_end], @groupfilter[:DBID])
      @groupfilter[:Min_Snap_ID] = @min_snap_id unless @groupfilter.has_key?(:Min_Snap_ID)
      @groupfilter[:Max_Snap_ID] = @max_snap_id unless @groupfilter.has_key?(:Max_Snap_ID)
    end

    @groupfilter.each {|key,value|
      sql = groupfilter_value(key, value)[:sql]
      if key == :DBID || key == :Min_Snap_ID || key == :Max_Snap_ID    # Werte nur gegen HistTabelle binden
        @dba_hist_where_string << " AND #{sql}"  # Filter weglassen, wenn nicht belegt
        if value && value != ''
          @dba_hist_where_values << value   # Wert nur binden wenn nicht im :sql auf NULL getestet wird
        else
          @dba_hist_where_values << 0                    # Wenn kein valides Alter festgestellt über DBA_Hist_Snapshot, dann reicht gv$Active_Session_History aus für Zugriff,
          @dba_hist_where_string << "/* Zugriff auf DBA_Hist_Active_Sess_History ausblenden, da kein Wert für #{key} gefunden wurde (alle Daten kommen aus gv$Active_Session_History)*/"
        end
      else                                # Werte für Hist- und gv$-Tabelle binden
        @global_where_string << " AND #{sql}"
        @global_where_values << value if value && value != ''  # Wert nur binden wenn nicht im :sql auf NULL getestet wird
      end
    }
  end # where_from_groupfilter

  # Gruppierungskriterien für list_temp_usage_historic
  def temp_historic_grouping_options
    if !defined?(@temp_historic_grouping_options_hash) || @temp_historic_grouping_options_hash.nil?
      @temp_historic_grouping_options_hash = {}
      @temp_historic_grouping_options_hash[:second] = t(:second, :default=>'Second')
      @temp_historic_grouping_options_hash[:minute] = 'Minute'
      @temp_historic_grouping_options_hash[:hour]   = t(:hour,  :default => 'Hour')
      @temp_historic_grouping_options_hash[:day]    = t(:day,  :default => 'Day')
      @temp_historic_grouping_options_hash[:week]   = t(:week, :default => 'Week')
    end
    @temp_historic_grouping_options_hash
  end


end