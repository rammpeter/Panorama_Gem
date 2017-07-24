# Activate background-processing for Panorama-Sampler

require 'config/engine_config'

PanoramaSamplerJob.perform_later if !EngineConfig.config.panorama_sampler_master_password.nil?
