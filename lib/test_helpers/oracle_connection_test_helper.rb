# requires config/environment.rb loaded a'la: require File.expand_path("../../test/dummy/config/environment.rb", __FILE__)

class ActiveSupport::TestCase
  include ApplicationHelper
  include EnvHelper
  include ActionView::Helpers::TranslationHelper

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...

  # Sicherstellen, dass immer auf ein aktuelles Sessin-Objekt zurückgegriffern werden kann
  def session
    @session
  end

  #def cookies
  #  {:client_key => 100 }
  #end


  # Method shared with Panorama children
  def connect_oracle_db_internal(test_config)
    test_url = test_config['test_url'].split(":")

    current_database = {}
    current_database[:modus]        = 'host'

    current_database[:host]         = test_url[3].delete "@"
    if test_url[4]['/']                                                         # Service_Name
      current_database[:port]       = test_url[4].split('/')[0]
      current_database[:sid]        = test_url[4].split('/')[1]

      current_database[:sid_usage]  = :SERVICE_NAME
    else                                                                        # SID
      current_database[:port]       = test_url[4]
      current_database[:sid]        = test_url[5]
      current_database[:sid_usage]  = :SID
    end

    current_database[:user]         = test_config["test_username"]
    current_database[:tns]          = test_config['test_url'].split('@')[1]     # Alles nach jdbc:oracle:thin@
    current_database[:management_pack_license] = :diagnostic_and_tuning_pack    # Allow access on management packs

    # Config im Cachestore ablegen
    # Sicherstellen, dass ApplicationHelper.get_cached_client_key nicht erneut den client_key entschlüsseln will
    @@cached_encrypted_client_key = '100'
    @@cached_decrypted_client_key = '100'
    cookies[:client_key]          = '100'


    # Passwort verschlüsseln in session
    current_database[:password] = database_helper_encrypt_value(test_config["test_password"])
    write_to_client_info_store(:current_database, current_database)


    # puts "Test for #{ENV['DB_VERSION']} with #{database.user}/#{database.password}@#{database.host}:#{database.port}:#{database.sid}"
    open_oracle_connection                                                      # Connection zur Test-DB aufbauen, um Parameter auszulesen
    read_initial_db_values                                                      # evtl. Exception tritt erst beim ersten Zugriff auf

    # DBID is set at first request after login normally
    set_cached_dbid(sql_select_one("SELECT /* Panorama Tool Ramm */ DBID FROM v$Database"))

    set_I18n_locale('de')
  end

  def set_session_test_db_context
    Rails.logger.info ""
    Rails.logger.info "=========== test_helper.rb : set_session_test_db_context ==========="

    # Client Info store entfernen, da dieser mit anderem Schlüssel verschlüsselt sein kann
    #FileUtils.rm_rf(Application.config.client_info_filename)

    #initialize_client_key_cookie                                                # Ensure browser cookie for client_key exists
    connect_oracle_db
    sql_row = sql_select_first_row "SELECT /* Panorama-Tool Ramm */ SQL_ID, Child_Number, Parsing_Schema_Name
                                          FROM   v$SQL
                                          WHERE  RowNum < 2"
    @sga_sql_id = sql_row.sql_id
    @sga_child_number = sql_row.child_number
    @sga_parsing_schema_Name = sql_row.parsing_schema_name
    db_session = sql_select_first_row "select Inst_ID, SID, Serial# SerialNo, RawToHex(Saddr)Saddr FROM gV$Session s WHERE SID=UserEnv('SID')  AND Inst_ID = USERENV('INSTANCE')"
    @instance = db_session.inst_id
    @sid      = db_session.sid
    @serialno = db_session.serialno
    @saddr    = db_session.saddr

    yield   # Ausführen optionaler Blöcke mit Anweisungen, die gegen die Oracle-Connection verarbeitet werden

    # Rückstellen auf NullDB kann man sich hier sparen
  end
end