# Stores Config-object in memory and synchronizes access to session store on disk
class PanoramaSamplerConfig
  @@config_array = nil                                                          # First access loads it from session store
  @@config_access_mutex = Mutex.new

  # Get copy of config array incl. cloned elements for display etc.
  def self.get_cloned_config_array
    retval = []
    @@config_access_mutex.synchronize do
      get_config_array.each{|c| retval << c.clone}
    end
    retval
  end

  def self.get_cloned_config_entry(p_id)
    @@config_access_mutex.synchronize do
      return get_config_entry_by_id(p_id).clone
    end
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

  #
  def self.encryt_password(native_password)
    Encryption.encrypt_value(native_password, EngineConfig.config.panorama_sampler_master_password) # Encrypt password with master_password
  end

  def self.validate_entry(entry, mode)
    raise "Password is mandatory" if (entry[:password].nil? || entry[:password] == '') && mode == :add
  end

  # Modify some content after edit
  def self.prepare_saved_entry(entry)
    entry[:tns]                 = PanoramaConnection.get_host_tns(entry) if entry[:modus].to_sym == :host
    entry[:id]                  = entry[:id].to_i
    entry[:snapshot_retention]  = entry[:snapshot_retention].to_i

    if entry[:password].nil? || entry[:password] == ''
      entry.delete(:password)                                                   # Preserve previous password at merge
    else
      entry[:password] = encryt_password(entry[:password])                      # Encrypt password with master_password
    end
    entry
  end

  def self.add_config_entry(entry)
    validate_entry(entry, :add)
    @@config_access_mutex.synchronize do
      get_config_array.each do |c|
        raise "ID #{entry[:id]} is already used" if c[:id] == entry[:id]        # Ensure unique IDs
      end
      get_config_array << prepare_saved_entry(entry)                            # Ensures initialization
      write_config_array_to_store
    end
  end

  def self.modify_config_entry(entry)
    validate_entry(entry, :edit)
    @@config_access_mutex.synchronize do
      org_entry = get_config_entry_by_id(entry[:id])
      org_entry.merge!(prepare_saved_entry(entry))
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

  private

  def self.client_info_store_key
    "panorama_sampler_master_config_#{EngineConfig.config.panorama_sampler_master_password.to_i(36)}_#{EngineConfig.config.panorama_sampler_master_password.length}"
  end

  # get array initialized from session store. Call inside Mutex.synchronize only
  def self.get_config_array
    if @@config_array.nil?
      @@config_array = EngineConfig.get_client_info_store.read(client_info_store_key)
      @@config_array = [] if @@config_array.nil?
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
    get_config_array.each do |c|
      return c if c[:id] == p_id
    end
    raise "No Panorama-Sampler config found for ID=#{p_id} class='#{p_id.class}'"
  end

end
