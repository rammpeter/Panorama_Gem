Rails.application.routes.draw do

  # define routes as controller/action
  EnvController.routing_actions.each do |r|
    puts "set route for #{r[:controller]}/#{r[:action]}"
    get  "#{r[:controller]}/#{r[:action]}"
    post  "#{r[:controller]}/#{r[:action]}"
  end

end