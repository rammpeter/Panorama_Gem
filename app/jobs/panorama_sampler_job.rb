class PanoramaSamplerJob < ApplicationJob
  include ExceptionHelper

  queue_as :default

  def perform(*args)

    snapshot_time = Time.now.round                                              # cut subseconds

    min_snapshot_cycle = PanoramaSamplerConfig.min_snapshot_cycle

    # calculate next snapshot time from now
    last_snapshot_minute = snapshot_time.min-snapshot_time.min % min_snapshot_cycle
    last_snapshot_time = Time.new(snapshot_time.year, snapshot_time.month, snapshot_time.day, snapshot_time.hour, last_snapshot_minute, 0)
    next_snapshot_time = last_snapshot_time + min_snapshot_cycle * 60
    PanoramaSamplerJob.set(wait_until: next_snapshot_time).perform_later

    if last_snapshot_time < snapshot_time                                                 # First Job execution at server startup
      Rails.logger.info "#{snapshot_time}: Job suspended because not started at exact snapshot time #{last_snapshot_time}"
      return
    end

=begin
    snapshot_time = Time.now.round                                              # Cut subseconds
    # Wait until Time is at bound of smallest snapshot_cycle and exactly at minute bound
    while snapshot_time.strftime('%M').to_i % min_snapshot_cycle != 0 || snapshot_time.strftime('%S').to_i != 0
      sleeptime = 1 - Time.now.nsec.to_f/1000000000
      sleep sleeptime                                # sleep as long to match the next full second
      # Rails.logger.info "Sleeping #{sleeptime} seconds"
      snapshot_time = Time.now.round                                            # Cut subseconds
    end
    # Rails.logger.info "Starting with snapshot_time=#{Time.now.iso8601(10)}"

    # reschedule the job 12 seconds before next snapshot cycle

    #PanoramaSamplerJob.set(wait_until: Date.tomorrow.noon).perform_later(guest)
    PanoramaSamplerJob.set(wait_until: .perform_later    # Start 12 seconds before to ensure end of minute is hit exactly

=end
    # Iterate over PanoramaSampler entries
    PanoramaSamplerConfig.get_cloned_config_array.each do |config|
      if config[:active] && (snapshot_time.min % config[:snapshot_cycle] == 0  ||  # exact startup time at full hour + x*snapshot_cycle
                             snapshot_time.min == 0 && snapshot_time.hour % config[:snapshot_cycle]/60 == 0)  # Full hour for snapshot cycle = n*hour
        if config[:last_snapshot_start].nil? || (config[:last_snapshot_start]+(config[:snapshot_cycle]).minutes <= snapshot_time) && # snapshot_cycle expired ?
          PanoramaSamplerConfig.modify_config_entry({id: config[:id], last_snapshot_start: snapshot_time})
          WorkerThread.create_snapshot(config, snapshot_time)
          PanoramaSamplerConfig.modify_config_entry({id: config[:id], last_snapshot_end: Time.now})
        else
          Rails.logger.error "#{Time.now}: Last snapshot start (#{config[:last_snapshot_start]}) not old enough to expire next snapshot after #{config[:snapshot_cycle]} minutes for ID=#{config[:id]} '#{config[:name]}'"
          Rails.logger.error "May be sampling is done by multiple Panorama instances?"
        end
      end
    end
  rescue Exception => e
    Rails.logger.error "Exception in PanoramaSamplerJob.perform:\n#{e.message}"
    log_exception_backtrace(e, 40)
    raise e
  end
end
