# encoding: utf-8
require 'test_helper'

class PanoramaSamplerControllerTest < ActionDispatch::IntegrationTest

  setup do
    set_session_test_db_context
    EngineConfig.config.panorama_sampler_master_password = 'hugo'

    @config_entry_without_id                                  = get_current_database
    @config_entry_without_id[:name]                           = 'Hugo'
    @config_entry_without_id[:password]                       = Encryption.decrypt_value(@config_entry_without_id[:password], cookies['client_salt'])
    @config_entry_without_id[:owner]                          = @config_entry_without_id[:user] # Default

    set_panorama_sampler_config_defaults!(@config_entry_without_id)

    if PanoramaSamplerConfig.get_max_id < 100
      id = PanoramaSamplerConfig.get_max_id + 1
      PanoramaSamplerConfig.add_config_entry(@config_entry_without_id.merge( {:id => id, :name => "Test-Config #{id}" }))
    end
  end

  test "show_config with xhr: true" do
    get '/panorama_sampler/show_config',  :params => {:format=>:html}
    assert_response :success, 'show_config'
  end

  test "request_master_password with xhr: true" do
    get '/panorama_sampler/request_master_password',  :params => {:format=>:html}
    assert_response :success, 'request_master_password'
  end

  test "check_master_password with xhr: true" do
    get '/panorama_sampler/check_master_password',  :params => {:format=>:html, :master_password=>'hugo'}
    assert_response :success, 'check_master_password should connect'
    get '/panorama_sampler/check_master_password',  :params => {:format=>:js, :master_password=>'wrong'}
    assert_response :success, 'check_master_password should produce connect error'
  end

  test "show_new_config_form with xhr: true" do
    get '/panorama_sampler/show_new_config_form',  :params => {:format=>:html}
    assert_response :success, 'show_new_config_form'
  end

  test "show_edit_config_form with xhr: true" do
puts "Before calling action"
    get '/panorama_sampler/show_edit_config_form',  :params => {:format=>:html, :id=>1}
puts "After calling action"
    assert_response :success, 'show_edit_config_form'
puts "After assert"
  end

  test "clear_config_error with xhr: true" do
    post '/panorama_sampler/clear_config_error',  :params => {:format=>:html, :id=>1}
    assert_response :success, 'clear_config_error'
  end

  test "save_config with xhr: true" do
    ['Save', 'Test connection'].each do |button|                                # Simulate pressed button "Save" or "Test connection"
      ['Existing', 'New'].each do |mode|                                        # Simulate change of existing or new record
        ['Right', 'Wrong', 'System'].each do |right|                            # Valid or invalid connection info
          id = mode=='New' ? PanoramaSamplerConfig.get_max_id + 1 : PanoramaSamplerConfig.get_max_id
          config = @config_entry_without_id.clone
          response_format = :html                                                        # Default
          config[:user] = 'blabla' if right == 'Wrong'                          # Force connect error or not
          config[:owner] = 'system' if right == 'System'
          response_format = :js if (right == 'Wrong' || right == 'System') && button == 'Test connection'  # Popup-Dialog per JS expected

          get '/panorama_sampler/save_config',
              :params => {
                  :format => response_format,
                  :commit => button,
                  :id     => id,
                  :config => config
              }
          assert_response :success, "save_config for button='#{button}', mode='#{mode}', right='#{right}'"

        end
      end
    end
  end

  test "delete_config with xhr: true" do
    get '/panorama_sampler/delete_config',  :params => {:format=>:html, :id=>PanoramaSamplerConfig.get_max_id }
    assert_response :success, 'delete_config'
  end

end
