require 'test_helper'

class PanoramaSamplerControllerTest < ActionDispatch::IntegrationTest

  setup do
    set_session_test_db_context{}
  end

  test "should get show_config" do
    get panorama_sampler_show_config_url
    assert_response :success
  end

end
