# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
#noinspection RubyResolve
require 'mvn2/version'

Gem::Specification.new do |spec|
  spec.name        = 'mvn2'
  spec.version     = Mvn2::VERSION
  spec.authors     = ['Eric Henderson']
  spec.email       = ['henderea@gmail.com']
  spec.summary     = %q{Maven helper}
  spec.description = %q{a Ruby script that runs a maven build, including (or not including) tests, and only outputs the lines that come after a compile failure, build success, test result, or reactor summary start line}
  spec.homepage    = 'https://github.com/henderea/mvn2'
  spec.license     = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake', '~> 10'

  spec.add_dependency 'everyday-cli-utils', '~> 1.8', '>= 1.8.1'
  spec.add_dependency 'everyday-plugins', '~> 1.2'
end