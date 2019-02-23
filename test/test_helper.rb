# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../../test/dummy/config/environment.rb", __FILE__)
#ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../test/dummy/db/migrate", __FILE__)]
#ActiveRecord::Migrator.migrations_paths << File.expand_path('../../db/migrate', __FILE__)
require "rails/test_help"

require 'fileutils'

require "minitest/reporters"

# Load own helpers
require File.expand_path("../../lib/test_helpers/oracle_connection_test_helper.rb", __FILE__)       # requires config/environment.rb loaded
require File.expand_path("../../lib/test_helpers/menu_test_helper.rb", __FILE__)
require File.expand_path("../../lib/test_helpers/application_system_test_case", __FILE__)

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.

# Ramm, auskommentiert 02.08.2017
#Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# Suppress the following error:
# ArgumentError: wrong number of arguments (1 for 0)
# aggregated_results at /home/ramm/.rvm/gems/jruby-9.1.7.0/gems/railties-5.0.1/lib/rails/test_unit/minitest_plugin.rb:597
# report at /home/ramm/.rvm/gems/jruby-9.1.7.0/gems/minitest-5.10.2/lib/minitest.rb:597
# each at org/jruby/RubyArray.java:1733
# report at /home/ramm/.rvm/gems/jruby-9.1.7.0/gems/minitest-5.10.2/lib/minitest.rb:687
# run at /home/ramm/.rvm/gems/jruby-9.1.7.0/gems/minitest-5.10.2/lib/minitest.rb:141
# run at /home/ramm/.rvm/gems/jruby-9.1.7.0/gems/railties-5.0.1/lib/rails/test_unit/minitest_plugin.rb:73
# block in autorun at /home/ramm/.rvm/gems/jruby-9.1.7.0/gems/minitest-5.10.2/lib/minitest.rb:63
# rake aborted!

Minitest::Reporters.use!(
    Minitest::Reporters::DefaultReporter.new,
    ENV, Minitest.backtrace_filter
)

# Load fixtures from the engine
#if ActiveSupport::TestCase.respond_to?(:fixture_path=)
#  ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
#  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
#  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
#  ActiveSupport::TestCase.fixtures :all
#end

# Globales Teardown für alle Tests
class ActionController::TestCase

  teardown do
    # Problem: fixtures.rb merkt sich am Start des Tests die aktive Connection und will darauf am Ende des Tests ein Rollback machen
    # zu diesem Zeitpunkt ist die gemerkte Connection jedoch gar nicht mehr aktiv, da mehrfach andere Connection aktiviert wurde
    # Lösung: Leeren des Arrays mit gemerkten Connections von fixture.rb, so dass nichts mehr zurückgerollt wird
    @fixture_connections.clear
  end

end


