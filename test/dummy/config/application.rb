 require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)
require "panorama_gem"

 # Possibly requied by Rails 7.0.4
 # require "sprockets/railtie"
module Dummy
  class Application < Rails::Application
    # Possibly requied by Rails 7.0.4
    # config.load_defaults 7.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
  end
end

