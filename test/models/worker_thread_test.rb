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
    WorkerThread.new(@sampler_config).check_connection_internal(FakeController.new)
  end

  test "do_sampling" do
    PanoramaSamplerStructureCheck.remove_tables(@sampler_config)                # dedicated szeario
    WorkerThread.new(@sampler_config).create_snapshot_internal                  # Tables must be created before snapshot., first snapshot initialization called

    WorkerThread.new(@sampler_config).create_snapshot_internal                  # Tables already exists before snapshot
  end

end