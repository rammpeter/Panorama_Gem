# contains functions to be executed in separate manual thread
class WorkerThread

  # Check if connection may function and return DBID aof database
  def self.check_connection(sampler_config)
    thread = Thread.new{WorkerThread.new(sampler_config).check_connection_internal}
    thread.join
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

  def check_connection_internal
    PanoramaConnection.sql_select_one "SELECT DBID FROM V$Database"
  rescue Exception => e
    Rails.logger.error "Exception #{e.message} raised in check_connection_internal"
    raise e
  end

end