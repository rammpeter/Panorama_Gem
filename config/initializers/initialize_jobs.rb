# Activate background-processing for Panorama-Sampler

require_relative '../../config/engine_config'

# Wait async to proceed rails startup before first job execution
 PanoramaSamplerJob.set(wait: 5.seconds).perform_later if !EngineConfig.config.panorama_sampler_master_password.nil?

 ConnectionTerminateJob.set(wait: 10.seconds).perform_later                      # Check connections for inactivity
