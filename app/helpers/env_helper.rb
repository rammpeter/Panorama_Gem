# encoding: utf-8

require "zlib"
require 'encryption'

module EnvHelper
  include DatabaseHelper

  def init_management_pack_license(current_database)
    if current_database[:management_pack_license].nil?                          # not already set, calculate initial value
      control_management_pack_access = read_control_management_pack_access
      return :diagnostics_and_tuning_pack  if control_management_pack_access['TUNING']
      return :diagnostics_pack             if control_management_pack_access['DIAGNOSTIC']
      return :panorama_sampler             if !current_database[:panorama_sampler_schema].nil?  # Use Panorama-Sampler as default if data exists
      return :none
    end
    return current_database[:management_pack_license]                           # Use old value if already set
  end

  def read_control_management_pack_access                                       # returns either NONE | DIAGNOSTIC | DIAGNOSTIC+TUNING
    sql_select_one "SELECT Value FROM V$Parameter WHERE name='control_management_pack_access'"  # ab Oracle 11 belegt
  end

  # Einlesen last_logins aus client_info-store
  def read_last_logins
=begin
    begin
      if cookies[:last_logins]
        #last_logins = Marshal.load(Zlib::Inflate.inflate(cookies[:last_logins]))
        cookies_last_logins = Marshal.load(cookies[:last_logins])
      else
        cookies_last_logins = []
      end
    rescue Exception => e
      Rails.logger.warn "read_last_login_cookies: #{e.message}"
      cookies_last_logins = []      # Cookie neu initialisieren wenn Fehler beim Auslesen
      write_last_logins(cookies_last_logins)   # Zurückschreiben in cookie-store
    end

    unless cookies_last_logins.instance_of?(Array)  # Falscher Typ des Cookies?
      cookies_last_logins = []
      write_last_logins(cookies_last_logins)   # Zurückschreiben in cookie-store
    end

    # Transformation der cookie-Kürzel in lesbare Bezeichner
    cookies_last_logins.map{|c| {:host=>c[:h], :port=>c[:p], :sid=>c[:s], :user=>c[:u], :password=>c[:w], :authorization=>c[:a], :sid_usage=>(c[:g]==1 ? :SID : :SERVICE_NAME)} }
=end
    last_logins = read_from_client_info_store(:last_logins)
    if last_logins.nil? || !last_logins.instance_of?(Array)
      last_logins = []
      write_last_logins(last_logins)   # Zurückschreiben in client_info-store
    end
    last_logins
  end

  # Zurückschreiben des logins in client_info_store
  def write_last_logins(last_logins)
=begin
    #compressed_cookie = Zlib::Deflate.deflate(Marshal.dump(last_logins))

    # Transformation der lesbaren Bezeichner in cookie-Kürzel
    write_cookie = last_logins.map {|o| {:h=>o[:host], :p=>o[:port], :s=>o[:sid], :u=>o[:user], :w=>o[:password], :a=>o[:authorization], :g=>(o[:sid_usage] == :SID ? 1 : 0) } }

    while Marshal.dump(write_cookie).length > 1500 do                           # Größe des Cookies überschreitet x kByte
      write_cookie.delete(write_cookie.last)                                    # Letzten Eintrag loeschen
    end

    compressed_cookie = Marshal.dump(write_cookie)
    cookies[:last_logins] = { :value => compressed_cookie, :expires => 1.year.from_now }
