# Stores Config-object in memory and synchronizes access to session store on disk
# noinspection RubyClassVariableUsageInspection
class PanoramaSamplerConfig
  @@config_array = nil                                                          # First access loads it from session store
  @@config_access_mutex = Mutex.new

  def initialize(config_hash = {})
    @config_hash = config_hash.clone                                            # Store config as instance element

    # Intitalize defaults
    @config_hash[:id]                                 = PanoramaSamplerConfig.get_max_id+1     if !@config_hash.has_key?(:id)
    @config_hash[:awr_ash_snapshot_cycle]             = 60    if !@config_hash.has_key?(:awr_ash_snapshot_cycle)
    @config_hash[:awr_ash_snapshot_retention]         = 32    if !@config_hash.has_key?(:awr_ash_snapshot_retention)
    @config_hash[:sql_min_no_of_execs]                = 2     if !@config_hash.has_key?(:sql_min_no_of_execs)
    @config_hash[:sql_min_runtime_millisecs]          = 10    if !@config_hash.has_key?(:sql_min_runtime_millisecs)
    @config_hash[:awr_ash_active]                     = false if !@config_hash.has_key?(:awr_ash_active)
    @config_hash[:object_size_active]                 = false if !@config_hash.has_key?(:object_size_active)
    @config_hash[:object_size_snapshot_cycle]         = 24    if !@config_hash.has_key?(:object_size_snapshot_cycle)
    @config_hash[:object_size_snapshot_retention]     = 1000  if !@config_hash.has_key?(:object_size_snapshot_retention)
    @config_hash[:cache_objects_active]               = false if !@config_hash.has_key?(:cache_objects_active)
    @config_hash[:cache_objects_snapshot_cycle]       = 30    if !@config_hash.has_key?(:cache_objects_snapshot_cycle)
    @config_hash[:cache_objects_snapshot_retention]   = 60    if !@config_hash.has_key?(:cache_objects_snapshot_retention)
    @config_hash[:blocking_locks_active]              = false if !@config_hash.has_key?(:blocking_locks_active)
    @config_hash[:blocking_locks_snapshot_cycle]      = 2     if !@config_hash.has_key?(:blocking_locks_snapshot_cycle)
    @config_hash[:blocking_locks_snapshot_retention]  = 60    if !@config_hash.has_key?(:blocking_locks_snapshot_retention)
    @config_hash[:blocking_locks_long_locks_limit]    = 10000 if !@config_hash.has_key?(:blocking_locks_long_locks_limit)
    @config_hash[:last_analyze_check_timestamp]       = nil   if !@config_hash.has_key?(:last_analyze_check_timestamp)
    @config_hash[:last_awr_ash_snapshot_start]        = nil   if !@config_hash.has_key?(:last_awr_ash_snapshot_start)
    @config_hash[:last_object_size_snapshot_start]    = nil   if !@config_hash.has_key?(:last_object_size_snapshot_start)
    @config_hash[:last_cache_objects_snapshot_start]  = nil   if !@config_hash.has_key?(:last_cache_objects_snapshot_start)
    @config_hash[:last_blocking_locks_snapshot_start] = nil   if !@config_hash.has_key?(:last_blocking_locks_snapshot_start)
  end

  def get_cloned_config_hash
    retval = @config_hash.clone
    retval.delete(:select_any_table)                                            # don't store this value, should be scanned new
    retval
  end

  def get_config_value(key)
    Rails.logger.info "PanoramaSamplerConfig.get_config_value: Missing hash key '#{key}' of class '#{key.class}' for panorama-sampler config with ID=#{get_id}" if !@config_hash.has_key?(key);
    @config_hash[key]
  end

  def get_id;                                 get_config_value(:id);                                  end
  def get_awr_ash_active;                     get_config_value(:awr_ash_active);                      end
  def get_awr_ash_snapshot_cycle;             get_config_value(:awr_ash_snapshot_cycle);              end
  def get_awr_ash_snapshot_retention;         get_config_value(:awr_ash_snapshot_retention);          end
  def get_blocking_locks_active;              get_config_value(:blocking_locks_active);               end
  def get_blocking_locks_long_locks_limit;    get_config_value(:blocking_locks_long_locks_limit);     end
  def get_blocking_locks_snapshot_cycle;      get_config_value(:blocking_locks_snapshot_cycle);       end
  def get_blocking_locks_snapshot_retention;  get_config_value(:blocking_locks_snapshot_retention);   end
  def get_cache_objects_active;               get_config_value(:cache_objects_active);                end
  def get_cache_objects_snapshot_cycle;       get_config_value(:cache_objects_snapshot_cycle);        end
  def get_cache_objects_snapshot_retention;   get_config_value(:cache_objects_snapshot_retention);    end
  def get_dbid;                               get_config_value(:dbid);                                end
  def get_name;                               get_config_value(:name);                                end
  def get_object_size_active;                 get_config_value(:object_size_active);                  end
  def get_object_size_snapshot_cycle;         get_config_value(:object_size_snapshot_cycle);          end
  def get_object_size_snapshot_retention;     get_config_value(:object_size_snapshot_retention);      end
  def get_owner;                              get_config_value(:owner);                               end
  def get_sql_min_no_of_execs;                get_config_value(:sql_min_no_of_execs);                 end
  def get_sql_min_runtime_millisecs;          get_config_value(:sql_min_runtime_millisecs);           end
  def get_last_analyze_check_timestamp;       get_config_value(:last_analyze_check_timestamp);        end

  def get_domain_active(domain);              get_config_value("#{domain.downcase}_active".to_sym);               end
  def get_domain_snapshot_cycle(domain);      get_config_value("#{domain.downcase}_snapshot_cycle".to_sym);       end
  def get_Last_domain_snapshot_start(domain); get_config_value("last_#{domain.downcase}_snapshot_start".to_sym);  end

  # Does the user have SELECT ANY TABLE? This ensures that user may select V$-Tables from within packages
  def get_select_any_table
    if !@config_hash.key?(:select_any_table)
      # Check if accessing v$-tables from within PL/SQL-Package is possible
      # don't persist config change because config may be pending (not saved) for new sampler configuration
      @config_hash[:select_any_table] = (0 < PanoramaConnection.sql_select_one(["SELECT COUNT(*) FROM DBA_Sys_Privs WHERE Grantee = ? AND Privilege = 'SELECT ANY TABLE'", @config_hash[:user].upcase]))

      # System does not have SELECT-grant on V$-Tables from within packages! Tested for 18.3-EE and 18.4-XE
      # Ensure using anonymous PL/SQL instead of package if user is system
      @config_hash[:select_any_table] = false if @config_hash[:user].upcase == 'SYSTEM' || @config_hash[:owner].upcase == 'SYSTEM'
    end
    @config_hash[:select_any_table]
  end

  def set_select_any_table(value)
    raise "Method is for test purpose only" if ENV['RAILS_ENV'] != 'test'
    @config_hash[:select_any_table] = value
  end

  def set_domain_last_snapshot_start(domain, snapshot_time)
    @@config_access_mutex.synchronize do
      @config_hash["last_#{domain.downcase}_snapshot_start".to_sym] = snapshot_time
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  def set_domain_last_snapshot_end(domain, snapshot_time)
    @@config_access_mutex.synchronize do
      @config_hash["last_#{domain.downcase}_snapshot_end".to_sym] = snapshot_time
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  def set_error_message(message)
    @@config_access_mutex.synchronize do
      @config_hash[:last_error_time]    = Time.now
      @config_hash[:last_error_message] = message
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  def clear_error_message
    @@config_access_mutex.synchronize do
      @config_hash[:last_error_time] = nil
      @config_hash[:last_error_message] = nil
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  def last_successful_connect(domain, instance)
    @@config_access_mutex.synchronize do
      @config_hash[:last_successful_connect] = Time.now
      @config_hash["last_#{domain.downcase}_snapshot_instance".to_sym] = instance
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  def set_last_analyze_check_timestamp
    @@config_access_mutex.synchronize do
      @config_hash[:last_analyze_check_timestamp] = Time.now
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  # Modify object with values from hash
  def modify(modified_config_hash)
    @@config_access_mutex.synchronize do
      org_config_hash = get_cloned_config_hash                                  # Use cloned hash for validation test
      PanoramaSamplerConfig.validate_entry(org_config_hash.merge(modified_config_hash)) # Validate resulting merged entry
      @config_hash.merge!(modified_config_hash)                                 # Do real merge if validation passed
      PanoramaSamplerConfig.write_config_array_to_store
    end
  end

  #----------------------------- class methods -----------------------------------
  # get array initialized from session store. Call inside Mutex.synchronize only
  def self.get_config_array
    if @@config_array.nil?
      @@config_access_mutex.synchronize do
        if EngineConfig.config.panorama_sampler_master_password.nil?
          @@config_array = []                                                     # No config to read if master password is not given
        else
          config_hash_array = EngineConfig.get_client_info_store.read(client_info_store_key)  # get stored values as Hash
          config_hash_array = [] if config_hash_array.nil?
          @@config_array = config_hash_array.map{|config_hash| PanoramaSamplerConfig.new(config_hash)} # Store instances in array
        end
      end
    end
    @@config_array
  end

  def self.get_config_entry_by_id(p_id)
    retval = get_config_entry_by_id_or_nil(p_id)
    if retval.nil?
      raise "No Panorama-Sampler config found for ID=#{p_id} class='#{p_id.class}'"
    end
    retval
  end

  def self.get_config_entry_by_id_or_nil(p_id)
    get_config_array.each do |c|
      return c if c.get_id == p_id.to_i
    end
    return nil
  end

  def self.sampler_schema_for_dbid(dbid)
    get_config_array.each do |config|
      return config.get_owner if config.get_dbid == dbid
    end
    nil
  end

  def self.get_max_id
    retval = 0
    get_config_array.each do |config|
      retval = config.get_id if config.get_id > retval
    end
    retval
  end

  def self.min_snapshot_cycle
    min_snapshot_cycle = 60                                                     # at least every hour run job
    get_config_array.each do |config|
      min_snapshot_cycle = config.get_awr_ash_snapshot_cycle            if config.get_awr_ash_active        && config.get_awr_ash_snapshot_cycle          < min_snapshot_cycle  # Rerun job at smallest snapshot cycle config
      min_snapshot_cycle = config.get_object_size_snapshot_cycle*60     if config.get_object_size_active    && config.get_object_size_snapshot_cycle*60   < min_snapshot_cycle  # Rerun job at smallest snapshot cycle config
      min_snapshot_cycle = config.get_cache_objects_snapshot_cycle      if config.get_cache_objects_active  && config.get_cache_objects_snapshot_cycle    < min_snapshot_cycle  # Rerun job at smallest snapshot cycle config
      min_snapshot_cycle = config.get_blocking_locks_snapshot_cycle     if config.get_blocking_locks_active && config.get_blocking_locks_snapshot_cycle   < min_snapshot_cycle  # Rerun job at smallest snapshot cycle config
    end
    min_snapshot_cycle
  end

  #
  def self.encryt_password(native_password)
    Encryption.encrypt_value(native_password, EngineConfig.config.panorama_sampler_master_password) # Encrypt password with master_password
  end

  def self.validate_entry(config_hash, empty_password_allowed = false)
    raise PopupMessageException.new "User name is mandatory" if (config_hash[:user].nil? || config_hash[:user] == '')
    raise PopupMessageException.new "Password is mandatory" if (config_hash[:password].nil? || config_hash[:password] == '') && !empty_password_allowed
    if config_hash[:awr_ash_snapshot_cycle].nil? || config_hash[:awr_ash_snapshot_cycle] <=0 || (60 % config_hash[:awr_ash_snapshot_cycle] != 0 && config_hash[:awr_ash_snapshot_cycle] % 60 != 0) || config_hash[:awr_ash_snapshot_cycle] % 5 != 0
      # Allow wrong values if master password is test password
      raise PopupMessageException.new "AWR/ASH-snapshot cycle must be a multiple of 5 minutes\nand divisible without remainder from 60 minutes or multiple of 60 minutes\ne.g. 5, 10, 15, 20, 30, 60 or 120 minutes" if EngineConfig.config.panorama_sampler_master_password != 'hugo'
    end
    raise PopupMessageException.new "AWR/ASH-napshot retention must be >= 1 day" if config_hash[:awr_ash_snapshot_retention].nil? || config_hash[:awr_ash_snapshot_retention] < 1

    if config_hash[:object_size_snapshot_cycle].nil? || config_hash[:object_size_snapshot_cycle] <=0 || 24 % config_hash[:object_size_snapshot_cycle] != 0 || config_hash[:object_size_snapshot_cycle]  > 24
      raise PopupMessageException.new "Object size snapshot cycle must be a divisible without remainder from 24 hours and max. 24 hours\ne.g. 1, 2, 3, 4, 6, 8, 12 or 24 hours"
    end

    raise PopupMessageException.new "Object size snapshot cycle must be >= 1 hour>"   if config_hash[:object_size_snapshot_cycle].nil?      || config_hash[:object_size_snapshot_cycle]     <=0
    raise PopupMessageException.new "Object size snapshot retention must be >= 1 day" if config_hash[:object_size_snapshot_retention].nil?  || config_hash[:object_size_snapshot_retention] < 1
  end

  def self.config_entry_exists?(p_id)
    return !get_config_entry_by_id_or_nil(p_id).nil?
  end

  # add new entry (parameter already prepared)
  def self.add_config_entry(entry_hash)
    validate_entry(entry_hash)
    @@config_access_mutex.synchronize do
      get_config_array.each do |c|
        raise "ID #{entry_hash[:id]} is already used" if c.get_id == entry_hash[:id].to_i        # Ensure unique IDs
      end
      get_config_array << PanoramaSamplerConfig.new(entry_hash)
      write_config_array_to_store
    end
  end

  def self.delete_config_entry(p_id)
    @@config_access_mutex.synchronize do
      get_config_array.each_index do |i|                                        # Ensures initialization
        @@config_array.delete_at(i) if @@config_array[i].get_id == p_id.to_i
      end
      write_config_array_to_store
    end
  end


  #-------------- not validated class methods --------------



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
    entry[:blocking_locks_long_locks_limit]   = entry[:blocking_locks_long_locks_limit].to_i

    # Ensure that SYS always logs in as sysdba
    entry[:privilege]                         = :sysdba if entry[:user].upcase == 'SYS'

    validate_entry(entry, config_entry_exists?(entry[:id]))                     # Password required only for add, not for modify

    if entry[:password].nil? || entry[:password] == ''
      entry.delete(:password)                                                   # Preserve previous password at merge
    else
      entry[:password] = encryt_password(entry[:password])                      # Encrypt password with master_password
    end
    entry
  end


  private

  def self.client_info_store_key
    "panorama_sampler_master_config_#{EngineConfig.config.panorama_sampler_master_password.to_i(36)}_#{EngineConfig.config.panorama_sampler_master_password.length}"
  end


  #  Call inside Mutex.synchronize only
  def self.write_config_array_to_store
    EngineConfig.get_client_info_store.write(client_info_store_key, @@config_array.map{|config| config.get_cloned_config_hash})  # Store config array as Hash-Array
  rescue Exception =>e
    Rails.logger.error("Exception '#{e.message}' raised while writing file store at '#{EngineConfig.config.client_info_filename}'")
    raise "Exception '#{e.message}' while writing file store at '#{EngineConfig.config.client_info_filename}'"
  end


end
