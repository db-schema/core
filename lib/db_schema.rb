require 'sequel'

require 'db_schema/configuration'
require 'db_schema/utils'
require 'db_schema/definitions'
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

    def configuration
      raise 'You must call DbSchema.configure in order to connect to the database.' if @configuration.nil?

      @configuration
    end

    def reset!
      @configuration = nil
      @connection    = nil
    end
  end
end
