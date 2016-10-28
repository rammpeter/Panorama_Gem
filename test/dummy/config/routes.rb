require 'env_controller'

Rails.application.routes.draw do
  # route geenrated from rails engine
  # mount Panorama::Engine => "/panorama"

  #mount Panorama::Engine => "/"

  # set routing info for engine
  EnvController.routing_actions.each do |r|
    puts "set route for #{r[:controller]}/#{r[:action]}"
    get  "#{r[:controller]}/#{r[:action]}"
    post  "#{r[:controller]}/#{r[:action]}"
  end

  root  'env#index'
end
