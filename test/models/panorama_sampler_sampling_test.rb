require 'test_helper'

class PanoramaSamplerSamplingTest < ActiveSupport::TestCase

  setup do
    @sampler_config = prepare_panorama_sampler_thread_db_config
  end


#  test "do_sampling" do
#    PanoramaSamplerStructureCheck.remove_tables(@sampler_config)
#    PanoramaSamplerSampling.do_sampling(@sampler_config)
#  end

  test "do_housekeeping" do
    [true, false].each do |shrink_space|
      PanoramaSamplerSampling.do_housekeeping(@sampler_config, shrink_space)
    end
  end

  test "do_object_size_housekeeping" do
    [true, false].each do |shrink_space|
      PanoramaSamplerSampling.do_object_size_housekeeping(@sampler_config, shrink_space)
    end
  end

end