require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "tinkit"
  gem.homepage = "http://github.com/forforf/tinkit"
  gem.license = "Apache v2" #license is Apache v2
  gem.summary = %Q{Tinkit, a portable persistence layer for cloud, file systems, and other persistent stores}
  gem.description = %Q{Tinkit provides a portable persistence layer that adopts to your data, not the other way around.}
  gem.email = "dmarti21@gmail.com"
  gem.authors = ["Dave M"]

  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  #  gem.add_runtime_dependency 'jabber4r', '> 0.1'
  #  gem.add_development_dependency 'rspec', '> 1.2.3'
  #core dependencies
  gem.add_dependency "log4r", "~> 1.1.9"
  gem.add_dependency "mime-types", "~> 1.16"
  #CouchDB interface dependencies
  gem.add_dependency "couchrest", "~> 1.0.2"
  gem.add_dependency "couchrest_extended_document", "~> 1.0.0"
  gem.add_dependency "rest-client", "~> 1.6.1"
  #mysql interface dependencies

end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "tinkit #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