class ActiveSupport::TestCase
  include ApplicationHelper
  include EnvHelper
  include ActionView::Helpers::TranslationHelper

  # Verbindungsparameter der für Test konfigurierten DB als Session-Parameter hinterlegen
  # damit wird bei Connect auf diese DB zurückgegriffen

  def connect_oracle_db
    test_config = PanoramaTestConfig.test_config

    Rails.logger.info "#{Time.now} : Starting Test with configuration #{test_config}"

    connect_oracle_db_internal(test_config)   # aus lib/test_helpers/oracle_connection_test_helper
    @db_version = PanoramaConnection.db_version                                 # Store db_version outside PanoramaConnection
  end

  # Don't use PanoramaConnection.db_version because PanoramaConnection.reset_thread_local_attributes is called at end of each request
  def get_db_version
    @db_version
  end

  def set_panorama_sampler_config_defaults!(sampler_config)

    sampler_config[:query_timeout]                  = 20                        # single test should not last longer
    sampler_config[:awr_ash_active]                 = true
    sampler_config[:object_size_active]             = true
    sampler_config[:cache_objects_active]           = true
    sampler_config[:blocking_locks_active]          = true

    sampler_config[:awr_ash_snapshot_cycle]         = 1                         # Ensure small runtime of test run
    sampler_config[:longterm_trend_snapshot_cycle]  = 1                         # one hour
    sampler_config.merge!(PanoramaSamplerConfig.new(sampler_config).get_cloned_config_hash)
  end

  setup do
    @test_start_time = Time.now
    Rails.logger.info "#{@test_start_time} : start of test #{self.class}.#{self.name}" # set timestamp in test.logs
  end

  teardown do
    @test_end_time = Time.now
    Rails.logger.info "#{@test_end_time} : end of test #{self.class}.#{self.name}" # set timestamp in test.logs
    Rails.logger.info "#{@test_end_time-@test_start_time} seconds for test #{self.class}.#{self.name}" # set timestamp in test.logs
    Rails.logger.info ''
  end

  def prepare_panorama_sampler_thread_db_config(user = nil)
    EngineConfig.config.panorama_sampler_master_password = 'hugo'

    sampler_config = PanoramaTestConfig.test_config

    sampler_config[:id]                             = 1
    sampler_config[:name]                           = 'Test-Config'
    sampler_config[:client_salt]                    = EngineConfig.config.panorama_sampler_master_password  # identic doubled like WorkerThread.initialized
    sampler_config[:management_pack_license]        = management_pack_license   # use same management_pack_license as all other tests
    sampler_config[:owner]                          = sampler_config[:user]     # assume owner = connected user for test

    if user.nil?
      sampler_config[:password] = sampler_config[:password_decrypted]           # Encryption is done by PanoramaSamplerConfig.prepare_saved_entry!
      #sampler_config[:password] = Encryption.encrypt_value(sampler_config[:password_decrypted], sampler_config[:client_salt])
    else
      sampler_config[:password] = sampler_config[:syspassword_decrypted]        # Encryption is done by PanoramaSamplerConfig.prepare_saved_entry!
      #sampler_config[:password] = Encryption.encrypt_value(sampler_config[:syspassword_decrypted], sampler_config[:client_salt])
      sampler_config[:user]                          = user                     # use SYS or SYSTEM for connect
    end

    set_panorama_sampler_config_defaults!(sampler_config)

    PanoramaSamplerConfig.prepare_saved_entry!(sampler_config)

    config_object = PanoramaSamplerConfig.get_config_entry_by_id_or_nil(sampler_config[:id])

    if config_object.nil?
      PanoramaSamplerConfig.add_config_entry(sampler_config)
    else
      config_object.modify(sampler_config)
    end

    PanoramaConnection.set_connection_info_for_request(sampler_config)

    PanoramaSamplerConfig.get_config_entry_by_id(sampler_config[:id])
  end

  def assert_response_success_or_management_pack_violation(comment = '')
    if management_pack_license == :none
      sleep(0.5)                                                                # ensure moderate allocation of new DB-sessions beacause current session is destroyed
      assert_response(:error, "Expected :error but response is #{@response.response_code}: #{comment}")
    else
      assert_response(:success, "Expected :success but response is #{@response.response_code}: #{comment}")
    end
  end

  def initialize_min_max_snap_id_and_times
    two_snaps_sql = "SELECT Snap_ID - 1 Max_Snap_ID,
                                         Snap_ID - 2 Min_Snap_ID,
                                         Start_Time, End_Time
                                  FROM   (
                                          SELECT Snap_ID, Startup_Time,
                                                 LAG(Startup_Time, 1, NULL) OVER (PARTITION BY Instance_Number ORDER BY Snap_ID) Startup_1,
                                                 LAG(Startup_Time, 2, NULL) OVER (PARTITION BY Instance_Number ORDER BY Snap_ID) Startup_2,
                                                 LAG(Startup_Time, 3, NULL) OVER (PARTITION BY Instance_Number ORDER BY Snap_ID) Startup_3,
                                                 LAG(End_Interval_Time, 1, NULL) OVER (PARTITION BY Instance_Number ORDER BY Snap_ID) End_Time,
                                                 LAG(Begin_Interval_Time, 2, NULL) OVER (PARTITION BY Instance_Number ORDER BY Snap_ID) Start_Time
                                          FROM   DBA_Hist_Snapshot
                                          WHERE  Instance_Number = 1
                                          -- ORDER BY Snap_ID DESC /* order by corrupts result of LAG */
                                         )
                                  WHERE  Startup_Time = Startup_1
                                  AND    Startup_Time = Startup_2
                                  AND    Startup_Time = Startup_3
                                  ORDER BY Snap_ID DESC"


    # Ensure existence of panorama_sampler_snapshots
    if management_pack_license == :panorama_sampler
      # Ensure existence of structure
      sampler_config = prepare_panorama_sampler_thread_db_config
      PanoramaSamplerStructureCheck.domains.each do |domain|
        PanoramaSamplerStructureCheck.do_check(sampler_config, domain)
      end

      snaps = sql_select_first_row two_snaps_sql                                # Look for 2 subsequent snapshots in the middle of 4 snapshots with same startup time
      if snaps.nil? ||
          snaps.min_snap_id.nil? ||
          snaps.max_snap_id.nil? ||
          snaps.start_time.nil?  ||
          snaps.end_time.nil?    ||                                             # Not enough snapshots exists, create 4 subsequent
          (snaps.end_time - snaps.start_time) < 61                              # at least one minute should be between snapshots

        if !snaps.start_time.nil? && !snaps.end_time.nil? && (snaps.end_time - snaps.start_time) < 61
          Rails.logger.info "initialize_min_max_snap_id_and_times: new snaps executed because duration between snapshots is only #{} seconds"
        end

        WorkerThread.new(@sampler_config, 'initialize_min_max_snap_id_and_times').create_snapshot_internal(Time.now.round, :AWR)
        sleep(61)                                                               # Wait until next minute
        WorkerThread.new(@sampler_config, 'initialize_min_max_snap_id_and_times').create_snapshot_internal(Time.now.round, :AWR)
        sleep(61)                                                               # Wait until next minute
        WorkerThread.new(@sampler_config, 'initialize_min_max_snap_id_and_times').create_snapshot_internal(Time.now.round, :AWR)
        sleep(61)                                                               # Wait until next minute
        WorkerThread.new(@sampler_config, 'initialize_min_max_snap_id_and_times').create_snapshot_internal(Time.now.round, :AWR)
      end
    end


    # Get 2 subsequent snapshots in the middle of 4 snapshots with same startup time
    snaps = sql_select_first_row two_snaps_sql

    if snaps.nil?
      message = "No 4 subsequent snapshots with same startup_time found in #{PanoramaSamplerStructureCheck.adjust_table_name('DBA_Hist_Snapshot')}"
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

    @min_snap_id = snaps.min_snap_id
    @max_snap_id = snaps.max_snap_id

    @time_selection_start = (snaps.start_time-1).strftime("%d.%m.%Y %H:%M")
    @time_selection_end   = snaps.end_time.strftime("%d.%m.%Y %H:%M")
  end

end

class PanoramaTestConfig
  def self.test_config
    test_host         = ENV['TEST_HOST']        || 'localhost'
    test_port         = ENV['TEST_PORT']        || '1521'
    test_servicename  = ENV['TEST_SERVICENAME'] || 'ORCLPDB1'
    test_username     = ENV['TEST_USERNAME']    || 'panorama_test'
    test_password     = ENV['TEST_PASSWORD']    || 'panorama_test'
    test_syspassword  = ENV['TEST_SYSPASSWORD'] || 'oracle'

    config = {
        adapter:                  'nulldb',
        host:                     test_host,
        management_pack_license:  ENV['MANAGEMENT_PACK_LICENSE'] ? ENV['MANAGEMENT_PACK_LICENSE'].to_sym : :diagnostics_and_tuning_pack,
        modus:                    'host',
        panorama_sampler_schema:  test_username,                     # Use test user for panorama-sampler if not specified
        password_decrypted:       test_password,
        port:                     test_port,
        privilege:                'normal',
        sid:                      test_servicename,
        sid_usage:                :SERVICE_NAME,
        syspassword_decrypted:    test_syspassword,
        user:                     test_username,
        tns:                      "#{test_host}:#{test_port}/#{test_servicename}",
    }

    config
  end
end

