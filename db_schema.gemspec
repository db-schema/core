lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'db_schema/version'

Gem::Specification.new do |spec|
  spec.name          = 'db_schema'
  spec.version       = DbSchema::VERSION
  spec.authors       = ['Vsevolod Romashov']
  spec.email         = ['7@7vn.ru']

  spec.summary       = 'Declarative database schema definition.'
  spec.description   = 'A database schema management tool that reads a "single-source-of-truth" schema definition from a ruby file and auto-migrates the database to conform to it.'
  spec.homepage      = 'https://github.com/db-schema/core'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r(^spec/)) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r(^exe/)) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'sequel'
  spec.add_runtime_dependency 'dry-equalizer', '~> 0.2'
  spec.add_runtime_dependency 'db_schema-definitions', '~> 0.1.1'

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'awesome_print', '~> 1.7'

  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'guard-rspec'
  spec.add_development_dependency 'terminal-notifier'
  spec.add_development_dependency 'terminal-notifier-guard'

  spec.add_development_dependency 'db_schema-reader-postgres', '~> 0.1.1'
end
