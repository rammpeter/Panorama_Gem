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

  test "do_sampling_awr_ash" do
    PanoramaSamplerStructureCheck.remove_tables(@sampler_config)                # dedicated szeario
    WorkerThread.new(@sampler_config, 'test_do_sampling').check_structure_synchron
    WorkerThread.new(@sampler_config, 'test_do_sampling').create_ash_sampler_daemon(Time.now.round)
    WorkerThread.new(@sampler_config, 'test_do_sampling').create_snapshot_internal                  # Tables must be created before snapshot., first snapshot initialization called

    WorkerThread.new(@sampler_config, 'test_do_sampling').create_snapshot_internal                  # Tables already exists before snapshot
  end

  test "do_sampling_object_size" do
    PanoramaSamplerStructureCheck.remove_tables(@sampler_config)                # dedicated szeario
    WorkerThread.new(@sampler_config, 'do_sampling_object_size').create_object_size_snapshot_internal(Time.now.round)                  # Tables already exists before snapshot
  end

end