# encoding: utf-8

require 'application_controller'
require 'menu_helper'
require 'licensing_helper'
require 'java'

# version.rb not include wile using gem from http://github.com
require "panorama_gem/version"

class EnvController < ApplicationController
  layout 'application'
#  include ApplicationHelper       # application_helper leider nicht automatisch inkludiert bei Nutzung als Engine in anderer App
  include EnvHelper
  include MenuHelper
  include LicensingHelper

  # Verhindern "ActionController::InvalidAuthenticityToken" bei erstem Aufruf der Seite und im Test
  protect_from_forgery :except => :index unless Rails.env.test?

  public
  # Einstieg in die Applikation, rendert nur das layout (default.rhtml), sonst nichts
  def index
    # Ensure client browser has unique client_key stored as cookie (create new one if not already exists)
    initialize_client_key_cookie

    set_I18n_locale('en') if get_locale.nil?                                    # Locale not yet specified, set default

    # Entfernen evtl. bisheriger Bestandteile des Session-Cookies
    cookies.delete(:locale)                         if cookies[:locale]
    cookies.delete(:last_logins)                    if cookies[:last_logins]
    session.delete(:locale)                         if session[:locale]
    session.delete(:last_used_menu_controller)      if session[:last_used_menu_controller]
    session.delete(:last_used_menu_action)          if session[:last_used_menu_action]
    session.delete(:last_used_menu_caption)         if session[:last_used_menu_caption]
    session.delete(:last_used_menu_hint)            if session[:last_used_menu_hint]
    session.delete(:database)                       if session[:database]
    session.delete(:dbid)                           if session[:dbid]
    session.delete(:version)                        if session[:version]
    session.delete(:db_block_size)                  if session[:db_block_size]
    session.delete(:wordsize)                       if session[:wordsize]
    session.delete(:dba_hist_cache_objects_owner)   if session[:dba_hist_cache_objects_owner]
    session.delete(:dba_hist_blocking_locks_owner)  if session[:dba_hist_blocking_locks_owner]
    session.delete(:request_counter)                if session[:request_counter]
    session.delete(:instance)                       if session[:instance]
    session.delete(:time_selection_start)           if session[:time_selection_start]
    session.delete(:time_selection_end)             if session[:time_selection_end]


    #set_I18n_locale(get_locale)                                                 # ruft u.a. I18n.locale = get_locale auf

    write_to_client_info_store(:last_used_menu_controller,  'env')
    write_to_client_info_store(:last_used_menu_action,      'index')
    write_to_client_info_store(:last_used_menu_caption,     'Start')
    write_to_client_info_store(:last_used_menu_hint,        t(:menu_env_index_hint, :default=>"Start of application without connect to database"))

    @panorama_session_key = rand(10000000)                                      # Unique key to distinguish multiple tabs or windows of one browser instance

  rescue Exception=>e
    Rails.logger.error("#{e.message}")
    set_current_database(nil) if !cookies['client_key'].nil?                    # Sicherstellen, dass bei naechstem Aufruf neuer Einstieg (nur wenn client_info_store bereits initialisiert ist)
    raise e                                                                     # Werfen der Exception
  end

  # Auffüllen SELECT mit OPTION aus tns-Records
  def get_tnsnames_records
    tnsnames = read_tnsnames

    result = ''
    tnsnames.keys.sort.each do |key|
      result << "jQuery('#database_tns').append('<option value=\"#{key}\">'+rpad('#{key}', 180, 'database_tns')+'&nbsp;&nbsp;#{tnsnames[key][:hostName]} : #{tnsnames[key][:port]} : #{tnsnames[key][:sidName]}</value>');\n"
    end

    respond_to do |format|
      format.js {render :js => result }
    end
  end

  # Wechsel der Sprache in Anmeldedialog
  def set_locale
    set_I18n_locale(params[:locale])                                            # Merken in Client_Info_Cache

    respond_to do |format|
      format.js {render :js => "window.location.reload();" }                    # Reload der ganzen Seite
    end
  end

  # start page called after login and management pack choice
  def start_page

    @dictionary_access_msg = ""       # wird additiv belegt in Folge
    @dictionary_access_problem = false    # Default, keine Fehler bei Zugriff auf Dictionary
    begin
      @banners       = []   # Vorbelegung,damit bei Exception trotzdem valider Wert in Variable
      @instance_data = []   # Vorbelegung,damit bei Exception trotzdem valider Wert in Variable
      @version_info  = []   # Vorbelegung,damit bei Exception trotzdem valider Wert in Variable
      # Einlesen der DBID der Database, gleichzeitig Test auf Zugriffsrecht auf DataDictionary
      read_initial_db_values

      # Data for DB versions
      @version_info = sql_select_all "SELECT /* Panorama Tool Ramm */ Banner FROM V$Version"
      @database_info = sql_select_first_row "SELECT /* Panorama Tool Ramm */ Name, Platform_name, Created, dbtimezone, SYSDATE FROM v$Database"  # Zugriff ueber Hash, da die Spalte nur in Oracle-Version > 9 existiert


      client_info = sql_select_first_row "SELECT sys_context('USERENV', 'NLS_DATE_LANGUAGE') || '_' || sys_context('USERENV', 'NLS_TERRITORY') NLS_Lang FROM DUAL"

      @version_info << ({:banner => "Platform: #{@database_info.platform_name}" }.extend SelectHashHelper)

      if get_db_version >= '11.2'
        exadata_info = sql_select_first_row "SELECT COUNT(*) Cell_Count FROM (SELECT cellname FROM v$Cell_Config GROUP BY CellName)"
        @version_info << ({:banner => "Machine: EXADATA with #{exadata_info.cell_count} storage cell server" }.extend SelectHashHelper) if exadata_info.cell_count > 0
      end

      if get_db_version >= '12.1'
        oracle_home = sql_select_one "SELECT SYS_CONTEXT ('USERENV','ORACLE_HOME') FROM DUAL"
        @version_info << ({:banner => "ORACLE_HOME: '#{oracle_home}'" }.extend SelectHashHelper)
      end

      @version_info << ({:banner => "DB timezone offset: #{@database_info.dbtimezone}", :client_info=>"SYSDATE = '#{localeDateTime(@database_info.sysdate)}'" }.extend SelectHashHelper)

      @version_info.each {|vi| vi[:client_info] = nil if vi[:client_info].nil? }                         # each row should have this column defined
      @version_info[0][:client_info] = "JDBC connect string = \"#{jdbc_thin_url}\""                                                                           if @version_info.count > 0
      @version_info[1][:client_info] = "JDBC driver version = \"#{ConnectionHolder.get_jdbc_driver_version}\""                                                if @version_info.count > 1
      @version_info[2][:client_info] = "Client time zone = \"#{java.util.TimeZone.get_default.get_id}\", #{java.util.TimeZone.get_default.get_display_name}"  if @version_info.count > 2
      @version_info[3][:client_info] = "Client NLS setting = \"#{client_info.nls_lang}\""                                                                        if @version_info.count > 3



      @instance_data = sql_select_all ["SELECT /* Panorama Tool Ramm */ gi.*, i.Instance_Number Instance_Connected,
                                                      (SELECT n.Value FROM gv$NLS_Parameters n WHERE n.Inst_ID = gi.Inst_ID AND n.Parameter='NLS_CHARACTERSET') NLS_CharacterSet,
                                                      (SELECT n.Value FROM gv$NLS_Parameters n WHERE n.Inst_ID = gi.Inst_ID AND n.Parameter='NLS_NCHAR_CHARACTERSET') NLS_NChar_CharacterSet,
                                                      (SELECT p.Value FROM GV$Parameter p WHERE p.Inst_ID = gi.Inst_ID AND LOWER(p.Name) = 'cpu_count') CPU_Count,
                                                      d.Open_Mode, d.Protection_Mode, d.Protection_Level, d.Switchover_Status, d.Dataguard_Broker, d.Force_Logging,
                                                      ws.Snap_Interval_Minutes, ws.Snap_Retention_Days
                                                      #{", CDB" if get_db_version >= '12.1'}
                                               FROM  GV$Instance gi
                                               CROSS JOIN  v$Database d
                                               LEFT OUTER JOIN v$Instance i ON i.Instance_Number = gi.Instance_Number
                                               #{
      if PackLicense.diagnostic_pack_licensed?(get_current_database[:management_pack_license])
        "LEFT OUTER JOIN (SELECT DBID, MIN(EXTRACT(HOUR FROM Snap_Interval))*60 + MIN(EXTRACT(MINUTE FROM Snap_Interval)) Snap_Interval_Minutes, MIN(EXTRACT(DAY FROM Retention)) Snap_Retention_Days FROM DBA_Hist_WR_Control GROUP BY DBID) ws ON ws.DBID = d.DBID"
      else
        "CROSS JOIN (SELECT NULL Snap_Interval_Minutes, NULL Snap_Retention_Days FROM DUAL) ws"
      end
      }

                                       "]
      @instance_data.each do |i|
        if i.instance_connected
          @instance_name = i.instance_name
          @host_name     = i.host_name
          set_current_database(get_current_database.merge({:cdb => true})) if get_db_version >= '12.1' && i.cdb == 'YES'  # Merken ob DB eine CDP/PDB ist
        end
      end
      if get_current_database[:cdb]
        @containers = sql_select_all "SELECT c.*, s.Con_ID Connected_Con_ID
                                      FROM   gv$Containers c
                                      JOIN   v$session s ON audsid = userenv('sessionid')
                                     "
      end
    rescue Exception => e
      Rails.logger.error "Exception: #{e.message}"
      curr_line_no=0
      e.backtrace.each do |bt|
        Rails.logger.error bt if curr_line_no < 20                                # report First 20 lines of stacktrace in log
        curr_line_no += 1
      end

      raise "Your user is missing SELECT-right on gv$Instance, gv$Database.\nPlease ensure that your user has granted SELECT ANY DICTIONARY.\nPanorama is not usable with this user account!\n\n #{e.message}"
    end

    @dictionary_access_problem = true unless select_any_dictionary?(@dictionary_access_msg)
    @dictionary_access_problem = true unless x_memory_table_accessible?("BH", @dictionary_access_msg )

    render_partial :start_page, {:additional_javascript_string => "$('#main_menu').html('#{j render_to_string :partial =>"build_main_menu" }');" }  # Wait until all loogon jobs are processed before showing menu

  end

  # Aufgerufen aus dem Anmelde-Dialog für gemerkte DB-Connections
  def set_database_by_id
    if params[:login]                                                           # Button Login gedrückt
      params[:database] = read_last_logins[params[:saved_logins_id].to_i]   # Position des aktuell ausgewählten in Array

      params[:database][:query_timeout] = 360 unless params[:database][:query_timeout]  # Initialize if stored login dies not contain query_timeout

      raise "env_controller.set_database_by_id: No database found to login! Please use direct login!" unless params[:database]
      set_database
    end

    if params[:delete]                                                          # Button DELETE gedrückt, Entfernen des aktuell selektierten Eintrages aus Liste der gespeicherten Logins
      last_logins = read_last_logins
      last_logins.delete_at(params[:saved_logins_id].to_i)

      write_last_logins(last_logins)
      respond_to do |format|
        format.js {render :js => "window.location.reload();" }                  # Neuladen der gesamten HTML-Seite, damit Entfernung des Eintrages auch sichtbar wird
      end
    end

  end

  # Aufgerufen aus dem Anmelde-Dialog für DB mit Angabe der Login-Info
  def set_database_by_params
    # Passwort sofort verschlüsseln als erstes und nur in verschlüsselter Form in session-Hash speichern
    params[:database][:password]  = database_helper_encrypt_value(params[:database][:password])

    #set_I18n_locale(params[:database][:locale])  # locale is set directly before, use this
    set_database(true)
  end



  private

  # Test auf Lesbarkeit von X$-Tabellen
  def x_memory_table_accessible?(table_name_suffix, msg)
    begin
      sql_select_all "SELECT /* Panorama Tool Ramm */ * FROM X$#{table_name_suffix} WHERE RowNum < 1"
      return true
    rescue Exception => e
      msg << "<div>#{t(:env_set_database_xmem_line1, :user=>get_current_database[:user], :table_name_suffix=>table_name_suffix, :default=>'DB-User %{user} has no right to read on X$%{table_name_suffix} ! Therefore a very small number of functions of Panorama is not usable!')}<br/>"
      msg << "<a href='#' onclick=\"jQuery('#xbh_workaround').show(); return false;\">#{t(:moeglicher, :default=>'possible')} workaround:</a><br/>"
      msg << "<div id='xbh_workaround' style='display:none; background-color: lightyellow; padding: 20px;'>"
      msg << "#{t(:env_set_database_xmem_line2, :default=>'Alternative 1: Connect with role SYSDABA')}<br/>"
      msg << "#{t(:env_set_database_xmem_line3, :default=>'Alternative 2: Execute as user SYS')}<br/>"
      msg << "> create view X_$#{table_name_suffix} as select * from X$#{table_name_suffix};<br/>"
      msg << "> create public synonym X$#{table_name_suffix} for sys.X_$#{table_name_suffix};<br/>"
      msg << t(:env_set_database_xmem_line4, :table_name_suffix=>table_name_suffix, :default=>'This way X$%{table_name_suffix} becomes available with role SELECT ANY DICTIONARY')
      msg << "</div>"
      msg << "</div>"
      return false
    end
  end

  def select_any_dictionary?(msg)
    if sql_select_one("SELECT COUNT(*) FROM Session_Privs WHERE Privilege = 'SELECT ANY DICTIONARY'") == 0
      msg << t(:env_set_database_select_any_dictionary_msg, :user=>get_current_database[:user], :default=>"DB-User %{user} doesn't have the grant 'SELECT ANY DICTIONARY'! Many functions of Panorama may be not usable!<br>")
      false
    else
      true
    end
  end

  def get_host_tns(current_database)                                            # JDBC-URL for host/port/sid
    sid_separator = case current_database[:sid_usage].to_sym
                      when :SID then          ':'
                      when :SERVICE_NAME then '/'
                      else raise "Unknown value '#{current_database[:sid_usage]}' for :sid_usage"
                    end
    connect_prefix = current_database[:sid_usage].to_sym==:SERVICE_NAME ? '//' : ''                 # only for service name // is needed at first
    "#{connect_prefix}#{current_database[:host]}:#{current_database[:port]}#{sid_separator}#{current_database[:sid]}"   # Evtl. existierenden TNS-String mit Angaben von Host etc. ueberschreiben
  end

  public

  # Erstes Anmelden an DB
  # Wurde direkt aus Browser aufgerufen oder per set_database_by_params_called?
  def set_database(called_from_set_database_by_params = false)

    write_to_client_info_store(:last_used_menu_controller, "env")
    write_to_client_info_store(:last_used_menu_action,     "set_database")
    write_to_client_info_store(:last_used_menu_caption,    "Login")
    write_to_client_info_store(:last_used_menu_hint,       t(:menu_env_set_database_hint, :default=>"Start of application after connect to database"))



    #current_database = params[:database].to_h.symbolize_keys                   # Puffern in lokaler Variable, bevor in client_info-Cache geschrieben wird
    current_database = params[:database]                                        # Puffern in lokaler Variable, bevor in client_info-Cache geschrieben wird
    current_database[:save_login] = current_database[:save_login] == '1' if called_from_set_database_by_params # Store as bool instead of number fist time after login

    @show_management_plan_choice =  current_database[:management_pack_license].nil?          # show choice for management pack if first login to database or stored login does not contain the choice

    if current_database[:modus] == 'tns'                                        # TNS-Alias auswerten
      tns_records = read_tnsnames                                               # Hash mit Attributen aus tnsnames.ora für gesuchte DB
      tns_record = tns_records[current_database[:tns]]
      unless tns_record
        respond_to do |format|
          format.js {render :js => "show_status_bar_message('Entry for DB \"#{current_database[:tns]}\" not found in tnsnames.ora');
                                    jQuery('#login_dialog').effect('shake', { times:3 }, 100);
                                   "
          }
        end
        set_dummy_db_connection
        return
      end
      # Alternative settings for connection if connect with current_database[:modus] == 'tns' does not work
      current_database[:host]       = tns_record[:hostName]
      current_database[:port]       = tns_record[:port]
      current_database[:sid]        = tns_record[:sidName]
      current_database[:sid_usage]  = tns_record[:sidUsage]
    else # Host, Port, SID auswerten
      current_database[:tns]       = get_host_tns(current_database)             # Evtl. existierenden TNS-String mit Angaben von Host etc. ueberschreiben
    end

    # Temporaerer Schutz des Produktionszuganges bis zur Implementierung LDAP-Autorisierung    
    if current_database[:host].upcase.rindex("DM03-SCAN") && current_database[:sid].upcase.rindex("NOADB")
      if params[:database][:authorization]== nil  || params[:database][:authorization]==""
        respond_to do |format|
          format.js {render :js => "show_status_bar_message('zusätzliche Autorisierung erforderlich fuer CORE-Produktionssystem');
                                    jQuery('#login_dialog_authorization').show();
                                    jQuery('#login_dialog').effect('shake', { times:3 }, 100);
                                   "
          }
        end
        set_dummy_db_connection
        return
      end
      if params[:database][:authorization]== nil || params[:database][:authorization]!="meyer"
        respond_to do |format|
          format.js {render :js => "show_status_bar_message('Autorisierung \"#{params[:database][:authorization]}\" ungueltig fuer CORE-Produktionssystem');
                                    jQuery('#login_dialog').effect('shake', { times:3 }, 100);
                                   "
          }
        end
        set_dummy_db_connection
        return
      end
    end

    set_current_database(current_database)                                      # Persist current database setting in cache
    current_database = nil                                                      # Diese Variable nicht mehr verwenden ab jetzt, statt dessen get_current_database verwenden

    # First SQL execution opens Oracle-Connection

    # Test der Connection und ruecksetzen auf vorherige wenn fehlschlaegt
    begin
      if get_current_database[:modus] == 'tns'
        begin
          sql_select_one "SELECT /* Panorama Tool Ramm */ SYSDATE FROM DUAL"    # Connect with TNS-Alias has second try if does not function
        rescue Exception => e                                                   # Switch to host/port/sid instead
          Rails.logger.error "Error connecting to database: URL='#{jdbc_thin_url}' TNSName='#{get_current_database[:tns]}' User='#{get_current_database[:user]}'"
          Rails.logger.error e.message
          e.backtrace.each do |bt|
            Rails.logger.error bt
          end

          set_current_database(get_current_database.merge({:modus => 'host', :tns => get_host_tns(get_current_database)}))
          Rails.logger.info "Second try to connect with host/port/sid instead of TNS-alias: URL='#{jdbc_thin_url}' TNSName='#{get_current_database[:tns]}' User='#{get_current_database[:user]}'"
          sql_select_one "SELECT /* Panorama Tool Ramm */ SYSDATE FROM DUAL"    # Connect with host/port/sid as second try if does not function
        end
      else
        sql_select_one "SELECT /* Panorama Tool Ramm */ SYSDATE FROM DUAL"      # Connect with host/port/sid should function at first try
      end
    rescue Exception => e
      Rails.logger.error "Error connecting to database: URL='#{jdbc_thin_url}' TNSName='#{get_current_database[:tns]}' User='#{get_current_database[:user]}'"
      Rails.logger.error e.message
      e.backtrace.each do |bt|
        Rails.logger.error bt
      end

      set_dummy_db_connection
      respond_to do |format|
