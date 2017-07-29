class PanoramaSamplerJob < ApplicationJob
  queue_as :default

  MIN_SNAPSHOT_CYCLE=2
  def perform(*args)

    # Wait until Time is at 5-minutes-bound
    while Time.now.strftime('%M').to_i % MIN_SNAPSHOT_CYCLE != 0
      sleep 1
    end
    # reschedule the job in 4 minutes
    PanoramaSamplerJob.set(wait: (MIN_SNAPSHOT_CYCLE-1).minutes).perform_later

    # Iterate over PanoramaSampler entries
    PanoramaSamplerConfig.get_cloned_config_array.each do |config|
      if config[:active]
        WorkerThread.create_snapshot(config)
      end
    end
  end
end
