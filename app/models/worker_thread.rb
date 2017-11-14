# contains functions to be executed in separate manual thread
class WorkerThread
  include ExceptionHelper

  ############################### class methods as public interface ###############################
  # Check if connection may function and return DBID of database
  def self.check_connection(sampler_config, controller)
    thread = Thread.new{WorkerThread.new(sampler_config, 'check_connection').check_connection_internal(controller)}
    result = thread.value
    result
  rescue Exception => e
    Rails.logger.error "Exception #{e.message} raised in WorkerThread.check_connection"
    raise e
  end

  # Generic create snapshot
  def self.create_snapshot(sampler_config, snapshot_time, domain)
    if domain == :AWR_ASH
      WorkerThread.new(sampler_config, 'check_structure_synchron').check_structure_synchron # Ensure existence of objects necessary for both Threads, synchron with job's thread
      thread = Thread.new{WorkerThread.new(sampler_config, 'ash_sampler_daemon').create_ash_sampler_daemon(snapshot_time)} # Start PL/SQL daemon that does ASH-sampling, terminates before next snapshot

      create_snapshot(sampler_config, snapshot_time, :AWR)                      # recall method with changed domain
    else
      thread = Thread.new{WorkerThread.new(sampler_config, "create #{domain} snapshot").create_snapshot_internal(snapshot_time, domain)}  # Excute the snapshot and terminate
    end
  rescue Exception => e
    Rails.logger.error "Exception #{e.message} raised in WorkerThread.create_snapshot for config-ID=#{sampler_config[:id]} and domain=#{domain}"
    # Don't raise exception because it should not stop calling job processing
  end


  ############################### inner implementation ###############################

  def initialize(sampler_config, action_name)
    @sampler_config = sampler_config

    connection_config = sampler_config.clone                                    # Structure similar to database

    connection_config[:client_salt]             = EngineConfig.config.panorama_sampler_master_password
    connection_config[:management_pack_license] = :none                         # assume no management packs are licensed
    connection_config[:privilege]               = 'normal'
    connection_config[:query_timeout]           = connection_config[:awr_ash_snapshot_cycle]*60+60 # 1 minute more than snapshot cycle
    connection_config[:current_controller_name] = 'WorkerThread'
    connection_config[:current_action_name]     = action_name

    PanoramaConnection.set_connection_info_for_request(connection_config)

  end

  # Check if connection may function and store result in config hash
  def check_connection_internal(controller)
    # Remove all connections from pool for this target to ensure connect with new credentials

    dbid = PanoramaConnection.sql_select_one "SELECT DBID FROM V$Database"

    if dbid.nil?
      controller.add_statusbar_message("Trial connect to '#{@sampler_config[:name]}' not successful, see Panorama-Log for details")
      @sampler_config[:last_error_time] = Time.now
    else
      PanoramaSamplerConfig.check_for_select_any_table!(@sampler_config)        # Persist existence of grant

      owner_exists = PanoramaConnection.sql_select_one ["SELECT COUNT(*) FROM All_Users WHERE UserName = ?", @sampler_config[:owner].upcase]
      raise "Schema-owner #{@sampler_config[:owner]} does not exists in database" if owner_exists == 0

      PanoramaConnection.sql_execute "CREATE TABLE #{@sampler_config[:owner]}.Panorama_Resource_Test(ID NUMBER)"
      PanoramaConnection.sql_execute "DROP TABLE #{@sampler_config[:owner]}.Panorama_Resource_Test"

      controller.add_statusbar_message("Trial connect to '#{@sampler_config[:name]}' successful")
      @sampler_config[:dbid] = dbid
      @sampler_config[:last_successful_connect] = Time.now
    end
    PanoramaConnection.release_connection                                       # Free DB connection in Pool
    dbid
  rescue Exception => e
    Rails.logger.error "Exception #{e.message} raised in WorkerThread.check_connection_internal"
    controller.add_statusbar_message("Trial connect to '#{@sampler_config[:name]}' not successful!\nExcpetion: #{e.message}\nFor details see Panorama-Log for details")
    @sampler_config[:last_error_time]    = Time.now
    @sampler_config[:last_error_message] = e.message
    PanoramaConnection.release_connection                                       # Free DB connection in Pool
    raise e if ENV['RAILS_ENV'] != 'test'                                       # don't log this exception in test.log
  end

  # Execute first part of job synchroneous with job's PanoramaConnection
  @@synchron__structure_checks = {}                                             # Prevent multiple jobs from being active
  def check_structure_synchron
    if @@synchron__structure_checks[ @sampler_config[:id]]
      Rails.logger.error("Previous check_structure_synchron not yet finshed for ID=#{@sampler_config[:id]} (#{@sampler_config[:name]}), no synchroneous structure check is done! Restart Panorama server if this problem persists.")
      PanoramaSamplerConfig.set_error_message(@sampler_config[:id], "Previous check_structure_synchron not yet finshed, no synchroneous structure check is done! Restart Panorama server if this problem persists.")
      return
    end

    @@synchron__structure_checks[@sampler_config[:id]] = true                   # Create semaphore for thread, begin processing
    PanoramaSamplerStructureCheck.do_check(@sampler_config, :ASH)               # Check data structure preconditions, but only for ASH-tables
    @@synchron__structure_checks.delete(@sampler_config[:id])                   # Remove semaphore
    PanoramaConnection.release_connection                                       # Free DB connection in Pool
  rescue Exception => e
    @@synchron__structure_checks.delete(@sampler_config[:id])                   # Remove semaphore
    Rails.logger.error("Error #{e.message} during WorkerThread.check_structure_synchron for ID=#{@sampler_config[:id]} (#{@sampler_config[:name]})")
    log_exception_backtrace(e, 20) if ENV['RAILS_ENV'] != 'test'
    PanoramaSamplerConfig.set_error_message(@sampler_config[:id], "Error #{e.message} during WorkerThread.check_structure_synchron")
    PanoramaConnection.release_connection                                       # Free DB connection in Pool
    raise e
  end


  @@active_ash_daemons = {}
  # Create snapshot in database
  def create_ash_sampler_daemon(snapshot_time)
    # Wait for end of previous ASH sampler daemon if not yet terminated
    loop_count = 0
    while @@active_ash_daemons[ @sampler_config[:id]] && loop_count < 600  # wait max. 60 seconds for previous ASH sampler daemon to terminate
      sleep 0.1
      loop_count += 1
    end
    if @@active_ash_daemons[ @sampler_config[:id]]
      Rails.logger.error("Previous ASH daemon not yet finshed for ID=#{@sampler_config[:id]} (#{@sampler_config[:name]}), new ASH daemon for snapshot not started! Restart Panorama server if this problem persists.")
      PanoramaSamplerConfig.set_error_message(@sampler_config[:id], "Previous ASH daemon not yet finshed, new ASH daemon for snapshot not started! Restart Panorama server if this problem persists.")
      return
    end

    Rails.logger.info "#{Time.now}: Create new ASH daemon for ID=#{@sampler_config[:id]}, Name='#{@sampler_config[:name]}'"

    @@active_ash_daemons[@sampler_config[:id]] = true                           # Create semaphore for thread, begin processing
    # Check data structure only for ASH-tables is already done in check_structure_synchron
    PanoramaSamplerSampling.run_ash_daemon(@sampler_config, snapshot_time)      # Start ASH daemon

    # End activities after finishing snapshot
    Rails.logger.info "#{Time.now}: ASH daemon terminated for ID=#{@sampler_config[:id]}, Name='#{@sampler_config[:name]}'"
  rescue Exception => e
    begin
      Rails.logger.error("Error #{e.message} during WorkerThread.create_ash_sampler_daemon for ID=#{@sampler_config[:id]} (#{@sampler_config[:name]})")
      log_exception_backtrace(e, 20) if ENV['RAILS_ENV'] != 'test'
      PanoramaSamplerConfig.set_error_message(@sampler_config[:id], "Error #{e.message} during WorkerThread.create_ash_sampler_daemon")
      raise e
    rescue Exception => x
      Rails.logger.error "WorkerThread.create_ash_sampler_daemon: Exception #{x.message} in exception handler"
      log_exception_backtrace(x, 40)
      raise x
    end
  rescue Object => e
    Rails.logger.error("Exception #{e.class} during WorkerThread.create_ash_sampler_daemon for ID=#{@sampler_config[:id]} (#{@sampler_config[:name]})")
    PanoramaSamplerConfig.set_error_message(@sampler_config[:id], "Exception #{e.class} during WorkerThread.create_ash_sampler_daemon")
    raise e
  ensure
    @@active_ash_daemons.delete(@sampler_config[:id])                           # Remove semaphore
    PanoramaConnection.release_connection                                       # Free DB connection in Pool
  end

  # Generic method to create snapshots
  @@active_snapshots = {}
  def create_snapshot_internal(snapshot_time, domain)
    snapshot_semaphore_key = "#{@sampler_config[:id]}_#{domain}"
    if @@active_snapshots[snapshot_semaphore_key]
      Rails.logger.error("Previous #{domain} snapshot not yet finshed for ID=#{@sampler_config[:id]} (#{@sampler_config[:name]}), new object size snapshot not started! Restart Panorama server if this problem persists.")
      PanoramaSamplerConfig.set_error_message(@sampler_config[:id], "Previous #{domain} snapshot not yet finshed, new object size snapshot not started! Restart Panorama server if this problem persists.")
      return
    end

    Rails.logger.info "#{Time.now}: Create new #{domain} snapshot for ID=#{@sampler_config[:id]}, Name='#{@sampler_config[:name]}'"

    @@active_snapshots[snapshot_semaphore_key] = true                 # Create semaphore for thread, begin processing

    PanoramaSamplerConfig.modify_config_entry(@sampler_config[:id], { last_successful_connect: Time.now, "last_#{domain.downcase}_snapshot_instance".to_sym => PanoramaConnection.instance_number }) # Set after first successful SQL

    PanoramaSamplerStructureCheck.do_check(@sampler_config, :AWR) if domain == :AWR   # Check data structure preconditions, but nor for ASH-tables

    PanoramaSamplerSampling.do_sampling(@sampler_config, snapshot_time, domain)  # Do Sampling
    PanoramaSamplerSampling.do_housekeeping(@sampler_config, false, domain) # Do housekeeping without shrink space

    # End activities after finishing snapshot
    PanoramaSamplerConfig.modify_config_entry(@sampler_config[:id], {"last_#{domain.downcase}_snapshot_end".to_sym => Time.now})
    Rails.logger.info "#{Time.now}: Finished creating new #{domain} snapshot for ID=#{@sampler_config[:id]}, Name='#{@sampler_config[:name]}' and domain=#{domain}"
  rescue Exception => e
    begin
      Rails.logger.error("Error #{e.message} during WorkerThread.create_snapshot_internal for ID=#{@sampler_config[:id]} (#{@sampler_config[:name]}) and domain=#{domain}")
      log_exception_backtrace(e, 30) if ENV['RAILS_ENV'] != 'test'
      PanoramaSamplerStructureCheck.do_check(@sampler_config, domain)       # Check data structure preconditions first in case of error
      PanoramaSamplerSampling.do_housekeeping(@sampler_config, true, domain)   # Do housekeeping also in case of exception to clear full tablespace quota etc. + shrink space
      if domain == :AWR
        raise e
      else
        PanoramaSamplerSampling.do_sampling(@sampler_config, snapshot_time, domain)  # Retry sampling
      end
    rescue Exception => x
      Rails.logger.error "WorkerThread.create_snapshot_internal: Exception #{x.message} in exception handler for ID=#{@sampler_config[:id]} (#{@sampler_config[:name]}) and domain=#{domain}"
      log_exception_backtrace(x, 40)
      PanoramaSamplerConfig.set_error_message(@sampler_config[:id], "Error #{e.message} during WorkerThread.create_snapshot_internal for domain=#{domain}")
      raise x
    end
  rescue Object => e
    Rails.logger.error("Exception #{e.class} during WorkerThread.create_snapshot_internal for ID=#{@sampler_config[:id]} (#{@sampler_config[:name]}) and domain=#{domain}")
    PanoramaSamplerConfig.set_error_message(@sampler_config[:id], "Exception #{e.class} during WorkerThread.create_snapshot_internal for domain=#{domain}")
    raise e
  ensure
    @@active_snapshots.delete(snapshot_semaphore_key)                           # Remove semaphore
Rails.logger.info "Release_Connection for create_snapshot_internal"
    PanoramaConnection.release_connection                                       # Free DB connection in Pool
  end

end