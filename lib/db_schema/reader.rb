module DbSchema
  module Reader
    class << self
      def read_schema(connection)
        reader_for(connection).read_schema(connection)
      end

      def read_table(table_name, connection)
        reader_for(connection).read_table(table_name, connection)
      end

      def read_enums(connection)
        reader_for(connection).read_enums(connection)
      end

      def read_extensions(connection)
        reader_for(connection).read_extensions(connection)
      end

    private
      def reader_for(connection)
        case connection.adapter_scheme
        when :postgres
          unless defined?(Reader::Postgres)
            raise 'You need the \'db_schema-reader-postgres\' gem in order to work with PostgreSQL database structure.'
          end

          Reader::Postgres
        else
          raise NotImplementedError, "DbSchema::Reader does not support #{connection.adapter_scheme}."
        end
      end
    end
  end
end
