require 'test_helper'

class FakeController
  def add_statusbar_message(message)
  end
end

class WorkerThreadTest < ActiveSupport::TestCase

  setup do
    register_test_start_in_log
    @sampler_config = prepare_panorama_sampler_thread_db_config
  end

  test "check_connection" do
    [nil, 'SYS', 'SYSTEM'].each do |connection_user|                            # Use different user for connect
      @sampler_config = prepare_panorama_sampler_thread_db_config(connection_user)
      WorkerThread.new(@sampler_config, 'test_check_connection').check_connection_internal(FakeController.new)
    end
  end

  test "check_structure" do
    [nil, 'SYS', 'SYSTEM'].each do |connection_user|                            # Use different user for connect
      [true, false].each do |select_any_table|                                  # Test package and anonymous PL/SQL
        @sampler_config = prepare_panorama_sampler_thread_db_config(connection_user)
        @sampler_config.set_select_any_table(select_any_table)

        PanoramaSamplerStructureCheck.remove_tables(@sampler_config)              # ensure missing objects is tested

        PanoramaSamplerStructureCheck.domains.each do |domain|
          PanoramaSamplerStructureCheck.do_check(@sampler_config, domain)
        end                                                                       # leave all objects existing because other tests rely on
      end
    end
  end

  test "do_sampling_awr_ash" do
    [nil, 'SYS', 'SYSTEM'].each do |connection_user|                            # Use different user for connect

      # Test-user needs SELECT ANY TABLE for read access on V$-Tables from PL/SQL-Packages
      [true, false].each do |select_any_table|                                  # Test package and anonymous PL/SQL
        @sampler_config = prepare_panorama_sampler_thread_db_config(connection_user)
        Rails.logger.info "######### Testing for connection_user=#{connection_user}, select_any_table=#{select_any_table}"

        @sampler_config.set_select_any_table(select_any_table)

        PanoramaSamplerStructureCheck.remove_tables(@sampler_config)            # ensure missing objects is tested

        WorkerThread.new(@sampler_config, 'test_check_structure_synchron').check_structure_synchron
        WorkerThread.new(@sampler_config, 'test_create_ash_sampler_daemon').create_ash_sampler_daemon(Time.now.round)
        WorkerThread.new(@sampler_config, 'test_do_sampling_AWR').create_snapshot_internal(Time.now.round, :AWR) # Tables must be created before snapshot., first snapshot initialization called

        sleep(61)                                                               # Ensure next execution in next minute

        WorkerThread.new(@sampler_config, 'test_check_structure_synchron').check_structure_synchron
        WorkerThread.new(@sampler_config, 'test_create_ash_sampler_daemon').create_ash_sampler_daemon(Time.now.round)
        WorkerThread.new(@sampler_config, 'test_do_sampling_AWR').create_snapshot_internal(Time.now.round, :AWR) # Tables must be created before snapshot., first snapshot initialization called

      end
    end
  end

  test "do_sampling_other_than_AWR_ASH" do
    [nil, 'SYS', 'SYSTEM'].each do |connection_user|                            # Use different user for connect
      PanoramaSamplerConfig.get_domains.each do |domain|
        if domain != :AWR_ASH
          @sampler_config = prepare_panorama_sampler_thread_db_config(connection_user)
          WorkerThread.new(@sampler_config, "test_sampling_#{domain}").create_snapshot_internal(Time.now.round, domain)
        end
      end
    end
  end

end