#        format.html {render :html => "#{t(:env_connect_error, :default=>'Error connecting to database')}: <br/>
#                                                                      #{e.message}<br/><br/>
#                                                                      URL:  '#{jdbc_thin_url}'<br/>
#                                                                      Timezone: \"#{java.util.TimeZone.get_default.get_id}\", #{java.util.TimeZone.get_default.get_display_name}
#                                                                      <script type='text/javascript'>$('#login_dialog').effect('shake', { times:3 }, 100);</script>
#                                                                     ".html_safe
        format.js {render :js => "show_status_bar_message('#{
                                          my_html_escape("#{
t(:env_connect_error, :default=>'Error connecting to database')}:
#{e.message}

JDBC URL:  '#{jdbc_thin_url}'
Client Timezone: \"#{java.util.TimeZone.get_default.get_id}\", #{java.util.TimeZone.get_default.get_display_name}

                                                         ")
                                        }');
                                  jQuery('#login_dialog').effect('shake', { times:3 }, 300);
                                 "
        }
      end
      return        # Fehler-Ausgang
    end

    # Merken interner DB-Name und ohne erneuten DB-Zugriff
    set_current_database(get_current_database.merge( { :database_name => ConnectionHolder.current_database_name } ))
    write_connection_to_last_logins

    initialize_unique_area_id                                                   # Zaehler für eindeutige IDs ruecksetzen

    # Set management pack according to 'control_management_pack_access' only after DB selects,
    # Until now get_current_database[:management_pack_license] is nil for first time login, so no management pack license is violated until now
    # User has to acknowlede management pack licensing at next screen
    set_current_database(get_current_database.merge( {:management_pack_license  => init_management_pack_license(get_current_database) } ))


    timepicker_regional = ""
    if get_locale == "de"  # Deutsche Texte für DateTimePicker
      timepicker_regional = "prevText: '<zurück',
                                    nextText: 'Vor>',
                                    monthNames: ['Januar','Februar','März','April','Mai','Juni', 'Juli','August','September','Oktober','November','Dezember'],
                                    dayNamesMin: ['So','Mo','Di','Mi','Do','Fr','Sa'],
                                    timeText: 'Zeit',
                                    hourText: 'Stunde',
                                    minuteText: 'Minute',
                                    currentText: 'Jetzt',
                                    closeText: 'Auswählen',"
    end
    respond_to do |format|
      format.html {
        render_partial :choose_management_pack, :additional_javascript_string=>
                               "$('#current_tns').html('#{j "<span title='TNS=#{get_current_database[:tns]},\n#{"Host=#{get_current_database[:host]},\nPort=#{get_current_database[:port]},\n#{get_current_database[:sid_usage]}=#{get_current_database[:sid]},\n" if get_current_database[:modus].to_sym == :host}User=#{get_current_database[:user]}'>#{get_current_database[:user]}@#{get_current_database[:tns]}</span>"}');
                                $.timepicker.regional = { #{timepicker_regional}
                                    ampm: false,
                                    firstDay: 1,
                                    dateFormat: '#{timepicker_dateformat }'
                                 };
                                $.timepicker.setDefaults($.timepicker.regional);
                                $.datepicker.setDefaults({ firstDay: 1, dateFormat: '#{timepicker_dateformat }'});
                                numeric_decimal_separator = '#{numeric_decimal_separator}';
                                var session_locale = '#{get_locale}';
                                $('#login_dialog').dialog('close');
                                "
      }
    end
  rescue Exception=>e
    set_dummy_db_connection                                                     # Rückstellen auf neutrale DB
    raise e
  end






  # Rendern des zugehörigen Templates, wenn zugehörige Action nicht selbst existiert
  def render_menu_action
    # Template der eigentlichen Action rendern
    render_internal('content_for_layout', params[:redirect_controller], params[:redirect_action])
  end


