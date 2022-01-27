require 'test_helper'

class PackLicenseTest < ActiveSupport::TestCase

  setup do
    @sampler_config = prepare_panorama_sampler_thread_db_config
  end

  test "translate_sql_table_names" do
    assert_equal("#{@sampler_config.get_owner}.Panorama_Snapshot", PackLicense.translate_sql_table_names('DBA_Hist_Snapshot', :panorama_sampler))
    assert_equal("DBA_Hist_Snapshot", PackLicense.translate_sql_table_names('DBA_Hist_Snapshot', :diagnostics_pack))
    assert_equal("DBA_Hist_Snapshot", PackLicense.translate_sql_table_names('DBA_Hist_Snapshot', :diagnostics_and_tuning_pack))
    assert_equal("DBA_Hist_Snapshot", PackLicense.translate_sql_table_names('DBA_Hist_Snapshot', :none))
  end
end

