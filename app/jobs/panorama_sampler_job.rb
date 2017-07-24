class PanoramaSamplerJob < ApplicationJob
  queue_as :default

  def perform(*args)
    puts "#################################### Job started #{self.object_id}#"
    sleep 60
    puts "#################################### Job ended #{self.object_id}"
  end
end
