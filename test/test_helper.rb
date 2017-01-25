# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../../test/dummy/config/environment.rb", __FILE__)
#ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../test/dummy/db/migrate", __FILE__)]
#ActiveRecord::Migrator.migrations_paths << File.expand_path('../../db/migrate', __FILE__)
require "rails/test_help"

require 'fileutils'

# Load own helpers
require File.expand_path("../../lib/test_helpers/oracle_connection_test_helper.rb", __FILE__)
#require '../../lib/test_helpers/oracle_connection_test_helper'           # requires config/environment.rb loaded
require 'menu_test_helper'
#require 'capybara_test_helper'

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new


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



