require 'test_helper'

class PanoramaSamplerControllerTest < ActionDispatch::IntegrationTest

  setup do
    set_session_test_db_context{}
    EngineConfig.config.panorama_sampler_master_password = 'hugo'

    @config_entry_without_id                      = get_current_database
    @config_entry_without_id[:password]           = Encryption.decrypt_value(@config_entry_without_id[:password], cookies['client_salt'])
    @config_entry_without_id[:snapshot_retention] = 60

    if PanoramaSamplerConfig.get_max_id < 100
      id = PanoramaSamplerConfig.get_max_id + 1
      PanoramaSamplerConfig.add_config_entry(@config_entry_without_id.merge( {:id => id, :name => "Test-Config #{id}" }))
    end
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
    get '/panorama_sampler/check_master_password',  :params => {:format=>:html, :master_password=>'hugo'}
    assert_response :success
    get '/panorama_sampler/check_master_password',  :params => {:format=>:js, :master_password=>'wrong'}
    assert_response :success
  end

  test "show_new_config_form with xhr: true" do
    get '/panorama_sampler/show_new_config_form',  :params => {:format=>:html}
    assert_response :success
  end

  test "show_edit_config_form with xhr: true" do
    get '/panorama_sampler/show_edit_config_form',  :params => {:format=>:html, :id=>1}
    assert_response :success
  end

  test "save_config with xhr: true" do
    get '/panorama_sampler/save_config',  :params => {:format=>:html, :commit=>'Save',
        :config => @config_entry_without_id.merge({:id => PanoramaSamplerConfig.get_max_id + 1, :name => "New Test-Config" })
    }
    assert_response :success

    get '/panorama_sampler/save_config',  :params => {:format=>:html, :commit=>'Test connection',
                                                      :config => @config_entry_without_id.merge({:id => PanoramaSamplerConfig.get_max_id + 1, :name => "New Test-Config" })
    }
    assert_response :success
  end

  test "delete_config with xhr: true" do
    get '/panorama_sampler/delete_config',  :params => {:format=>:html, :id=>PanoramaSamplerConfig.get_max_id }
    assert_response :success
  end

end
