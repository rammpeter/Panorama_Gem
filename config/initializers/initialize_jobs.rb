# Activate background-processing for Panorama-Sampler

require_relative '../../config/engine_config'
require '../../app/jobs/connection_terminate_job'
require '../../app/jobs/initialization_job'
require '../../app/jobs/panorama_sampler_job'

# Wait async to proceed rails startup before first job execution

InitializationJob.set(wait: 1.seconds).perform_later

PanoramaSamplerJob.set(wait: 5.seconds).perform_later if !EngineConfig.config.panorama_sampler_master_password.nil?

ConnectionTerminateJob.set(wait: 10.seconds).perform_later                      # Check connections for inactivity
