# encoding: utf-8
require 'test_helper'

class AdminControllerTest < ActionDispatch::IntegrationTest

  setup do
    set_session_test_db_context
    EngineConfig.config.panorama_master_password = 'hugo'
  end

  # Called from menu entry "Spec. additions"/"Admin login"
  test "master_login with xhr: true" do
    get '/admin/admin_logout',  :params => {:format=>:html}
    assert_response :success, log_on_failure('Remove a possibly existing cookie before test')

    get '/admin/master_login',  :params => {:format=>:html}
    assert_response :redirect, log_on_failure('Should be redirecte to login page')

    # Set a valid JWT with cookie
    post '/admin/admin_logon',  :params => {:format=>:html, origin_controller: :admin, origin_action: :master_login, master_password: EngineConfig.config.panorama_master_password}
    assert_response :redirect, log_on_failure('Should be redirecte to a dummy page after successful logon')

    get '/admin/master_login',  :params => {:format=>:html}
    assert_response :success, log_on_failure('Should refresh menu with admin menu with valid JWT in cookie')
  end

  test "show_admin_logon with xhr: true" do
    get '/admin/show_admin_logon',  :params => {:format=>:html, origin_controller: :admin, origin_action: :master_login}
    assert_response :success, log_on_failure('Should show the logon dialog')
  end

  test "admin_logon with xhr: true" do
    # Set a valid JWT with cookie
    post '/admin/admin_logon',  :params => {:format=>:html, origin_controller: :admin, origin_action: :master_login, master_password: EngineConfig.config.panorama_master_password}
    assert_response :redirect, log_on_failure('Should be redirecte to a dummy page after successful logon')

    # Set a valid JWT with cookie
    post '/admin/admin_logon',  :params => {:format=>:html, origin_controller: :admin, origin_action: :master_login, master_password: 'false'}
    assert_response :error, log_on_failure('Should raise popup dialog due to wrong passworf')
  end

  test "admin_logout with xhr: true" do
    get '/admin/admin_logout',  :params => {:format=>:html}
    assert_response :success, log_on_failure('Logout from admin')
  end
end
