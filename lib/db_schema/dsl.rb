module DbSchema
  class DSL
    attr_reader :block

    def initialize(block)
      @block  = block
      @schema = []
    end

    def schema
      block.call(self)

      @schema
    end

    def table(name, &block)
      table_yielder = TableYielder.new(name, block)

      @schema << Definitions::Table.new(
        name,
        fields:       table_yielder.fields,
        indices:      table_yielder.indices,
        checks:       table_yielder.checks,
        foreign_keys: table_yielder.foreign_keys
      )
    end

    def enum(name, values)
      @schema << Definitions::Enum.new(name.to_sym, values.map(&:to_sym))
    end

    def extension(name)
      @schema << Definitions::Extension.new(name.to_sym)
    end

    class TableYielder
      attr_reader :table_name

      def initialize(table_name, block)
        @table_name = table_name
        block.call(self)
      end

      DbSchema::Definitions::Field.registry.keys.each do |type|
        define_method(type) do |name, **options|
          field(name, type, options)
        end
      end

      def primary_key(name)
        fields << Definitions::Field::Integer.new(name, primary_key: true)
      end

      def field(name, type, **options)
        fields << Definitions::Field.build(name, type, options)
      end

      def index(*fields, name: nil, unique: false, using: :btree, where: nil, **ordered_fields)
        index_fields = fields.map do |field_name|
          Definitions::Index::Field.new(field_name.to_sym)
        end + ordered_fields.map do |field_name, field_order_options|
          options = case field_order_options
          when :asc
            {}
          when :desc
            { order: :desc }
          when :asc_nulls_first
            { nulls: :first }
          when :desc_nulls_last
            { order: :desc, nulls: :last }
          else
            raise ArgumentError, 'Only :asc, :desc, :asc_nulls_first and :desc_nulls_last options are supported.'
          end

          Definitions::Index::Field.new(field_name.to_sym, **options)
        end

        index_name = name || "#{table_name}_#{index_fields.map(&:name).join('_')}_index"

        indices << Definitions::Index.new(
          name:      index_name,
          fields:    index_fields,
          unique:    unique,
          type:      using,
          condition: where
        )
      end

      def check(name, condition)
        checks << Definitions::CheckConstraint.new(name: name, condition: condition)
      end

      def foreign_key(*fkey_fields, references:, name: nil, on_update: :no_action, on_delete: :no_action, deferrable: false)
        fkey_name = name || :"#{table_name}_#{fkey_fields.first}_fkey"

        if references.is_a?(Array)
          # [:table, :field]
          referenced_table, *referenced_keys = references

          foreign_keys << Definitions::ForeignKey.new(
            name:       fkey_name,
            fields:     fkey_fields,
            table:      referenced_table,
            keys:       referenced_keys,
            on_delete:  on_delete,
            on_update:  on_update,
            deferrable: deferrable
          )
        else
          # :table
          foreign_keys << Definitions::ForeignKey.new(
            name:       fkey_name,
            fields:     fkey_fields,
            table:      references,
            on_delete:  on_delete,
            on_update:  on_update,
            deferrable: deferrable
          )
        end
      end

      def method_missing(method_name, name, *args, &block)
        options = args.first || {}

        fields << Definitions::Field::Custom.new(
          name,
          type_name: method_name,
          **options
        )
      end

      def fields
        @fields ||= []
      end

      def indices
        @indices ||= []
      end

      def checks
        @checks ||= []
      end

      def foreign_keys
        @foreign_keys ||= []
      end
    end
  end
end
