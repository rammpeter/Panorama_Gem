class PanoramaSamplerController < ApplicationController
  def show_config
    request_master_password
  end

  def list_config
    @sampler_config = PanoramaSamplerConfig.get_config_array.map{|config| config.get_cloned_config_hash}
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
    @config = PanoramaSamplerConfig.new.get_cloned_config_hash
    render_partial :edit_config
  end

  def show_edit_config_form
    @modus = :edit
puts "Before calling get_config_entry" if ENV['RAILS_ENV'] != 'test'
    @config = PanoramaSamplerConfig.get_config_entry_by_id(params[:id].to_i).get_cloned_config_hash
puts "After calling get_config_entry" if ENV['RAILS_ENV'] != 'test'
    @config[:password] = nil                                                    # Password set ony if changed
puts "Before calling render" if ENV['RAILS_ENV'] != 'test'
    render_partial :edit_config
puts "After calling render" if ENV['RAILS_ENV'] != 'test'
  end

  def save_config
    config_entry                          = params[:config].to_unsafe_h.symbolize_keys
    config_entry[:id]                     = params[:id].to_i
    config_entry[:awr_ash_active]         = config_entry[:awr_ash_active]         == '1'
    config_entry[:object_size_active]     = config_entry[:object_size_active]     == '1'
    config_entry[:cache_objects_active]   = config_entry[:cache_objects_active]   == '1'
    config_entry[:blocking_locks_active]  = config_entry[:blocking_locks_active]  == '1'

    config_entry = PanoramaSamplerConfig.prepare_saved_entry(config_entry)      # Password encryption called here

    dbid = test_connection(config_entry)
    config_entry[:dbid] = dbid unless dbid.nil?                                 # Save dbid if real value
    config_entry[:last_successful_connect] = Time.now unless dbid.nil?


    if params[:commit] == 'Save'
      store_config(config_entry)  # Should replace instance
    else                                                                        # Check connection pressed
      if dbid.nil?
        show_popup_message("Connect to '#{config_entry[:name]}' not successful!\nException: #{config_entry[:last_error_message]}\nSee Panorama-Log for further details")
      else
        store_config(config_entry)                                                # add or modify entry in persistence
      end
    end
  end

  def store_config(config_entry)
    old_min_snapshot_cycle = PanoramaSamplerConfig.min_snapshot_cycle

    existing_config = PanoramaSamplerConfig.get_config_entry_by_id_or_nil(config_entry[:id])  # Check if config already exists

    if existing_config.nil?
      PanoramaSamplerConfig.add_config_entry(config_entry)
    else
      existing_config.modify(config_entry)
    end

    new_min_snapshot_cycle = PanoramaSamplerConfig.min_snapshot_cycle

    if new_min_snapshot_cycle < old_min_snapshot_cycle
      add_statusbar_message("Sampling currently starts each #{old_min_snapshot_cycle} minutes, but you've requested sampling each #{new_min_snapshot_cycle} minutes now.\nIf you don't restart Panorama's server now than your setting starts working only after next full #{old_min_snapshot_cycle} minutes")
    end

    list_config
  end

  def delete_config
    PanoramaSamplerConfig.delete_config_entry(params[:id])
    list_config
  end

  def clear_config_error
    PanoramaSamplerConfig.get_config_entry_by_id(params[:id]).clear_error_message
    list_config
  end

  private
  # Test connection and store result in entry, return DBID or nil in case of connect error
  def test_connection(config_hash)
    if PanoramaSamplerConfig.config_entry_exists?(config_hash[:id])            # entry already saved?
      org_entry = PanoramaSamplerConfig.get_config_entry_by_id(config_hash[:id]).get_cloned_config_hash  # Test with copy
      config_hash.replace(org_entry.merge(config_hash))                       # Replace content, but preserve object
    end

    dbid = WorkerThread.check_connection(PanoramaSamplerConfig.new(config_hash), self)  # Writes back some state in config_hash
    dbid
  end
end
