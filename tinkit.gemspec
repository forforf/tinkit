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
end