=end
    write_to_client_info_store(:last_logins, last_logins)
  end

  # Ensure client browser has unique client_key stored as cookie
  MAX_NEW_KEY_TRIES  = 1000
  def initialize_client_key_cookie
    if cookies['client_key']
      begin
        Encryption.decrypt_value(cookies['client_key'], cookies['client_salt']) # Test client_key-Cookie for possible decryption
      rescue Exception => e
        Rails.logger.error("Exception #{e.message} while database_helper_decrypt_value(cookies['client_key'])")
        cookies.delete('client_key')                                            # Verwerfen des nicht entschlüsselbaren Cookies
        cookies.delete('client_salt')
      end
    end

    unless cookies['client_key']                                                # Erster Zugriff in neu gestartetem Browser oder Cookie nicht mehr verfügbar
      loop_count = 0
      while loop_count < MAX_NEW_KEY_TRIES
        loop_count = loop_count+1
        new_client_key = rand(10000000)
        unless EngineConfig.get_client_info_store.exist?(new_client_key)                     # Dieser Key wurde noch nie genutzt
          # Salt immer mit belegen bei Vergabe des client_key, da es genutzt wird zur Verschlüsselung des Client_Key im cookie
          cookies['client_salt'] = { :value => rand(10000000000),                                                 :expires => 1.year.from_now }  # Lokaler Schlüsselbestandteil im Browser-Cookie des Clients, der mit genutzt wird zur Verschlüsselung der auf Server gespeicherten Login-Daten
          cookies['client_key']  = { :value => Encryption.encrypt_value(new_client_key, cookies['client_salt']),  :expires => 1.year.from_now }
          client_store = EngineConfig.get_client_info_store
          client_store.write(new_client_key, 1)                        # Marker fuer Verwendung des Client-Keys
          break
        end
      end
      raise "Cannot create client key after #{MAX_NEW_KEY_TRIES} tries" if loop_count >= MAX_NEW_KEY_TRIES
    else
      if cookies.class.name != 'Rack::Test::CookieJar'                          # Don't set Hash for cookies in test because it becomes String like ' { :value => 100, :expires => ... }'
        cookies['client_salt'] = { :value => cookies['client_salt'], :expires => 1.year.from_now }    # Timeout neu setzen bei Benutzung
        cookies['client_key']  = { :value => cookies['client_key'],  :expires => 1.year.from_now }    # Timeout neu setzen bei Benutzung
      end
    end
  end

  # Helper to distiguish browser tabs, sets @browser_tab_id
  def initialize_browser_tab_id
    tab_ids = read_from_client_info_store(:browser_tab_ids)
    tab_ids = {} if tab_ids.nil? || tab_ids.class != Hash
    @browser_tab_id = 1                                                         # Default tab-id if no other exists
    while tab_ids.key?(@browser_tab_id) do
      if tab_ids[@browser_tab_id].key?(:last_used) && tab_ids[@browser_tab_id][:last_used] < Time.now-1000000
        break
      end
      @browser_tab_id += 1

    end
    tab_ids[@browser_tab_id] = {} if !tab_ids.key?(@browser_tab_id)             # create Hash for browser tab if not already exsists
    tab_ids[@browser_tab_id][:last_used] = Time.now
    write_to_client_info_store(:browser_tab_ids, tab_ids)
  end

  # Einlesen und strukturieren der Datei tnsnames.ora
  def read_tnsnames
    if ENV['TNS_ADMIN']
      tnsadmin = ENV['TNS_ADMIN']
    else
      if ENV['ORACLE_HOME']
        tnsadmin = "#{ENV['ORACLE_HOME']}/network/admin"
      else
        logger.warn 'read_tnsnames: TNS_ADMIN or ORACLE_HOME not set in environment, no TNS names provided'
        return tnsnames # Leerer Hash
      end
    end

    read_tnsnames_internal( "#{tnsadmin}/tnsnames.ora" )

  rescue Exception => e
    Rails.logger.error "Error processing tnsnames.ora: #{e.message}"
    {}
  end

  def read_tnsnames_internal(file_name)
    tnsnames = {}

    fullstring = IO.read(file_name)
    fullstring.encode!(fullstring.encoding, :universal_newline => true)         # Ensure that Windows-Linefeeds 0D0A are replaced by 0A

    # Test for IFILE insertions
    fullstring_ifile = fullstring.clone                                         # local copy
    while true
      start_pos_ifile = fullstring_ifile.index('IFILE')
      break unless start_pos_ifile
      fullstring_ifile = fullstring_ifile[start_pos_ifile+5, 1000000]           # remove all before and including IFILE

      while fullstring_ifile[0].match '[= ]'                                    # remove = and blanks before filename
        fullstring_ifile = fullstring_ifile[1, 1000000]                         # remove first char of string
      end

      start_pos_ifile = fullstring_ifile.index("\n")
      if start_pos_ifile.nil?
        ifile_name = fullstring_ifile[0, 1000000]
      else
        ifile_name = fullstring_ifile[0, start_pos_ifile]
      end

      tnsnames.merge!(read_tnsnames_internal(ifile_name))
    end

    while true
      # Ermitteln TNSName
      start_pos_description = fullstring.index('DESCRIPTION')
      break unless start_pos_description                               # Abbruch, wenn kein weitere DESCRIPTION im String
      tns_name = fullstring[0..start_pos_description-1]
      while tns_name[tns_name.length-1,1].match '[=,\(, ,\n,\r]'            # Zeichen nach dem TNSName entfernen
        tns_name = tns_name[0, tns_name.length-1]                         # Letztes Zeichen des Strings entfernen
      end
      while tns_name.index("\n")                                        # Alle Zeilen vor der mit DESCRIPTION entfernen
        tns_name = tns_name[tns_name.index("\n")+1, 10000]                # Wert akzeptieren nach Linefeed wenn enthalten
      end
      fullstring = fullstring[start_pos_description + 10, 1000000]     # Rest des Strings fuer weitere Verarbeitung

      next if tns_name[0,1] == "#"                                              # Auskommentierte Zeile

      # ermitteln Hostname
      start_pos_host = fullstring.index('HOST')
      # Naechster Block mit Description beginnen wenn kein Host enthalten oder in naechster Description gefunden
      next if start_pos_host==nil || (fullstring.index('DESCRIPTION') && fullstring.index('DESCRIPTION')<start_pos_host)    # Alle weiteren Treffer muessen vor der naechsten Description liegen
      fullstring = fullstring[start_pos_host + 5, 1000000]
      hostName = fullstring[0..fullstring.index(')')-1]
      hostName = hostName.delete(' ').delete('=') # Entfernen Blank u.s.w

      # ermitteln Port
      start_pos_port = fullstring.index('PORT')
      # Naechster Block mit Description beginnen wenn kein Port enthalten oder in naechster Description gefunden
      next if start_pos_port==nil || (fullstring.index('DESCRIPTION') && fullstring.index('DESCRIPTION')<start_pos_port) # Alle weiteren Treffer muessen vor der naechsten Description liegen
      fullstring = fullstring[start_pos_port + 5, 1000000]
      port = fullstring[0..fullstring.index(')')-1]
      port = port.delete(' ').delete('=')      # Entfernen Blank u.s.w.

      # ermitteln SID oder alternativ Instance_Name oder Service_Name
      sid_tag_length = 4
      sid_usage = :SID
      start_pos_sid = fullstring.index('SID=')                                  # i.d.R. folgt unmittelbar ein "="
      start_pos_sid = fullstring.index('SID ') if start_pos_sid.nil?            # evtl. " " zwischen SID und "="
      if start_pos_sid.nil? || (fullstring.index('DESCRIPTION') && fullstring.index('DESCRIPTION')<start_pos_sid) # Alle weiteren Treffer muessen vor der naechsten Description liegen
        sid_tag_length = 12
        sid_usage = :SERVICE_NAME
        start_pos_sid = fullstring.index('SERVICE_NAME')
      end
      # Naechster Block mit Description beginnen wenn kein SID enthalten oder in naechster Description gefunden
      next if start_pos_sid==nil || (fullstring.index('DESCRIPTION') && fullstring.index('DESCRIPTION')<start_pos_sid) # Alle weiteren Treffer muessen vor der naechsten Description liegen
      fullstring = fullstring[start_pos_sid + sid_tag_length, 1000000]               # Rest des Strings fuer weitere Verarbeitung

      sidName = fullstring[0..fullstring.index(')')-1]
      sidName = sidName.delete(' ').delete('=')   # Entfernen Blank u.s.w.

      # Kompletter Record gefunden
      tnsnames[tns_name] = {:hostName => hostName, :port => port, :sidName => sidName, :sidUsage =>sid_usage }
    end
    tnsnames
  rescue Exception => e
    Rails.logger.error "Error processing #{file_name}: #{e.message}"
    tnsnames
  end
end