require 'test_helper'

class PanoramaConnectionTest < ActiveSupport::TestCase

  setup do
    @sampler_config = prepare_panorama_sampler_thread_db_config
  end

  test "disconnect_aged_connections" do
    PanoramaConnection.disconnect_aged_connections(100)
  end

  test "check_for_erroneous_connection_removal" do
    PanoramaConnection.sql_select_one "SELECT SYSDATE FROM DUAL"
    current_sql_errors = Thread.current[:panorama_connection_connection_object].sql_errors_count
    begin
      PanoramaConnection.sql_select_one "SELECT Unknown FROM DUAL"
    rescue Exception
      nil
    end
    assert_equal(current_sql_errors+1,  Thread.current[:panorama_connection_connection_object].sql_errors_count, "sql_errors_count should increase by 1 after error")

    max_sql_errors = 0
    PanoramaConnection::MAX_CONNECTION_SQL_ERRORS_BEFORE_CLOSE.downto(0) do
      begin
        PanoramaConnection.sql_select_one "SELECT Unknown FROM DUAL"
      rescue Exception
        nil
      end
      max_sql_errors = Thread.current[:panorama_connection_connection_object].sql_errors_count if Thread.current[:panorama_connection_connection_object]&.sql_errors_count&.> max_sql_errors
    end
    assert(Thread.current[:panorama_connection_connection_object].sql_errors_count  < max_sql_errors, "There should be a new connection used now with sql_errors_count (#{Thread.current[:panorama_connection_connection_object].sql_errors_count}) less than the termination value of the previous connection (#{max_sql_errors}) ")
  end


end