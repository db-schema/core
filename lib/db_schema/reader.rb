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
      DEFAULT_VALUE = /\A('(?<string>.*)')|(?<float>\d+\.\d+)|(?<integer>\d+)/

      INDICES_QUERY = <<-SQL.freeze
   SELECT relname AS name,
          indkey AS column_positions,
          indisunique AS unique,
          indoption AS index_options,
          pg_get_expr(indpred, indrelid, true) AS condition,
          pg_get_expr(indexprs, indrelid, true) AS expression,
          amname AS index_type
     FROM pg_class, pg_index
LEFT JOIN pg_opclass
       ON pg_opclass.oid = ANY(pg_index.indclass::int[])
LEFT JOIN pg_am
       ON pg_am.oid = pg_opclass.opcmethod
    WHERE pg_class.oid = pg_index.indexrelid
      AND pg_class.oid IN (
     SELECT indexrelid
       FROM pg_index, pg_class
      WHERE pg_class.relname = ?
        AND pg_class.oid = pg_index.indrelid
        AND indisprimary != 't'
)
  GROUP BY name, column_positions, indisunique, index_options, condition, expression, index_type
      SQL

      COLUMN_NAMES_QUERY = <<-SQL.freeze
   SELECT c.column_name AS name,
          c.ordinal_position AS pos,
          c.column_default AS default,
          c.is_nullable AS null,
          c.data_type AS type,
          c.character_maximum_length AS char_length,
          c.numeric_precision AS num_precision,
          c.numeric_scale AS num_scale,
          c.datetime_precision AS dt_precision,
          c.interval_type,
          e.data_type AS element_type
     FROM information_schema.columns AS c
LEFT JOIN information_schema.element_types AS e
       ON e.object_catalog = c.table_catalog
      AND e.object_schema = c.table_schema
      AND e.object_name = c.table_name
      AND e.object_type = 'TABLE'
      AND e.collection_type_identifier = c.dtd_identifier
    WHERE c.table_schema = 'public'
      AND c.table_name = ?
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
            options   = index[:index_options].split(' ').map(&:to_i)

            fields = column_names.values_at(*positions).zip(options).map do |column_name, column_order_options|
              options = case column_order_options
              when 0
                {}
              when 3
                { order: :desc }
              when 2
                { nulls: :first }
              when 1
                { order: :desc, nulls: :last }
              end

              DbSchema::Definitions::Index::Field.new(column_name.to_sym, **options)
            end

            {
              name:      index[:name].to_sym,
              fields:    fields,
              unique:    index[:unique],
              type:      index[:index_type].to_sym,
              condition: index[:condition]
            }
          end
        end

      private
        def build_field(data, primary_key: false)
          type = data[:type].to_sym.downcase

          nullable = (data[:null] != 'NO')

          unless primary_key || data[:default].nil?
            if match = DEFAULT_VALUE.match(data[:default])
              default = if match[:string]
                match[:string]
              elsif match[:integer]
                match[:integer].to_i
              elsif match[:float]
                match[:float].to_f
              end
            end
          end

          options = case type
          when :character, :'character varying', :bit, :'bit varying'
            Utils.rename_keys(
              Utils.filter_by_keys(data, :char_length),
              char_length: :length
            )
          when :numeric
            Utils.rename_keys(
              Utils.filter_by_keys(data, :num_precision, :num_scale),
              num_precision: :precision,
              num_scale: :scale
            )
          when :'timestamp without time zone',
               :'timestamp with time zone',
               :'time without time zone',
               :'time with time zone'
            Utils.rename_keys(
              Utils.filter_by_keys(data, :dt_precision),
              dt_precision: :precision
            )
          when :interval
            Utils.rename_keys(
              Utils.filter_by_keys(data, :dt_precision, :interval_type),
              dt_precision: :precision
            ) do |attributes|
              if interval_type = attributes.delete(:interval_type)
                attributes[:fields] = interval_type.gsub(/\(\d\)/, '').downcase.to_sym
              end
            end
          when :array
            Utils.rename_keys(Utils.filter_by_keys(data, :element_type)) do |attributes|
              attributes[:of] = attributes[:element_type].to_sym
            end
          else
            {}
          end

          Definitions::Field.build(
            data[:name].to_sym,
            type,
            primary_key: primary_key,
            null:        nullable,
            default:     default,
            **options
          )
        end

        def build_foreign_key(data)
          keys = if data[:key] == [primary_key_for(data[:table])]
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

        def primary_key_for(table_name)
          if pkey = primary_keys[table_name]
            pkey.to_sym
          end
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
