source 'https://rubygems.org'

# Declare your gem's dependencies in panorama_gem.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.


# Specific path for nulldb not nbecessary from rel. 0.3.7
#gem 'activerecord-nulldb-adapter', :git => 'http://github.com/mnoack/nulldb', :branch =>'rails5'

gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem 'puma'

group :test do
  gem 'selenium-webdriver'
  #gem "chromedriver-helper"
  gem "webdrivers"
  gem "minitest-rails-capybara", ">= 3.0.1" # Under Linux otherwise version 0.0.2 is installed
  gem "minitest-reporters"

  gem "capybara"
  #gem "capybara-webkit"
  gem "launchy"
end
