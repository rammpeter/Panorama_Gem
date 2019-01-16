require 'json'

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
    @config = PanoramaSamplerConfig.get_config_entry_by_id(params[:id].to_i).get_cloned_config_hash
    @config[:password] = nil                                                    # Password set ony if changed
    render_partial :edit_config
  end

  def save_config
    config_entry                          = params[:config].to_unsafe_h.symbolize_keys
    config_entry[:id]                     = params[:id].to_i
    config_entry[:awr_ash_active]         = config_entry[:awr_ash_active]         == '1'
    config_entry[:object_size_active]     = config_entry[:object_size_active]     == '1'
    config_entry[:cache_objects_active]   = config_entry[:cache_objects_active]   == '1'
    config_entry[:blocking_locks_active]  = config_entry[:blocking_locks_active]  == '1'

    PanoramaSamplerConfig.prepare_saved_entry!(config_entry)      # Password encryption called here

    if PanoramaSamplerConfig.config_entry_exists?(config_entry[:id])            # entry already saved?
      org_entry = PanoramaSamplerConfig.get_config_entry_by_id(config_entry[:id]).get_cloned_config_hash  # Test with copy
      config_entry.replace(org_entry.merge(config_entry))                       # Replace content, but preserve object
    end

    dbid = WorkerThread.check_connection(PanoramaSamplerConfig.new(config_entry), self, params[:commit] != 'Save')  # Tests connection and writes back some state in config_hash. Ignore exceptions if "Save" pressed

    config_entry[:dbid] = dbid unless dbid.nil?                                 # Save dbid if real value
    config_entry[:last_successful_connect] = Time.now unless dbid.nil?

    store_config(config_entry)                                                  # add or modify entry in persistence
  rescue Exception => e                                                         # if params[:commit] != 'Save' ('Test connection') Exception is raised if connect error occurs
    existing_config = PanoramaSamplerConfig.get_config_entry_by_id_or_nil(config_entry[:id])  # Check if config already exists
    existing_config.set_error_message(e.message) if existing_config
    raise e
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

  def monitor_sampler_status
    status = 200                                                                # Default

    config_array = PanoramaSamplerConfig.get_reduced_config_array_for_status_monitor

    retval = "{\n\"config_list\": ["
    config_array.each do |config|
      status = 500 if config[:error_active]
      retval << "\n#{JSON.pretty_generate(config, {indent: '  '})},"


=begin
indent: a string used to indent levels (default: ''),
space: a string that is put after, a : or , delimiter (default: ''),
space_before: a string that is put before a : pair delimiter (default: ''),
object_nl: a string that is put at the end of a JSON object (default: ''),
array_nl: a string that is put at the end of a JSON array (default: ''),
allow_nan: true if NaN, Infinity, and -Infinity should be generated, otherwise an exception is thrown if these values are encountered. This options defaults to false.
max_nesting: The maximum depth of nesting allowed in the data structures from which JSON is to be generated. Disable depth checking with :max_nestin
=end


    end
    retval << "\n]\n}"
    render json: retval, status: status
  end
end