private
  # Schreiben der aktuellen Connection in last logins, wenn neue dabei
  def write_connection_to_last_logins

    database = read_from_client_info_store(:current_database)

    last_logins = read_last_logins
    min_id = nil

    last_logins.each do |value|
      last_logins.delete(value) if value && value[:tns] == database[:tns] && value[:user] == database[:user]    # Aktuellen eintrag entfernen
    end
    if database[:save_login]
      last_logins = [database] + last_logins                                    # Neuen Eintrag an erster Stelle
      write_last_logins(last_logins)                                            # Zurückschreiben in client-info-store
    end

  end

  def persist_management_pack_license(management_pack_license)
    current_database = get_current_database
    current_database[:management_pack_license] = management_pack_license.to_sym
    set_current_database(current_database)
    write_connection_to_last_logins
  end

public

  # Process choosen management pack
  def choose_managent_pack_license
    persist_management_pack_license(params[:management_pack_license])
    start_page
  end

  def list_dbids
    if PackLicense.diagnostic_pack_licensed?(get_current_database[:management_pack_license])

      @dbids = sql_select_all ["SELECT s.DBID, MIN(Begin_Interval_Time) Min_TS, MAX(End_Interval_Time) Max_TS,
                                         (SELECT MIN(DB_Name) FROM DBA_Hist_Database_Instance i WHERE i.DBID=s.DBID) DB_Name,
                                         (SELECT COUNT(DISTINCT Instance_Number) FROM DBA_Hist_Database_Instance i WHERE i.DBID=s.DBID) Instances,
                                         MIN(EXTRACT(MINUTE FROM w.Snap_Interval)) Snap_Interval_Minutes,
                                         MIN(EXTRACT(DAY FROM w.Retention))        Snap_Retention_Days
                                  FROM   DBA_Hist_Snapshot s
                                  LEFT OUTER JOIN DBA_Hist_WR_Control w ON w.DBID = s.DBID
                                  GROUP BY s.DBID
                                  ORDER BY MIN(Begin_Interval_Time)"]

      set_new_dbid = true
      @dbids.each do |d|
        set_new_dbid = false if get_dbid == d.dbid                                # Reuse alread set dbid because it is valid
      end
      set_cached_dbid(sql_select_one("SELECT /* Panorama Tool Ramm */ DBID FROM v$Database")) if set_new_dbid # dbid has not been set or is not valid
    else
      @dbids = nil
    end

    render_partial :list_dbids
  end

  # DBID explizit setzen wenn mehrere verschiedene in Historie vorhande
  def set_dbid
    set_cached_dbid(params[:dbid])
    list_dbids
  end

  def list_management_pack_license
    @control_management_pack_access = read_control_management_pack_access       # ab Oracle 11 belegt

    render_partial :list_management_pack_license
  end

  def set_management_pack_license
    persist_management_pack_license(params[:management_pack_license])
    list_management_pack_license
  end

  # repeat last called menu action
  def repeat_last_menu_action
    controller_name = read_from_client_info_store(:last_used_menu_controller)
    action_name     = read_from_client_info_store(:last_used_menu_action)

    # Suchen des div im Menü-ul und simulieren eines clicks auf den Menü-Eintrag
    respond_to do |format|
      format.js {render :js => "$('#menu_#{controller_name}_#{action_name}').click();"}
    end
  end

  def list_machine_ip_info
    machine_name = params[:machine_name]

    resolver = Resolv::DNS.new
    result = "DNS-info for machine name \"#{machine_name}\":\\n"

    resolver.each_address(machine_name) do |address|
      result << "IP-address = #{address}\\n"
      resolver.each_name(address.to_s) do |name|
        result << "Name for IP-address \"#{address}\" = #{name}\\n"
      end
    end
    show_popup_message result
  end

  # Get arry with all engine's controller actions for routing
  def self.routing_actions(controller_dir)
    routing_list = []

    # Rails.logger.info "###### set routes for all controller methods in #{controller_dir}"
    Dir.glob("#{controller_dir}/*.rb") do |fname|
      controller_short_name = nil
      public_actions = true                                                       # following actions are public
      File.open(fname) do |f|
        f.each do |line|

          # find classname in file
          if line.match(/^ *class /)
            controller_name = line.split[1]
            controller_short_name = controller_name.underscore.gsub(/_controller/, '')
            # Rails.logger.info "set routes for all following methods in file #{fname} for #{controller_name}"
          end

          public_actions = true  if line.match(/^ *public */)
          public_actions = false if line.match(/^ *private */)

          # Find methods in file
          if line.match(/^ *def /)
            if !controller_short_name.nil?
              action_name = line.gsub(/\(/, ' ').split[1]
              if !action_name.match(/\?/) && public_actions && !action_name.match(/self\./)
                # set route for controllers action
                # Rails.logger.info "set route for #{controller_short_name}/#{action_name}"
                routing_list << {:controller => controller_short_name, :action => action_name}
                #get  "#{controller_short_name}/#{action_name}"
                #post "#{controller_short_name}/#{action_name}"

                # if controller is ApplicationController than set route for ApplicationController's methods for all controllers
              end
            end
          end
        end
      end
    end

    routing_list
  end

  def self.require_all_controller_and_helpers_and_models
    puts "########## Directory #{__dir__}"
    Dir.glob("#{__dir__}/*.rb")             {|fname| puts "require #{fname}"; require(fname) }
    Dir.glob("#{__dir__}/../helpers/*.rb")  {|fname| puts "require #{fname}"; require(fname) }
    Dir.glob("#{__dir__}/../models/*.rb")   {|fname| puts "require #{fname}"; require(fname) }
  end

end
