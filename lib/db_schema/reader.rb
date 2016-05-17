module DbSchema
  module Reader
    class << self
      def read_schema
        adapter.read_schema
      end

      def adapter
        adapter_name = DbSchema.configuration.adapter
        registry.fetch(adapter_name) do |adapter_name|
          raise NotImplementedError, "DbSchema::Reader does not support #{adapter_name}."
        end
      end

    private
      def registry
        @registry ||= {}
      end
    end

    module Postgres
      class << self
        def read_schema
          DbSchema.connection.tables.map do |table_name|
            has_sequence = !DbSchema.connection.primary_key_sequence(table_name).nil?

            fields = DbSchema.connection.schema(table_name).map do |field_name, field_details|
              Definitions::Field.new(
                name:         field_name,
                type:         translate_type(field_details[:db_type]),
                primary_key:  field_details[:primary_key],
                null:         field_details[:allow_null],
                default:      field_details[:ruby_default],
                has_sequence: field_details[:primary_key] && has_sequence
              )
            end

            indices = DbSchema.connection.indexes(table_name).map do |index_name, index_details|
              Definitions::Index.new(
                name:   index_name,
                fields: index_details[:columns],
                unique: index_details[:unique]
              )
            end

            Definitions::Table.new(name: table_name, fields: fields, indices: indices)
          end
        end

        def translate_type(postgres_type)
          case postgres_type
          when /^character varying/
            :varchar
          else
            postgres_type
          end
        end
      end
    end

    registry['postgres'] = Postgres
  end
end
