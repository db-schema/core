module DbSchema
  module DSL
    class << self
      def schema_from_block(block)
        block.call(self)

        tables
      end

      def table(name, &block)
        table_yielder = TableYielder.new(block)
        tables << Definitions::Table.new(name: name, fields: table_yielder.fields)
      end

    private
      def tables
        @tables ||= []
      end
    end

    class TableYielder
      def initialize(block)
        block.call(self)
      end

      %i(integer string).each do |type|
        define_method(type) do |name, **options|
          field(name, type, options)
        end
      end

      def field(name, type, primary_key: false, null: true, default: nil)
        fields << Definitions::Field.new(
          name:        name,
          type:        type,
          primary_key: primary_key,
          null:        null,
          default:     default
        )
      end

      def fields
        @fields ||= []
      end
    end
  end
end
