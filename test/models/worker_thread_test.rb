require 'test_helper'

class FakeController
  def add_statusbar_message(message)
  end
end

class WorkerThreadTest < ActiveSupport::TestCase

  setup do
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
        @sampler_config.set_test_awr_ash_snapshot_cycle(0)                      # Allow AWR/ASH Snapshots each x seconds, 5 seconds added by executing method

        PanoramaSamplerStructureCheck.remove_tables(@sampler_config)            # ensure missing objects is tested

        WorkerThread.new(@sampler_config, 'test_check_structure_synchron').check_structure_synchron
        WorkerThread.new(@sampler_config, 'test_create_ash_sampler_daemon').create_ash_sampler_daemon(Time.now.round)
        WorkerThread.new(@sampler_config, 'test_do_sampling_AWR').create_snapshot_internal(Time.now.round, :AWR) # Tables must be created before snapshot., first snapshot initialization called

        #sleep(61)                                                               # Ensure next execution in next minute

        WorkerThread.new(@sampler_config, 'test_check_structure_synchron').check_structure_synchron
        WorkerThread.new(@sampler_config, 'test_create_ash_sampler_daemon').create_ash_sampler_daemon(Time.now.round)
        WorkerThread.new(@sampler_config, 'test_do_sampling_AWR').create_snapshot_internal(Time.now.round, :AWR) # Tables must be created before snapshot., first snapshot initialization called

      end
    end
  end



  test "do_sampling_longterm_trend" do
    [nil, 'SYS', 'SYSTEM'].each do |connection_user|                            # Use different user for connect
      [true, false].each do |log_item|
        @sampler_config = prepare_panorama_sampler_thread_db_config(connection_user)

        @mod_sampler_config = PanoramaSamplerConfig.new(@sampler_config.get_cloned_config_hash.merge(
            longterm_trend_log_wait_class:  log_item,
            longterm_trend_log_wait_event:  log_item,
            longterm_trend_log_user:        log_item,
            longterm_trend_log_service:     log_item,
            longterm_trend_log_machine:     log_item,
            longterm_trend_log_module:      log_item,
            longterm_trend_log_action:      log_item,
            longterm_trend_subsume_limit:   400  # per mille
        ))
        WorkerThread.new(@mod_sampler_config, "test_sampling_longterm_trend").create_snapshot_internal(Time.now.round, :LONGTERM_TREND)
      end
    end
  end



  test "do_sampling_other_than_AWR_ASH" do
    [nil, 'SYS', 'SYSTEM'].each do |connection_user|                            # Use different user for connect
      [:OBJECT_SIZE, :CACHE_OBJECTS, :BLOCKING_LOCKS ].each do |domain|
        if domain != :AWR_ASH
          @sampler_config = prepare_panorama_sampler_thread_db_config(connection_user)
          WorkerThread.new(@sampler_config, "test_sampling_#{domain}").create_snapshot_internal(Time.now.round, domain)
        end
      end
    end
  end

end