require 'test_helper'

class PanoramaSamplerControllerTest < ActionDispatch::IntegrationTest

  setup do
    set_session_test_db_context{}
  end

  test "show_config with xhr: true" do
    get '/panorama_sampler/show_config',  :params => {:format=>:html}
    assert_response :success
  end

  test "request_master_password with xhr: true" do
    get '/panorama_sampler/request_master_password',  :params => {:format=>:html}
    assert_response :success
  end

  test "check_master_password with xhr: true" do
    EngineConfig.config.panorama_sampler_master_password = 'hugo'
    get '/panorama_sampler/check_master_password',  :params => {:format=>:html, :master_password=>'hugo'}
    assert_response :success
    get '/panorama_sampler/check_master_password',  :params => {:format=>:js, :master_password=>'wrong'}
    assert_response :success
  end


end
