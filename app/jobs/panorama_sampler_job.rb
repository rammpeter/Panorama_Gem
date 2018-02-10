class PanoramaSamplerJob < ApplicationJob
  include ExceptionHelper

  queue_as :default

  SECONDS_LATE_ALLOWED = 3                                                      # x seconds delay after job creation are accepted

  def perform(*args)

    snapshot_time = Time.now.round                                              # cut subseconds

    min_snapshot_cycle = PanoramaSamplerConfig.min_snapshot_cycle

    # calculate next snapshot time from now
    last_snapshot_minute = snapshot_time.min-snapshot_time.min % min_snapshot_cycle
    last_snapshot_time = Time.new(snapshot_time.year, snapshot_time.month, snapshot_time.day, snapshot_time.hour, last_snapshot_minute, 0)
    next_snapshot_time = last_snapshot_time + min_snapshot_cycle * 60
    PanoramaSamplerJob.set(wait_until: next_snapshot_time).perform_later

    if last_snapshot_time < snapshot_time-SECONDS_LATE_ALLOWED                  # Filter first Job execution at server startup, 2 seconds delay are allowed
      Rails.logger.info "#{snapshot_time}: Job suspended because not started at exact snapshot time #{last_snapshot_time}"
      return
    end

    # Iterate over PanoramaSampler entries
    PanoramaSamplerConfig.get_config_array.each do |config|
      check_for_sampling(config, snapshot_time, :AWR_ASH)
      check_for_sampling(config, snapshot_time, :OBJECT_SIZE, 60)
      check_for_sampling(config, snapshot_time, :CACHE_OBJECTS)
      check_for_sampling(config, snapshot_time, :BLOCKING_LOCKS)
    end
  rescue Exception => e
    Rails.logger.error "Exception in PanoramaSamplerJob.perform:\n#{e.message}"
    log_exception_backtrace(e, 40)
    raise e
  end


  private
  def check_for_sampling(config, snapshot_time, domain, minute_factor = 1)

    last_snapshot_start_key = "last_#{domain.downcase}_snapshot_start".to_sym
    snapshot_cycle_minutes  = config.get_domain_snapshot_cycle(domain) * minute_factor
    last_snapshot_start     = config.get_Last_domain_snapshot_start(domain)

    if config.get_domain_active(domain) && (snapshot_time.min % snapshot_cycle_minutes == 0  ||  # exact startup time at full hour + x*snapshot_cycle
        snapshot_time.min == 0 && snapshot_time.hour % snapshot_cycle_minutes/60 == 0)  # Full hour for snapshot cycle = n*hour
      if  last_snapshot_start.nil? || (last_snapshot_start + snapshot_cycle_minutes.minutes <= snapshot_time+SECONDS_LATE_ALLOWED)  # snapshot_cycle expired ?, 2 seconds delay are allowed
        config.set_domain_last_snapshot_start(domain, snapshot_time)
        WorkerThread.create_snapshot(config, snapshot_time, domain)
      else
        Rails.logger.error "#{Time.now}: Last #{domain} snapshot start (#{last_snapshot_start}) not old enough to expire next snapshot after #{snapshot_cycle_minutes} minutes for ID=#{config[:id]} '#{config[:name]}'"
        Rails.logger.error "May be sampling is done by multiple Panorama instances?"
      end
    end

  end

end
