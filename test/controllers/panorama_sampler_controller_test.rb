require 'test_helper'

class PanoramaSamplerControllerTest < ActionDispatch::IntegrationTest
  test "should get show_config" do
    get panorama_sampler_show_config_url
    assert_response :success
  end

end
