# requires config/environment.rb loaded a'la: require File.expand_path("../../test/dummy/config/environment.rb", __FILE__)
require 'encryption'

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

  def controller_name                                                           # Dummy to fulfill requirements of set_connection_info_for_request
    'oracle_connection_test_helper.rb'
  end

  def action_name                                                               # Dummy to fulfill requirements of set_connection_info_for_request
    'Test'
  end

  #def cookies
  #  {:client_key => 100 }
  #end

  def management_pack_license
    if ENV['MANAGEMENT_PACK_LICENSE']
      raise "Wrong environment value MANAGEMENT_PACK_LICENSE=#{ENV['MANAGEMENT_PACK_LICENSE']}" if !['diagnostics_pack', 'diagnostics_and_tuning_pack', 'panorama_sampler', 'none'].include?(ENV['MANAGEMENT_PACK_LICENSE'])
      ENV['MANAGEMENT_PACK_LICENSE'].to_sym
    else
      :diagnostics_and_tuning_pack  # Allow access on management packs, Default if nothing else specified
    end
  end

  def create_prepared_database_config(test_config)
    db_config = {}

    raise "Missing entry test_url in Hash" if !test_config.has_key?(:test_url)
    test_url = test_config[:test_url].split(":")
    db_config[:modus]        = 'host'

    db_config[:host]         = test_url[3].delete "@"
    if test_url[4]['/']                                                         # Service_Name
      db_config[:port]       = test_url[4].split('/')[0]
      db_config[:sid]        = test_url[4].split('/')[1]

      db_config[:sid_usage]  = :SERVICE_NAME
    else                                                                        # SID
      db_config[:port]       = test_url[4]
      db_config[:sid]        = test_url[5]
      db_config[:sid_usage]  = :SID
    end

    db_config[:user]         = test_config[:test_username]
    db_config[:panorama_sampler_schema] = db_config[:user]                      # Use test user for panorama-sampler
    db_config[:tns]          = test_config[:test_url].split('@')[1]     # Alles nach jdbc:oracle:thin@
    db_config[:privilege]    = 'normal'

    db_config[:management_pack_license] = management_pack_license

    #puts 'Database config for test is:'
    #puts db_config.inspect

    db_config
  end

  # Method shared with Panorama children
  def connect_oracle_db_internal(test_config)
    current_database = create_prepared_database_config(test_config)

    # Config im Cachestore ablegen
    # Sicherstellen, dass ApplicationHelper.get_cached_client_key nicht erneut den client_key entschlüsseln will
    initialize_client_key_cookie

    # Passwort verschlüsseln in session
    current_database[:password] = Encryption.encrypt_value(test_config[:test_password], cookies['client_salt'])

    @browser_tab_id = 1
    browser_tab_ids = { @browser_tab_id => {
        current_database: current_database,
        last_used: Time.now
    }
    }
    write_to_client_info_store(:browser_tab_ids, browser_tab_ids)


    # TODO Sollte so nicht mehr notwendig sein
    #open_oracle_connection                                                      # Connection zur Test-DB aufbauen, um Parameter auszulesen
    set_connection_info_for_request(current_database)

    # DBID is set at first request after login normally
    set_cached_dbid(PanoramaConnection.dbid)

    set_I18n_locale('de')
  end

  def set_session_test_db_context
    message = "#{Time.now} : #{self.class}.#{self.name} started"
    #puts message

    # Client Info store entfernen, da dieser mit anderem Schlüssel verschlüsselt sein kann
    #FileUtils.rm_rf(Application.config.client_info_filename)

    #initialize_client_key_cookie                                                # Ensure browser cookie for client_key exists

    # 2017/07/26 cookies are reset in ActionDispatch::IntegrationTest if using initialize_client_key_cookie
    cookies['client_salt'] = 100
    cookies['client_key']  = Encryption.encrypt_value(100, cookies['client_salt'])

    connect_oracle_db

    db_session = sql_select_first_row "select Inst_ID, SID, Serial# SerialNo, RawToHex(Saddr)Saddr FROM gV$Session s WHERE SID=UserEnv('SID')  AND Inst_ID = USERENV('INSTANCE')"
    @instance = db_session.inst_id
    @sid      = db_session.sid
    @serialno = db_session.serialno
    @saddr    = db_session.saddr

    ensure_panorama_sampler_tables_exist_with_content if management_pack_license == :panorama_sampler

    yield if block_given?                                                       # Ausführen optionaler Blöcke mit Anweisungen, die gegen die Oracle-Connection verarbeitet werden

    # Rückstellen auf NullDB kann man sich hier sparen
  end

  def ensure_panorama_sampler_tables_exist_with_content
    sampler_config = prepare_panorama_sampler_thread_db_config

    begin
      snapshots = sql_select_one "SELECT COUNT(*) FROM Panorama_Snapshot"
    rescue Exception                                                                     # Table does not yet exist
      PanoramaSamplerStructureCheck.do_check(sampler_config, :AWR)
      PanoramaSamplerStructureCheck.do_check(sampler_config, :ASH)
      snapshots = sql_select_one "SELECT COUNT(*) FROM Panorama_Snapshot"
    end
    if snapshots < 4
      WorkerThread.new(sampler_config, 'ensure_panorama_sampler_tables_exist_with_content').create_snapshot_internal(Time.now.round, :AWR) # Tables must be created before snapshot., first snapshot initialization called
      3.times do
        sleep(20)
        WorkerThread.new(sampler_config, 'ensure_panorama_sampler_tables_exist_with_content').create_snapshot_internal(Time.now.round, :AWR) # Tables must be created before snapshot., first snapshot initialization called
      end
    end
  end

  def initialize_min_max_snap_id_and_times
    # Get 2 subsequent snapshots in the middle of 4 snapshots with same startup time
    snaps = sql_select_all "SELECT *
                            FROM   (
                                    SELECT x.*, RowNum Row_Num
                                    FROM   (
                                            SELECT s.*,
                                                   LAG(Startup_Time, 1, NULL) OVER (PARTITION BY Instance_Number ORDER BY Snap_ID) Startup_1,
                                                   LAG(Startup_Time, 2, NULL) OVER (PARTITION BY Instance_Number ORDER BY Snap_ID) Startup_2,
                                                   LAG(Startup_Time, 3, NULL) OVER (PARTITION BY Instance_Number ORDER BY Snap_ID) Startup_3
                                            FROM   DBA_Hist_Snapshot s
                                            WHERE  Instance_Number = 1
                                            ORDER BY Snap_ID DESC
                                           ) x
                                    WHERE  Startup_Time = Startup_1
                                    AND    Startup_Time = Startup_2
                                    AND    Startup_Time = Startup_3
                                     ORDER BY Snap_ID DESC
                                   )
                            WHERE  Row_Num IN (2,3)
                            "

    if snaps.count < 2
      message = "No 4 subsequent snapshots with same startup_time found in #{PanoramaSamplerStructureCheck.adjust_table_name('DBA_Hist_Snapshot')} (only #{snaps.count} snapshots found)"
      puts message

      last_10_snaps = sql_select_all "SELECT *
                                      FROM   (SELECT *
                                              FROM DBA_Hist_Snapshot
                                              ORDER BY Begin_Interval_Time DESC
                                             )
                                      WHERE RowNum <= 10"

      puts "Last 10 snapshots are:"
      last_10_snaps.each do |s|
        puts "Snap_ID = #{s.snap_id}, Instance = #{s.instance_number}, Begin_Interval_Time = #{localeDateTime(s.begin_interval_time)}"
      end
      raise message
    end

    @min_snap_id = snaps[1].snap_id
    @max_snap_id = snaps[0].snap_id

    @time_selection_start = (snaps[1].begin_interval_time-1).strftime("%d.%m.%Y %H:%M")
    @time_selection_end   = snaps[0].end_interval_time.strftime("%d.%m.%Y %H:%M")
  end
end
