require 'test_helper'

class PanoramaSamplerSamplingTest < ActiveSupport::TestCase

  setup do
    @sampler_config = prepare_panorama_sampler_thread_db_config
  end

  # Test executed in WorkerThreadTest
  #test "do_sampling" do
  #  PanoramaSamplerStructureCheck.remove_tables(@sampler_config)
  #  PanoramaSamplerSampling.do_sampling(@sampler_config, Time.now, :AWR)
  #end

  test "do_housekeeping" do
    PanoramaSamplerStructureCheck.do_check(@sampler_config, :ASH)               # Check data structure preconditions, but only for ASH-tables

    [true, false].each do |shrink_space|
      PanoramaSamplerStructureCheck.domains.each do |domain|
        PanoramaSamplerStructureCheck.do_check(@sampler_config, domain)         # Ensure that structures are existing
        PanoramaSamplerSampling.do_housekeeping(@sampler_config, shrink_space, domain) if domain != :ASH  # :ASH does not have own housekeeping
      end
    end
  end


end