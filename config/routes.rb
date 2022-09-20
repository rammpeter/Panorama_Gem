Rails.application.routes.draw do

  get 'panorama_sampler/show_config'

  # define routes as controller/action
  # Rails.logger.info "Panorama_Gem/config/routes.rb: Setting routes for every controller action"
  sleep_count = 0
  while EnvController.routing_actions("#{__dir__}/../app/controllers").count == 0 && sleep_count < 10 do
    puts "Rails.application.routes.draw: EnvController.routing_actions is still empty! Retrying..."
    sleep 1
    sleep_count +=1
  end
  EnvController.routing_actions("#{__dir__}/../app/controllers").each do |r|
    # puts "set route for #{r[:controller]}/#{r[:action]}"
    get  "#{r[:controller]}/#{r[:action]}"
    post  "#{r[:controller]}/#{r[:action]}"
  end

end