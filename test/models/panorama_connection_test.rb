require 'test_helper'

class PanoramaConnectionTest < ActiveSupport::TestCase

  setup do
    @sampler_config = prepare_panorama_sampler_thread_db_config
  end

  test "disconnect_aged_connections" do
    PanoramaConnection.disconnect_aged_connections(100)
  end


end