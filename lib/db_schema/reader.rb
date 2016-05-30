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
      TYPECASTED_VALUE = /\A'(.*)'/

      INDICES_QUERY = <<-SQL.freeze
SELECT relname AS name,
       indkey AS column_positions,
       indisunique AS unique,
       pg_get_expr(indpred, indrelid, true) AS condition,
       pg_get_expr(indexprs, indrelid, true) AS expression
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
SELECT column_name AS name,
       ordinal_position AS pos,
       column_default AS default,
       is_nullable AS null,
       data_type AS type,
       character_maximum_length AS length,
       numeric_precision AS precision,
       numeric_scale AS scale
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name = ?
      SQL

      class << self
        def read_schema
          DbSchema.connection.tables.map do |table_name|
            primary_key_name = DbSchema.connection.primary_key(table_name)

            fields = DbSchema.connection[COLUMN_NAMES_QUERY, table_name.to_s].map do |column_data|
              build_field(column_data, primary_key: column_data[:name] == primary_key_name)
            end

            indices = indices_data_for(table_name).map do |index_data|
              Definitions::Index.new(index_data)
            end.sort_by(&:name)

            foreign_keys = DbSchema.connection.foreign_key_list(table_name).map do |foreign_key_data|
              build_foreign_key(foreign_key_data)
            end

            Definitions::Table.new(
              table_name,
              fields:       fields,
              indices:      indices,
              foreign_keys: foreign_keys
            )
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
        def build_field(data, primary_key: false)
          type = data[:type].to_sym

          nullable = (data[:null] != 'NO')

          unless primary_key || data[:default].nil?
            if match = TYPECASTED_VALUE.match(data[:default])
              default = match[1]
            end
          end

          options = case type
          when :'character varying'
            { length: data[:length] }
          else
            {}
          end

          Definitions::Field.build(
            data[:name].to_sym,
            data[:type].to_sym,
            primary_key: primary_key,
            null:        nullable,
            default:     default,
            **options
          )
        end

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
