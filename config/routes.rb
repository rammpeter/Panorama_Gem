Rails.application.routes.draw do

  # define routes as controller/action
  # Rails.logger.info "Panorama_Gem/config/routes.rb: Setting routes for every controller action"
  EnvController.routing_actions("#{__dir__}/../app/controllers").each do |r|
    # puts "set route for #{r[:controller]}/#{r[:action]}"
    get  "#{r[:controller]}/#{r[:action]}"
    post  "#{r[:controller]}/#{r[:action]}"
  end

end