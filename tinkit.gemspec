gem_spec = Gem::Specification.new do |s|
  s.name = "tinkit"
  s.rubyforge_project = s.name
  s.version = "0.0.4"
  s.date = %q{2011-01-17}
  s.description = %q{Tinkit, a portable persistence layer for cloud, disk, and others}
  s.has_rdoc = false
  s.extra_rdoc_files = ["README", "LICENSE"]
  s.summary = "Tinkit provides a portable persistence layer that adopts to your data, not the other way around."
  s.authors = ["Dave Martin"]
  s.email = "dmarti21@gmail.com"
  s.homepage = "http://github.com/forforf/tinkit"
  s.require_path = 'lib'
  s.files = %w(LICENSE README Rakefile) + Dir.glob("{lib,spec,examples}/**/*")
  #core dependencies
  s.add_dependency "log4r", "~> 1.1.9"
  s.add_dependency "mime-types", "~> 1.16"
  #CouchDB interface dependencies
  s.add_dependency "couchrest", "= 0.35"
  s.add_dependency "rest-client", "<= 1.2.0"
  #mysql interface dependencies
  s.add_dependency "dbi", "~> 0.4.5"
  s.add_dependency "dbd-mysql", "~> 0.4.4"
  #sdb/s3 dependencies (ultimately depends on lib curl
  s.add_dependency "forforf-aws-sdb", ">= 0.5.1"
  s.add_dependency "aws-s3", "~> 0.6.2"
end
