require 'sequel'
require 'yaml'

require 'db_schema/configuration'
require 'db_schema/utils'
require 'db_schema/definitions'
require 'db_schema/awesome_print'
require 'db_schema/dsl'
require 'db_schema/reader'
require 'db_schema/changes'
require 'db_schema/runner'
require 'db_schema/version'

module DbSchema
  class << self
    def describe(&block)
      desired_schema = DSL.new(block).schema
      actual_schema  = Reader.read_schema

      changes = Changes.between(desired_schema, actual_schema)
      log_changes(changes) if configuration.debug?
      Runner.new(changes).run!
    end

    def connection
      @connection ||= Sequel.connect(
        adapter:  configuration.adapter,
        host:     configuration.host,
        port:     configuration.port,
        database: configuration.database,
        user:     configuration.user,
        password: configuration.password
      )
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
    def log_changes(changes)
      if changes.respond_to?(:ai)
        puts changes.ai
      else
        puts changes.inspect
      end
    end
  end
end
