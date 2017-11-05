# Stores Config-object in memory and synchronizes access to session store on disk
class PanoramaSamplerConfig
  @@config_array = nil                                                          # First access loads it from session store
  @@config_access_mutex = Mutex.new


  def self.initialize_defaults(config = {})
    config[:id]                                 = PanoramaSamplerConfig.get_max_id+1     if !config.has_key?(:id)
    config[:awr_ash_snapshot_cycle]             = 60    if !config.has_key?(:awr_ash_snapshot_cycle)
    config[:awr_ash_snapshot_retention]         = 32    if !config.has_key?(:awr_ash_snapshot_retention)
    config[:sql_min_no_of_execs]                = 2     if !config.has_key?(:sql_min_no_of_execs)
    config[:sql_min_runtime_millisecs]          = 10    if !config.has_key?(:sql_min_runtime_millisecs)
    config[:awr_ash_active]                     = false if !config.has_key?(:awr_ash_active)
    config[:object_size_active]                 = false if !config.has_key?(:object_size_active)
    config[:object_size_snapshot_cycle]         = 24    if !config.has_key?(:object_size_snapshot_cycle)
    config[:object_size_snapshot_retention]     = 1000  if !config.has_key?(:object_size_snapshot_retention)
    config[:cache_objects_active]               = false if !config.has_key?(:cache_objects_active)
    config[:cache_objects_snapshot_cycle]       = 30    if !config.has_key?(:cache_objects_snapshot_cycle)
    config[:cache_objects_snapshot_retention]   = 60    if !config.has_key?(:cache_objects_snapshot_retention)
    config[:blocking_locks_active]              = false if !config.has_key?(:blocking_locks_active)
    config[:blocking_locks_snapshot_cycle]      = 2     if !config.has_key?(:blocking_locks_snapshot_cycle)
    config[:blocking_locks_snapshot_retention]  = 60    if !config.has_key?(:blocking_locks_snapshot_retention)
    config
  end

  # Get copy of config array incl. cloned elements for display etc.
  def self.get_cloned_config_array
    retval = []
    @@config_access_mutex.synchronize do
      get_config_array.each{|c| retval << initialize_defaults(c.clone)}
    end
    retval
  end

  def self.get_cloned_config_entry(p_id)
    @@config_access_mutex.synchronize do
      return initialize_defaults(get_config_entry_by_id(p_id).clone)
    end
  end

  def self.config_entry_exists?(p_id)
    @@config_access_mutex.synchronize do
      return !get_config_entry_by_id_or_nil(p_id).nil?
    end
  end

  def self.sampler_schema_for_dbid(dbid)
    get_cloned_config_array.each do |entry|
      return entry[:owner] if entry[:dbid] == dbid
    end
    nil
  end

  def self.get_max_id
    retval = 0
    @@config_access_mutex.synchronize do
      get_config_array.each do |c|
        retval = c[:id] if c[:id] && c[:id] > retval
      end
    end
    retval
  end

  def self.min_snapshot_cycle
    min_snapshot_cycle = 60                                                     # at least every hour run job
    get_cloned_config_array.each do |config|
      min_snapshot_cycle = config[:awr_ash_snapshot_cycle]            if config[:awr_ash_active]        && config[:awr_ash_snapshot_cycle]                  < min_snapshot_cycle  # Rerun job at smallest snapshot cycle config
      min_snapshot_cycle = config[:object_size_snapshot_cycle]*60     if config[:object_size_active]    && config[:object_size_snapshot_cycle]*60   < min_snapshot_cycle  # Rerun job at smallest snapshot cycle config
      min_snapshot_cycle = config[:cache_objects_snapshot_cycle]      if config[:cache_objects_active]  && config[:cache_objects_snapshot_cycle]    < min_snapshot_cycle  # Rerun job at smallest snapshot cycle config
      min_snapshot_cycle = config[:blocking_locks_snapshot_cycle]     if config[:blocking_locks_active] && config[:blocking_locks_snapshot_cycle]   < min_snapshot_cycle  # Rerun job at smallest snapshot cycle config
    end
    min_snapshot_cycle
  end

  #
  def self.encryt_password(native_password)
    Encryption.encrypt_value(native_password, EngineConfig.config.panorama_sampler_master_password) # Encrypt password with master_password
  end

  def self.validate_entry(entry, empty_password_allowed = false)
    raise PopupMessageException.new "User name is mandatory" if (entry[:user].nil? || entry[:user] == '')
    raise PopupMessageException.new "Password is mandatory" if (entry[:password].nil? || entry[:password] == '') && !empty_password_allowed
    if entry[:awr_ash_snapshot_cycle].nil? || entry[:awr_ash_snapshot_cycle] <=0 || (60 % entry[:awr_ash_snapshot_cycle] != 0 && entry[:awr_ash_snapshot_cycle] % 60 != 0) || entry[:awr_ash_snapshot_cycle] % 5 != 0
      # Allow wrong values if master password is test password
      raise PopupMessageException.new "AWR/ASH-snapshot cycle must be a multiple of 5 minutes\nand divisible without remainder from 60 minutes or multiple of 60 minutes\ne.g. 5, 10, 15, 20, 30, 60 or 120 minutes" if EngineConfig.config.panorama_sampler_master_password != 'hugo'
    end
    raise PopupMessageException.new "AWR/ASH-napshot retention must be >= 1 day" if entry[:awr_ash_snapshot_retention] < 1

   if entry[:object_size_snapshot_cycle].nil? || entry[:object_size_snapshot_cycle] <=0 || 24 % entry[:object_size_snapshot_cycle] != 0 || entry[:object_size_snapshot_cycle]  > 24
      raise PopupMessageException.new "Object size snapshot cycle must be a divisible without remainder from 24 hours and max. 24 hours\ne.g. 1, 2, 3, 4, 6, 8, 12 or 24 hours"
    end

    raise PopupMessageException.new "Object size snapshot cycle must be >= 1 hour>"   if entry[:object_size_snapshot_cycle].nil?      || entry[:object_size_snapshot_cycle]     <=0
    raise PopupMessageException.new "Object size snapshot retention must be >= 1 day" if entry[:object_size_snapshot_retention].nil?  || entry[:object_size_snapshot_retention] < 1
  end

  # Modify some content after edit and before storage
  def self.prepare_saved_entry(entry)
    entry[:tns]                               = PanoramaConnection.get_host_tns(entry) if entry[:modus].to_sym == :host
    entry[:id]                                = entry[:id].to_i
    entry[:awr_ash_snapshot_cycle]            = entry[:awr_ash_snapshot_cycle].to_i
    entry[:awr_ash_snapshot_retention]        = entry[:awr_ash_snapshot_retention].to_i
    entry[:owner]                             = entry[:user] if entry[:owner].nil? || entry[:owner] == ''             # User is default for owner
    entry[:object_size_snapshot_cycle]        = entry[:object_size_snapshot_cycle].to_i
    entry[:object_size_snapshot_retention]    = entry[:object_size_snapshot_retention].to_i
    entry[:cache_objects_snapshot_cycle]      = entry[:cache_objects_snapshot_cycle].to_i
    entry[:cache_objects_snapshot_retention]  = entry[:cache_objects_snapshot_retention].to_i
    entry[:blocking_locks_snapshot_cycle]     = entry[:blocking_locks_snapshot_cycle].to_i
    entry[:blocking_locks_snapshot_retention] = entry[:blocking_locks_snapshot_retention].to_i

    validate_entry(entry, config_entry_exists?(entry[:id]))                     # Password required only for add, not for modify

    if entry[:password].nil? || entry[:password] == ''
      entry.delete(:password)                                                   # Preserve previous password at merge
    else
      entry[:password] = encryt_password(entry[:password])                      # Encrypt password with master_password
    end
    entry
  end

  # add new entry (parameter already prepared)
  def self.add_config_entry(entry)
    validate_entry(entry)
    @@config_access_mutex.synchronize do
      get_config_array.each do |c|
        raise "ID #{entry[:id]} is already used" if c[:id] == entry[:id]        # Ensure unique IDs
      end
      get_config_array << entry
      write_config_array_to_store
    end
  end

  # modify entry (parameter already prepared)
  def self.modify_config_entry(entry)
    @@config_access_mutex.synchronize do
      org_entry = get_config_entry_by_id(entry[:id])
      validate_entry(org_entry.merge(entry))                                    # Validate resulting merged entry
      org_entry.merge!(entry)                                                   # Do real merge if validation passed
      write_config_array_to_store
    end
  end

  def self.delete_config_entry(p_id)
    @@config_access_mutex.synchronize do
      get_config_array.each_index do |i|                                        # Ensures initialization
        @@config_array.delete_at(i) if @@config_array[i][:id] == p_id.to_i
      end
      write_config_array_to_store
    end
  end

  # Set error state
  def self.set_error_message(id, message)
    PanoramaSamplerConfig.modify_config_entry({
                                                  :id                 => id,
                                                  :last_error_time    => Time.now,
                                                  :last_error_message => message
                                              })
  end
  private

  def self.client_info_store_key
    "panorama_sampler_master_config_#{EngineConfig.config.panorama_sampler_master_password.to_i(36)}_#{EngineConfig.config.panorama_sampler_master_password.length}"
  end

  # get array initialized from session store. Call inside Mutex.synchronize only
  def self.get_config_array
    if @@config_array.nil?
      if EngineConfig.config.panorama_sampler_master_password.nil?
        @@config_array = []                                                     # No config to read if master password is not given
      else
        @@config_array = EngineConfig.get_client_info_store.read(client_info_store_key)
        @@config_array = [] if @@config_array.nil?
      end
    end
    @@config_array
  end

  #  Call inside Mutex.synchronize only
  def self.write_config_array_to_store
    EngineConfig.get_client_info_store.write(client_info_store_key, @@config_array)
  rescue Exception =>e
    Rails.logger.error("Exception '#{e.message}' raised while writing file store at '#{EngineConfig.config.client_info_filename}'")
    raise "Exception '#{e.message}' while writing file store at '#{EngineConfig.config.client_info_filename}'"
  end

  #  Call inside Mutex.synchronize only
  def self.get_config_entry_by_id(p_id)
    retval = get_config_entry_by_id_or_nil(p_id)
    if retval.nil?
      raise "No Panorama-Sampler config found for ID=#{p_id} class='#{p_id.class}'"
    end
    retval
  end

  #  Call inside Mutex.synchronize only
  def self.get_config_entry_by_id_or_nil(p_id)
    get_config_array.each do |c|
      return c if c[:id] == p_id
    end
    return nil
  end

end
