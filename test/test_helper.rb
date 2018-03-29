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
require File.expand_path("../../lib/test_helpers/capybara_test_helper.rb", __FILE__)
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

    raise "Environment-Variable DB_VERSION not set" unless ENV['DB_VERSION']
    Rails.logger.info "#{Time.now} : Starting Test with configuration test_#{ENV['DB_VERSION']}"

    # Array mit Bestandteilen der Vorgabe aus database.yml
    #test_config = Dummy::Application.config.database_configuration["test_#{ENV['DB_VERSION']}"]

    test_config = PanoramaTestConfig.test_config

    connect_oracle_db_internal(test_config)   # aus lib/test_helpers/oracle_connection_test_helper
    @db_version = PanoramaConnection.db_version                                 # Store db_version outside PanoramaConnection

  end

  # Don't use PanoramaConnection.db_version because PanoramaConnection.reset_thread_local_attributes is called at end of each request
  def get_db_version
    @db_version
  end

  def set_panorama_sampler_config_defaults!(sampler_config)

    sampler_config[:query_timeout]                  = 20                            # single test should not last longer
    sampler_config[:awr_ash_active]                 = true
    sampler_config[:object_size_active]             = true
    sampler_config[:cache_objects_active]           = true
    sampler_config[:blocking_locks_active]          = true

    sampler_config[:awr_ash_snapshot_cycle]         = 1                         # Ensure small runtime of test run
    sampler_config.merge!(PanoramaSamplerConfig.new(sampler_config).get_cloned_config_hash)
  end


  def prepare_panorama_sampler_thread_db_config
    EngineConfig.config.panorama_sampler_master_password = 'hugo'

    test_config = PanoramaTestConfig.test_config

    sampler_config = create_prepared_database_config(test_config)

    sampler_config[:id]                             = 1
    sampler_config[:name]                           = 'Test-Config'
    sampler_config[:client_salt]                    = EngineConfig.config.panorama_sampler_master_password  # identic doubled like WorkerThread.initialized
    sampler_config[:management_pack_license]        = :none                     # assume no management packs are licensed for PanoramaSampler-execution
    sampler_config[:privilege]                      = 'normal'

    sampler_config[:password] = Encryption.encrypt_value(test_config["test_password"], sampler_config[:client_salt])
    sampler_config[:panorama_sampler_schema]        = 'panorama_test'           # Schema for panorama-sampler-tables

    sampler_config[:owner]                          = sampler_config[:user]                             # assume owner = connected user for test

    set_panorama_sampler_config_defaults!(sampler_config)

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
    assert_response(management_pack_license == :none ? :error : :success, comment)
  end

end

class PanoramaTestConfig
  def self.test_config
    Dummy::Application.config.database_configuration["test_#{ENV['DB_VERSION']}"]
  end
end

