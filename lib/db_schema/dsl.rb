module DbSchema
  class DSL
    attr_reader :block

    def initialize(block)
      @block = block
    end

    def schema
      block.call(self)

      tables
    end

    def table(name, &block)
      table_yielder = TableYielder.new(name, block)

      tables << Definitions::Table.new(
        name:         name,
        fields:       table_yielder.fields,
        indices:      table_yielder.indices,
        foreign_keys: table_yielder.foreign_keys
      )
    end

  private
    def tables
      @tables ||= []
    end

    class TableYielder
      attr_reader :table_name

      def initialize(table_name, block)
        @table_name = table_name
        block.call(self)
      end

      %i(integer varchar).each do |type|
        define_method(type) do |name, **options|
          field(name, type, options)
        end
      end

      def field(name, type, primary_key: false, null: true, default: nil)
        fields << Definitions::Field.new(
          name:         name,
          type:         type,
          primary_key:  primary_key,
          null:         null,
          default:      default
        )
      end

      def index(fields, name:, unique: false, where: nil)
        indices << Definitions::Index.new(
          name:      name,
          fields:    Array(fields),
          unique:    unique,
          condition: where
        )
      end

      def foreign_key(fields, references:, name: nil, on_update: :no_action, on_delete: :no_action, deferrable: false)
        fkey_fields = Array(fields)
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

      def fields
        @fields ||= []
      end

      def indices
        @indices ||= []
      end

      def foreign_keys
        @foreign_keys ||= []
      end
    end
  end
end
