class PanoramaSamplerJob < ApplicationJob
  queue_as :default

  MIN_SNAPSHOT_CYCLE=2
  def perform(*args)

    # Wait until Time is at 5-minutes-bound
    while Time.now.strftime('%M').to_i % MIN_SNAPSHOT_CYCLE != 0
      sleep 1
    end

    snapshot_time = Time.now

    # reschedule the job in 4 minutes
    PanoramaSamplerJob.set(wait: (MIN_SNAPSHOT_CYCLE-0.2).minutes).perform_later    # Start 12 seconds before to ensure end of minute is hit exactly

    # Iterate over PanoramaSampler entries
    PanoramaSamplerConfig.get_cloned_config_array.each do |config|
      if config[:active]
        if config[:last_snapshot_time].nil? || config[:last_snapshot_time]+(config[:snapshot_cycle]).minutes <= snapshot_time
          PanoramaSamplerConfig.modify_config_entry({id: config[:id], last_snapshot_time: snapshot_time})
          WorkerThread.create_snapshot(config)
        end
      end
    end
  end
end
