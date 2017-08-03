require 'test_helper'

class PanoramaSamplerStructureCheckTest < ActiveSupport::TestCase

  setup do
    @sampler_config = prepare_panorama_sampler_thread_db_config
  end


  test "has_column?" do
    assert_equal(true, PanoramaSamplerStructureCheck.has_column?('Panorama_Snapshot', 'Snap_ID'))
  end

end