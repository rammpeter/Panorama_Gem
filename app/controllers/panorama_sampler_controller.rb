class PanoramaSamplerController < ApplicationController
  def show_config
    if read_from_client_info_store(:encrypted_panorama_sampler_master_password)
      list_config
    else
      request_master_password
    end
  end

  def list_config
    @sampler_config = read_current_sampler_config
    render_partial :list_config
  end

  def request_master_password
    render_partial :request_master_password
  end

  $master_password_wrong_count=0
  def check_master_password
    if params[:master_password] == EngineConfig.config.panorama_sampler_master_password
      $master_password_wrong_count=0                                            # reset delay for wrong password
      list_config
    else
      sleep $master_password_wrong_count
      $master_password_wrong_count += 1
      show_popup_message('Wrong value entered for master password')
    end
  end

  def show_new_config_form
    @modus = :new
    @config = {:id => get_max_id+1, :snapshot_retention => 60}
    render_partial :edit_config
  end

  def show_edit_config_form
    @modus = :edit
    @config = x
    render_partial :edit_config
  end

  def save_config
    configs = read_current_sampler_config
    if params[:modus] == 'new'
      configs << {
          :id                 => params[:id].to_i,
          :name               => params[:name],
          :username           => params[:username],
          :password           => params[:password],
          :snapshot_retention => params[:snapshot_retention].to_i,
      }
      x = 5
    end
    if params[:modus] == 'edit'
      configs = []
    end
    write_current_sampler_config(configs)
    list_config
  end

  private
  # Config for current master password
  def read_current_sampler_config
    retval = get_client_info_store.read("panorama_sampler_master_config_#{EngineConfig.config.panorama_sampler_master_password.hash}")
    retval = [] if retval.nil?
    retval
  end

  def write_current_sampler_config(config)
    get_client_info_store.write("panorama_sampler_master_config_#{EngineConfig.config.panorama_sampler_master_password.hash}", config)
  rescue Exception =>e
    Rails.logger.error("Exception '#{e.message}' raised while writing file store at '#{EngineConfig.config.client_info_filename}'")
    raise "Exception '#{e.message}' while writing file store at '#{EngineConfig.config.client_info_filename}'"
  end

  def get_max_id
    retval = 0
    read_current_sampler_config.each do |c|
      retval = c[:id] if c[:id] > retval
    end
    retval
  end
end
