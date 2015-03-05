require File.join(File.dirname(__FILE__), "lib", "archieml", "version")

Gem::Specification.new do |gem|
  gem.name          = "archieml"
  gem.version       = Archieml::VERSION
  gem.authors       = ["Michael Strickland"]
  gem.email         = ["michael.strickland@nytimes.com"]
  gem.description   = %q{Parse Archie Markup Language documents}
  gem.summary       = %q{Archieml is a Ruby parser for the Archie Markup Language (ArchieML)}
  gem.homepage      = "http://archieml.org"
  gem.license       = "Apache License 2.0"
  gem.files         = `git ls-files`.split($\)
  gem.test_files    = gem.files.grep(%r{^spec/})
  gem.require_paths = ["lib"]
end
