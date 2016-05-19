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

      def index(fields, name:, unique: false)
        indices << Definitions::Index.new(
          name:   name,
          fields: Array(fields),
          unique: unique
        )
      end

      def foreign_key(fields, references:, name: nil)
        fkey_fields = Array(fields)
        fkey_name = name || :"#{table_name}_#{fkey_fields.first}_fkey"

        if references.is_a?(Array)
          # [:table, :field]
          referenced_table, *referenced_keys = references

          foreign_keys << Definitions::ForeignKey.new(
            name:   fkey_name,
            fields: fkey_fields,
            table:  referenced_table,
            keys:   referenced_keys
          )
        else
          # :table
          foreign_keys << Definitions::ForeignKey.new(
            name:   fkey_name,
            fields: fkey_fields,
            table:  references
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
