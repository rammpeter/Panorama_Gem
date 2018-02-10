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
    WorkerThread.new(@sampler_config, 'test_check_connection').check_connection_internal(FakeController.new)
  end

  test "check_structure" do
    PanoramaSamplerStructureCheck.remove_tables(@sampler_config)                # ensure missing objects is tested

    PanoramaSamplerStructureCheck.domains.each do |domain|
      PanoramaSamplerStructureCheck.do_check(@sampler_config, domain)
    end                                                                         # leave all objects existing because other tests rely on
  end

  test "do_sampling_awr_ash" do
    # Test-user needs SELECT ANY TABLE for read access on V$-Tables from PL/SQL-Packages
    [true, false].each do |select_any_table|                                    # Test package and anonymous PL/SQL
      @sampler_config.set_select_any_table(select_any_table)
      WorkerThread.new(@sampler_config, 'test_check_structure_synchron').check_structure_synchron
      WorkerThread.new(@sampler_config, 'test_create_ash_sampler_daemon').create_ash_sampler_daemon(Time.now.round)
      WorkerThread.new(@sampler_config, 'test_do_sampling_AWR').create_snapshot_internal(Time.now.round, :AWR) # Tables must be created before snapshot., first snapshot initialization called
    end
  end

  test "do_sampling_object_size" do
    WorkerThread.new(@sampler_config, 'do_sampling_object_size').create_snapshot_internal(Time.now.round, :OBJECT_SIZE)
  end

  test "do_sampling_cache_objects" do
    WorkerThread.new(@sampler_config, 'do_sampling_cache_objects').create_snapshot_internal(Time.now.round, :CACHE_OBJECTS)
  end

  test "do_sampling_blocking_locks" do
    WorkerThread.new(@sampler_config, 'do_sampling_blocking_locks').create_snapshot_internal(Time.now.round, :BLOCKING_LOCKS)
  end

end