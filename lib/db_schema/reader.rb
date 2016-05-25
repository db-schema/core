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
      INDICES_QUERY = <<-SQL.freeze
SELECT relname AS name,
       indkey AS column_positions,
       indisunique AS unique,
       pg_get_expr(indpred, indrelid, true) AS condition
  FROM pg_class, pg_index
 WHERE pg_class.oid = pg_index.indexrelid
   AND pg_class.oid IN (
    SELECT indexrelid
      FROM pg_index, pg_class
     WHERE pg_class.relname = ?
       AND pg_class.oid = pg_index.indrelid
       AND indisprimary != 't'
)
      SQL

      COLUMN_NAMES_QUERY = <<-SQL.freeze
SELECT ordinal_position AS pos, column_name AS name
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = ?
      SQL

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

            indices = indices_data_for(table_name).map do |index_data|
              Definitions::Index.new(index_data)
            end.sort_by(&:name)

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

        def indices_data_for(table_name)
          column_names = DbSchema.connection[COLUMN_NAMES_QUERY, table_name.to_s].reduce({}) do |names, column|
            names.merge(column[:pos] => column[:name])
          end

          DbSchema.connection[INDICES_QUERY, table_name.to_s].map do |index|
            positions = index[:column_positions].split(' ').map(&:to_i)
            names = column_names.values_at(*positions).map(&:to_sym)

            {
              name:      index[:name].to_sym,
              fields:    names,
              unique:    index[:unique],
              condition: index[:condition]
            }
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
