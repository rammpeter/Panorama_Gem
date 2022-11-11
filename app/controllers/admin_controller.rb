# encoding: utf-8
class AdminController < ApplicationController
  include AdminHelper
  include MenuHelper

  # Called from menu entry "Spec. additions"/"Admin login"
  def master_login
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    render html: "<script type='text/javascript'>#{build_main_menu_js_code}</script>".html_safe
  end

  # Called from restricted pages if not authorized before
  def show_admin_logon
    @origin_controller = prepare_param :origin_controller
    @origin_action     = prepare_param :origin_action
    render_partial
  end

  # Logon with valid master password and get JWT
  $master_password_wrong_count=0
  def admin_logon
    origin_controller = prepare_param :origin_controller
    origin_action     = prepare_param :origin_action
    master_password   = prepare_param :master_password

    if master_password == EngineConfig.config.panorama_master_password
      $master_password_wrong_count=0                                            # reset delay for wrong password
      expire_time = 8.hours.from_now
      token = JWT.encode({exp: expire_time.to_i}, jwt_secret, 'HS256')
      cookies['master'] = {value: token, expires: expire_time, httponly: true}
      redirect_to url_for(controller: origin_controller,
                          action:     origin_action,
                          :params     => {browser_tab_id: @browser_tab_id },
                          :method     => :post
                  )
    else
      cookies.delete 'master'                                                   # remove the invalid cookie
      sleep $master_password_wrong_count
      $master_password_wrong_count += 1
      show_popup_message('Wrong value entered for master password')
    end
  end

  def admin_logout
    cookies.delete 'master'
    render html: "<script type='text/javascript'>#{build_main_menu_js_code}</script>".html_safe
  end

  def show_log_level
    @log_level = @@log_level_aliases[Rails.logger.level]
    render_partial
  end

  def set_log_level
    return if force_login_if_admin_jwt_not_valid                                # Ensure valid authentication and suppress double rendering in tests
    log_level = prepare_param :log_level                                        # DEBUG, ERROR etc.
    Rails.logger.level = "Logger::#{log_level}".constantize
    msg = "Log level of Panorama server process set to #{log_level}"
    Rails.logger.warn('AdminController.set_log_level') { msg }
    render js: "show_status_bar_message('#{my_html_escape(msg)}')"
  end
end
