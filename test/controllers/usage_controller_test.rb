# encoding: utf-8
require 'test_helper'

class UsageControllerTest < ActionDispatch::IntegrationTest

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{}

    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000          # x Sekunden Abstand
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")

  end

  def usage_file_exists?
    file = File.open(EngineConfig.config.usage_info_filename, "r")
    Rails.logger.info "UsageControllerTest.usage_file_exists?: Test excuted because usage #{EngineConfig.config.usage_info_filename} file exists. PWD = #{Dir.pwd}"
    true
  rescue Exception
    Rails.logger.info "UsageControllerTest.usage_file_exists?: Test skipped because usage #{EngineConfig.config.usage_info_filename} file does not exist. PWD = #{Dir.pwd}"
    false
  end

  test "info with xhr: true" do
    if usage_file_exists?
      get '/usage/info', :params => {:format=>:html }
      assert_response :success
    end
  end

  test "detail_sum with xhr: true" do
    if usage_file_exists?
      ['Database', 'IP_Address', 'Controller', 'Action'].each do |groupkey|
        [{'Month' => '2017/05'}, {'Database' => 'Hugo'}, {'IP_Address' => '0.0.0.0'}, {'Controller' => 'Hugo'}, {'Action' => 'Hugo'}].each do |filter|
          post '/usage/detail_sum', :params => {format: :html, groupkey: groupkey, filter: filter }
          assert_response :success
        end
      end
    end
  end

  test "single_record with xhr: true" do
    if usage_file_exists?
      [{'Month' => '2017/05'}, {'Database' => 'Hugo'}, {'IP_Address' => '0.0.0.0'}, {'Controller' => 'Hugo'}, {'Action' => 'Hugo'}].each do |filter|
        post '/usage/single_record', :params => {format: :html, filter: filter }
        assert_response :success
      end
    end
  end

  test "connection_pool with xhr: true" do
    get '/usage/connection_pool', :params => {:format=>:html }
    assert_response :success
  end



end
