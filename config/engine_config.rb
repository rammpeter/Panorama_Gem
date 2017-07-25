class EngineConfig < Rails::Application
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.

  # Verzeichnis für permanent zu schreibende Dateien
  config.panorama_var_home = "."
  config.panorama_var_home = ENV['PANORAMA_VAR_HOME'] if ENV['PANORAMA_VAR_HOME']

  # Password for access on Panorama-Sampler config: Panorama-Sampler and his menu are activated if password is not empty
  config.panorama_sampler_master_password = ENV['PANORAMA_SAMPLER_MASTER_PASSWORD']  ? ENV['PANORAMA_SAMPLER_MASTER_PASSWORD'] : nil

  # Textdatei zur Erfassung der Panorama-Nutzung
  # Sicherstellen, dass die Datei ausserhalb der Applikation zu liegen kommt und Deployment der Applikation überlebt durch Definition von ENV['PANORAMA_VAR_HOME']
  config.usage_info_filename = "#{config.panorama_var_home}/Usage.log"

  # File-Store für ActiveSupport::Cache::FileStore
  config.client_info_filename = "#{config.panorama_var_home}/client_info.store"

  @@client_store_mutex = Mutex.new
  def self.get_client_info_store
    if !defined?($login_client_store) || $login_client_store.nil?
      @@client_store_mutex.synchronize do                                       # Ensure that only one thread is allowed to process
        if !defined?($login_client_store) || $login_client_store.nil?
          $login_client_store = ActiveSupport::Cache::FileStore.new(EngineConfig.config.client_info_filename)
          Rails.logger.info("Local directory for client-info store is #{EngineConfig.config.client_info_filename}")
          @@client_store_mutex = nil                                            # Free mutex that will never be used
        end
      end
    end
    $login_client_store
  rescue Exception =>e
    raise "Exception '#{e.message}' while creating file store at '#{EngineConfig.config.client_info_filename}'"
  end


  # -- begin rails3 relikt
  # Configure the default encoding used in templates for Ruby 1.9.
  #config.encoding = "utf-8"

  # Added 15.02.2012, utf8-Problem unter MAcOS nicht gelöst
  #Encoding.default_internal, Encoding.default_external = ['utf-8'] * 2

  # Configure sensitive parameters which will be filtered from the log file.
  #config.filter_parameters += [:password]

  # Enable escaping HTML in JSON.
  #config.active_support.escape_html_entities_in_json = true

  # Enable the asset pipeline
  config.assets.enabled = true

  # Don't disable subit button after click
  config.action_view.automatically_disable_submit_tag = false
end
