require 'sequel'
require 'yaml'

require 'db_schema/configuration'
require 'db_schema/utils'
require 'db_schema/definitions'
require 'db_schema/awesome_print'
require 'db_schema/dsl'
require 'db_schema/validator'
require 'db_schema/reader'
require 'db_schema/changes'
require 'db_schema/runner'
require 'db_schema/version'

module DbSchema
  class << self
    def describe(&block)
      desired_schema = DSL.new(block).schema
      validate(desired_schema)

      actual_schema = Reader.read_schema
      changes = Changes.between(desired_schema, actual_schema)
      return if changes.empty?

      log_changes(changes) if configuration.debug?
      Runner.new(changes).run!

      if configuration.post_check_enabled?
        unapplied_changes = Changes.between(desired_schema, Reader.read_schema)

        if unapplied_changes.any?
          readable_changes = if unapplied_changes.respond_to?(:ai)
            unapplied_changes.ai
          else
            unapplied_changes.inspect
          end

          message = <<-ERROR
Your database still differs from the expected schema after applying it; if you are 100% sure this is ok you can turn these checks off with DbSchema.configure(post_check: false). Here are the differences:

#{readable_changes}
          ERROR

          raise SchemaMismatch, message
        end
      end
    end

    def connection
      @connection ||= Sequel.connect(
        adapter:  configuration.adapter,
        host:     configuration.host,
        port:     configuration.port,
        database: configuration.database,
        user:     configuration.user,
        password: configuration.password
      ).tap do |db|
        db.extension :pg_enum
        db.extension :pg_array
      end
    end

    def configure(connection_parameters)
      @configuration = Configuration.new(connection_parameters)
      @connection    = nil
    end

    def configure_from_yaml(yaml_path, environment)
      data = Utils.symbolize_keys(YAML.load_file(yaml_path))
      filtered_data = Utils.filter_by_keys(
        data[environment.to_sym],
        *%i(adapter host port database username password)
      )
      renamed_data = Utils.rename_keys(filtered_data, username: :user)

      configure(renamed_data)
    end

    def configuration
      raise 'You must call DbSchema.configure in order to connect to the database.' if @configuration.nil?

      @configuration
    end

    def reset!
      @configuration = nil
      @connection    = nil
    end

  private
    def validate(schema)
      validation_result = Validator.validate(schema)

      unless validation_result.valid?
        message = "Requested schema is invalid:\n\n"

        validation_result.errors.each do |error|
          message << "* #{error}\n"
        end

        raise InvalidSchemaError, message
      end
    end

    def log_changes(changes)
      return if changes.empty?

      puts 'DbSchema is applying these changes to the database:'
      if changes.respond_to?(:ai)
        puts changes.ai
      else
        puts changes.inspect
      end
    end
  end

  class InvalidSchemaError < ArgumentError; end
  class SchemaMismatch < RuntimeError; end
  class UnsupportedOperation < ArgumentError; end
end
