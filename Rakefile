require 'rubygems'
require 'rake'
require './lib/yumrepo'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "yumrepo"
  gem.version = YumRepo::VERSION
  gem.homepage = "http://github.com/rubiojr/yumrepo"
  gem.license = "MIT"
  gem.summary = %Q{YUM Repository Metadata handling library}
  gem.description = %Q{YUM Repository Metadata handling library}
  gem.email = "rubiojr@frameos.org"
  gem.authors = ["Sergio Rubio"]
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  #  gem.add_runtime_dependency 'jabber4r', '> 0.1'
  gem.add_runtime_dependency 'nokogiri'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'fakeweb'
end
Jeweler::RubygemsDotOrgTasks.new

task :default => :build

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "yumrepo #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
