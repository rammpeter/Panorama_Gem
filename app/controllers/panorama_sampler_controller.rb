class PanoramaSamplerController < ApplicationController
  def show_config
    request_master_password
  end

  def list_config
    @sampler_config = PanoramaSamplerConfig.get_cloned_config_array
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
    @config = {:id => PanoramaSamplerConfig.get_max_id+1, :active=>true, :snapshot_cycle => 60, :snapshot_retention => 32}
    render_partial :edit_config
  end

  def show_edit_config_form
    @modus = :edit
    @config = PanoramaSamplerConfig.get_cloned_config_entry(params[:id].to_i)
    @config[:password] = nil                                                    # Password set ony if changed
    render_partial :edit_config
  end

  def save_config
    config_entry          = params[:config].to_unsafe_h.symbolize_keys
    config_entry[:id]     = params[:id].to_i
    config_entry[:active] = config_entry[:active] == '1'

    config_entry = PanoramaSamplerConfig.prepare_saved_entry(config_entry)

    dbid = test_connection(config_entry)

    if params[:commit] == 'Save'
      store_config(config_entry)
    else                                                                        # Check connection pressed
      if dbid.nil?
        ("Connect to '#{config_entry[:name]}' not successful!\nException: #{config_entry[:last_error_message]}\nSee Panorama-Log for further details")
      else
        store_config(config_entry)                                                # add or modify entry in persistence
      end
    end
  end

  def store_config(config_entry)
    if PanoramaSamplerConfig.min_snapshot_cycle > config_entry[:snapshot_cycle]
      add_statusbar_message("Sampling currently starts each #{PanoramaSamplerConfig.min_snapshot_cycle} minutes\nIf you don't restart Panorama's server now than your setting starts working not before next full #{PanoramaSamplerConfig.min_snapshot_cycle} minutes")
    end


    if PanoramaSamplerConfig.config_entry_exists?(config_entry[:id])
      PanoramaSamplerConfig.modify_config_entry(config_entry)
    else
      PanoramaSamplerConfig.add_config_entry(config_entry)
    end
    list_config
  end

  def delete_config
    PanoramaSamplerConfig.delete_config_entry(params[:id])
    list_config
  end

  def clear_config_error
    config_entry = {:id => params[:id].to_i}
    config_entry[:last_error_time]    = nil
    config_entry[:last_error_message] = nil
    PanoramaSamplerConfig.modify_config_entry(config_entry)
    list_config
  end

  private
  # Test connection and store result in entry, return DBID or nil in cse of connect error
  def test_connection(config_entry)
    if PanoramaSamplerConfig.config_entry_exists?(config_entry[:id])            # entry already saved?
      org_entry = PanoramaSamplerConfig.get_cloned_config_entry(config_entry[:id])  # Test with copy
      config_entry.replace(org_entry.merge(config_entry))                       # Replace content, but preserve object
    end

    dbid = WorkerThread.check_connection(config_entry, self)                    # Writes back some state in config_entry
    dbid
  end
end
