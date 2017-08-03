require 'test_helper'

class PanoramaSamplerStructureCheckTest < ActiveSupport::TestCase

  setup do
    @sampler_config = prepare_panorama_sampler_thread_db_config
  end


  test "has_column?" do
    assert_equal(true, PanoramaSamplerStructureCheck.has_column?('Panorama_Snapshot', 'Snap_ID'))
  end

  test "replacement_table" do
    assert_equal('Panorama_Snapshot', PanoramaSamplerStructureCheck.replacement_table('DBA_Hist_Snapshot'))
    assert_nil(PanoramaSamplerStructureCheck.replacement_table('Dummy'))
  end


end