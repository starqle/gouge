$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "gouge/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "gouge"
  s.version     = Gouge::VERSION
  s.authors     = ["Starqle Indonesia"]
  s.email       = ["admin@starqle.com"]
  s.homepage    = "http://starqle.com"
  s.summary     = "Starqle Ruby on Rails tools and utilities"
  s.description = "Gouge is tools and utilities for Ruby on Rails"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "LICENSE.txt", "Rakefile", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", "~> 5"
  s.add_dependency "spreadsheet", "~> 1.1.1"

  s.add_development_dependency "rspec", "~> 3.4.0"
  s.add_development_dependency "sqlite3"
end
