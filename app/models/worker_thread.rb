# contains functions to be executed in separate manual thread
class WorkerThread
  include ExceptionHelper

  ############################### class methods as public interface ###############################
  # Check if connection may function and return DBID aof database
  def self.check_connection(sampler_config, controller)
    thread = Thread.new{WorkerThread.new(sampler_config).check_connection_internal(controller)}
    result = thread.value
    result
  rescue Exception => e
    Rails.logger.error "Exception #{e.message} raised in WorkerThread.check_connection"
    raise e
  end

  # Create snapshot for PanoramaSampler
  def self.create_snapshot(sampler_config)
    thread = Thread.new{WorkerThread.new(sampler_config).create_snapshot_internal}
  rescue Exception => e
    Rails.logger.error "Exception #{e.message} raised in WorkerThread.create_snapshot for config-ID=#{sampler_config[:id]}"
    # raise e               # Don't raise exception because it should not stop calling job processing
  end

  ############################### inner implementation ###############################

  def initialize(sampler_config)
    @sampler_config = sampler_config

    connection_config = sampler_config.clone                                    # Structure similar to database

    connection_config[:client_salt]             = EngineConfig.config.panorama_sampler_master_password
    connection_config[:management_pack_license] = :none                         # assume no management packs are licensed
    connection_config[:privilege]               = 'normal'
    connection_config[:query_timeout]           = connection_config[:snapshot_cycle]*60+60 # 1 minute more than snapshot cycle

    PanoramaConnection.set_connection_info_for_request(connection_config)

  end

  # Check if connection may function and store result in config hash
  def check_connection_internal(controller)
    dbid = PanoramaConnection.sql_select_one "SELECT DBID FROM V$Database"

    if dbid.nil?
      controller.add_statusbar_message("Trial connect to '#{@sampler_config[:name]}' not successful, see Panorama-Log for details")
      @sampler_config[:last_error_time] = Time.now
    else
      owner_exists = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Users WHERE UserName = ?", @sampler_config[:owner].upcase]
      raise "Schema-owner #{@sampler_config[:owner]} does not exists in database" if owner_exists == 0

      PanoramaConnection.sql_execute "CREATE TABLE #{@sampler_config[:owner]}.Panorama_Resource_Test(ID NUMBER)"
      PanoramaConnection.sql_execute "DROP TABLE #{@sampler_config[:owner]}.Panorama_Resource_Test"

      controller.add_statusbar_message("Trial connect to '#{@sampler_config[:name]}' successful")
      @sampler_config[:dbid] = dbid
      @sampler_config[:last_successful_connect] = Time.now
    end
    PanoramaConnection.release_connection                                       # Free DB connection in Pool
    PanoramaConnection.reset_thread_local_attributes                            # Ensure fresh thread attributes if thread is reused from pool
    dbid
  rescue Exception => e
    Rails.logger.error "Exception #{e.message} raised in WorkerThread.check_connection_internal"
    controller.add_statusbar_message("Trial connect to '#{@sampler_config[:name]}' not successful!\nExcpetion: #{e.message}\nFor details see Panorama-Log for details")
    @sampler_config[:last_error_time]    = Time.now
    @sampler_config[:last_error_message] = e.message
    PanoramaConnection.release_connection                                       # Free DB connection in Pool
    PanoramaConnection.reset_thread_local_attributes                            # Ensure fresh thread attributes if thread is reused from pool
    raise e if ENV['RAILS_ENV'] != 'test'                                       # don't log this exception in test.log
  end

  @@active_snashots = {}
  # Create snapshot in database
  def create_snapshot_internal
    if @@active_snashots[ @sampler_config[:id]]
      Rails.logger.error("Previous snapshot creation not yet finshed for ID=#{@sampler_config[:id]} (#{@sampler_config[:name]}), no snapshot created! Restart Panorama server if this problem persists.")
      PanoramaSamplerConfig.set_error_message(@sampler_config[:id], "Previous snapshot creation not yet finshed, no snapshot created! Restart Panorama server if this problem persists.")
      return
    end

    Rails.logger.info "Create new snapshot for ID=#{@sampler_config[:id]}, Name='#{@sampler_config[:name]}'"

    @@active_snashots[@sampler_config[:id]] = true                              # Create semaphore for thread, begin processing
    db_time = PanoramaConnection.sql_select_one "SELECT SYSDATE FROM Dual"
    PanoramaSamplerConfig.modify_config_entry({:id => @sampler_config[:id], :last_successful_connect => Time.now }) # Set after first successful SQL
    PanoramaSamplerStructureCheck.do_check(@sampler_config)                     # Check data structure preconditions
    PanoramaSamplerSampling.do_sampling(@sampler_config)                        # Do Sampling (without active session history)
    PanoramaSamplerSampling.do_housekeeping(@sampler_config)                    # Do housekeeping

    # End activities after finishing snapshot
    Rails.logger.info "Finished creating new snapshot for ID=#{@sampler_config[:id]}, Name='#{@sampler_config[:name]}'"
    @@active_snashots.delete(@sampler_config[:id])                              # Remove semaphore
    PanoramaConnection.release_connection                                       # Free DB connection in Pool
    PanoramaConnection.reset_thread_local_attributes                            # Ensure fresh thread attributes if thread is reused from pool
  rescue Exception => e
    begin
      @@active_snashots.delete(@sampler_config[:id])                              # Remove semaphore
      Rails.logger.error("Error #{e.message} during WorkerThread.create_snapshot_internal for ID=#{@sampler_config[:id]} (#{@sampler_config[:name]})")
      log_exception_backtrace(e, 20) if ENV['RAILS_ENV'] != 'test'
      PanoramaSamplerConfig.set_error_message(@sampler_config[:id], "Error #{e.message} during WorkerThread.create_snapshot_internal")
      PanoramaConnection.release_connection                                       # Free DB connection in Pool
      PanoramaConnection.reset_thread_local_attributes                            # Ensure fresh thread attributes if thread is reused from pool
      raise e
    rescue Exception => x
      Rails.logger.error "WorkerThread.create_snapshot_internal: Exception #{x.message} in exception handler"
      log_exception_backtrace(x, 40)
      raise x
    end
  end

end