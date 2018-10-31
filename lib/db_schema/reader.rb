module DbSchema
  module Reader
    class << self
      def reader_for(connection)
        case connection.adapter_scheme
        when :postgres
          unless defined?(Reader::Postgres)
            raise 'You need the \'db_schema-reader-postgres\' gem in order to work with PostgreSQL database structure.'
          end

          Reader::Postgres.new(connection)
        else
          raise NotImplementedError, "DbSchema::Reader does not support #{connection.adapter_scheme}."
        end
      end
    end
  end
end
