guard :rspec, cmd: 'bundle exec rspec', all_on_start: true do
  require 'guard/rspec/dsl'
  dsl = Guard::RSpec::Dsl.new(self)

  # RSpec files
  rspec = dsl.rspec
  watch(rspec.spec_helper)  { rspec.spec_dir }
  watch(rspec.spec_support) { rspec.spec_dir }
  watch(rspec.spec_files)

  # Ruby files
  ruby = dsl.ruby
  dsl.watch_spec_files_for(ruby.lib_files)
  watch(%r{lib/db_schema/definitions\.rb})    { rspec.spec_dir }
  watch(%r{lib/db_schema/definitions/.*\.rb}) { rspec.spec_dir }
  watch(%r{lib/db_schema/operations\.rb})     { rspec.spec_dir }
  watch('lib/db_schema/utils.rb')             { rspec.spec_dir }
end
