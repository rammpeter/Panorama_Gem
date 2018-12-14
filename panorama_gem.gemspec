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
  s.add_dependency "rails", "5.2.1"

  s.add_dependency 'activerecord-nulldb-adapter'
  s.add_dependency 'activerecord-oracle_enhanced-adapter'     # lokal in Gemfile überschreiben mit : gem 'activerecord-oracle_enhanced-adapter', github: 'rsim/oracle-enhanced', branch: 'rails42'

  # Use SCSS for stylesheets
  #s.add_dependency  'sass-rails', '~> 5.0'

  #s.add_dependency  'turbolinks'                                                # needed for redirect_to

end
