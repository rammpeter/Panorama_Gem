$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "panorama_gem/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name          = "panorama_gem"
  s.version       = PanoramaGem::VERSION
  s.authors       = ["Peter Ramm"]
  s.email         = ["Peter@ramm-oberhermsdorf.de"]
  s.summary       = %q{Tool for monitoring performance issues of Oracle databases}
  s.description   = %q{Web-tool for monitoring performance issues of Oracle databases.
Provides easy access to several internal information.
Aims to issues that are inadequately analyzed and presented by other existing tools such as Enterprise Manager.
}
  s.homepage      = "https://github.com/rammpeter/Panorama_Gem"
  s.license       = "GNU General Public License"

  s.files = Dir["{app,config,lib}/**/*", "Rakefile", "README.md", "README.rdoc"]

  #  use exactly this rails version
  # s.add_dependency "rails", "6.1.3"

  # Alternative instead of complete rails including actioncable etc., prev. version was 6.0.4
  s.add_dependency  "activerecord",   "6.1.3"
  s.add_dependency  "activemodel",    "6.1.3"
  s.add_dependency  "actionpack",     "6.1.3"
  s.add_dependency  "actionview",     "6.1.3"
  s.add_dependency  "actionmailer",   "6.1.3"
  s.add_dependency  "activejob",      "6.1.3"
  s.add_dependency  "activesupport",  "6.1.3"
  s.add_dependency  "railties",       "6.1.3"

  s.add_dependency 'activerecord-nulldb-adapter'
  s.add_dependency 'activerecord-oracle_enhanced-adapter'     

  # s.add_dependency 'nokogiri'

  # sass-rails pinned to 5.0 which depends on sass, current sass-rails (6.0) depends on sassc which is incompatible with warbler
  s.add_dependency  'sass-rails', '~> 5.0'

  # TODO: i18n 1.8.8, 1.8.9 leads to Uncaught exception: undefined method `deep_merge!' for {}:Concurrent::Hash
  # Check if following versions fix this error
  s.add_dependency 'i18n', '1.8.7'


end
