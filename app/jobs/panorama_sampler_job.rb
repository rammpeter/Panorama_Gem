class PanoramaSamplerJob < ApplicationJob
  include ExceptionHelper

  queue_as :default

  def perform(*args)

    min_snapshot_cycle = 60                                                     # at least every hour run job
    PanoramaSamplerConfig.get_cloned_config_array.each do |config|
      min_snapshot_cycle = config[:snapshot_cycle] if config[:snapshot_cycle] < min_snapshot_cycle  # Rerrun job at smallest snapshot cycle config
    end

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
    PanoramaSamplerJob.set(wait: (min_snapshot_cycle-0.2).minutes).perform_later    # Start 12 seconds before to ensure end of minute is hit exactly
sleep 60
Rails.logger.info "################ Sleep fulfilled"
    # Iterate over PanoramaSampler entries
    PanoramaSamplerConfig.get_cloned_config_array.each do |config|
      if config[:active] && (snapshot_time.strftime('%M').to_i % config[:snapshot_cycle] == 0  ||  # exact startup time at full hour + x*snapshot_cycle
                             snapshot_time.strftime('%M').to_i == 0 && snapshot_time.strftime('%H') % config[:snapshot_cycle]/60 == 0)  # Full hour for snapshot cycle = n*hour
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
