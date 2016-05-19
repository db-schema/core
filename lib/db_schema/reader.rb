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
            fields = DbSchema.connection.schema(table_name).map do |field_name, field_details|
              Definitions::Field.new(
                name:         field_name,
                type:         translate_type(field_details[:db_type]),
                primary_key:  field_details[:primary_key],
                null:         field_details[:allow_null],
                default:      field_details[:ruby_default]
              )
            end

            indices = DbSchema.connection.indexes(table_name).map do |index_name, index_details|
              Definitions::Index.new(
                name:   index_name,
                fields: index_details[:columns],
                unique: index_details[:unique]
              )
            end

            foreign_keys = DbSchema.connection.foreign_key_list(table_name).map do |foreign_key_data|
              build_foreign_key(foreign_key_data)
            end

            Definitions::Table.new(
              name:         table_name,
              fields:       fields,
              indices:      indices,
              foreign_keys: foreign_keys
            )
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

      private
        def build_foreign_key(data)
          keys = if data[:key] == [primary_keys[data[:table]].to_sym]
            [] # this foreign key references a primary key
          else
            data[:key]
          end

          Definitions::ForeignKey.new(
            name:       data[:name],
            fields:     data[:columns],
            table:      data[:table],
            keys:       keys,
            on_delete:  data[:on_delete],
            on_update:  data[:on_update],
            deferrable: data[:deferrable]
          )
        end

        def primary_keys
          @primary_keys ||= DbSchema.connection.tables.reduce({}) do |primary_keys, table_name|
            primary_keys.merge(table_name => DbSchema.connection.primary_key(table_name))
          end
        end
      end
    end

    registry['postgres'] = Postgres
  end
end
