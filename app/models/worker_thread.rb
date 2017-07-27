# contains functions to be executed in separate manual thread
class WorkerThread

  # Check if connection may function and return DBID aof database
  def self.check_connection(sampler_config, controller)
    thread = Thread.new{WorkerThread.new(sampler_config).check_connection_internal(sampler_config, controller)}
    result = thread.value
    result
  rescue Exception => e
    Rails.logger.error "Exception #{e.message} raised in self.check_connection"
    raise e
  end

  def initialize(sampler_config)
    @sampler_config = sampler_config

    connection_config = sampler_config.clone                                    # Structure similar to database

    connection_config[:client_salt]             = EngineConfig.config.panorama_sampler_master_password
    connection_config[:management_pack_license] = :none                         # assume no management packs are licensed
    connection_config[:privilege]               = 'normal'
    connection_config[:query_timeout]           = connection_config[:snapshot_retention]*60+60 # 1 minute more than snapshot cycle

    PanoramaConnection.set_connection_info_for_request(connection_config)

  end

  # Check if connection may function and store result in config hash
  def check_connection_internal(sampler_config, controller)
    dbid = PanoramaConnection.sql_select_one "SELECT DBID FROM V$Database"

    if dbid.nil?
      controller.add_statusbar_message("Trial connect to '#{sampler_config[:name]}' not successful, see Panorama-Log for details")
      sampler_config[:last_error_time] = Time.now
    else
      controller.add_statusbar_message("Trial connect to '#{sampler_config[:name]}' successful")
      sampler_config[:dbid] = dbid
      sampler_config[:last_successful_connect] = Time.now
    end
    dbid
  rescue Exception => e
    Rails.logger.error "Exception #{e.message} raised in WorkerThread.check_connection_internal"
    controller.add_statusbar_message("Trial connect to '#{sampler_config[:name]}' not successful!\nExcpetion: #{e.message}\nFor details see Panorama-Log for details")
    sampler_config[:last_error_time]    = Time.now
    sampler_config[:last_error_message] = e.message
    raise e
  end

end