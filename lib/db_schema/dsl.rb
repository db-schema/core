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
      table_yielder = TableYielder.new(block)

      tables << Definitions::Table.new(
        name:    name,
        fields:  table_yielder.fields,
        indices: table_yielder.indices
      )
    end

  private
    def tables
      @tables ||= []
    end

    class TableYielder
      def initialize(block)
        block.call(self)
      end

      %i(integer varchar).each do |type|
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

      def index(fields, name:, unique: false)
        indices << Definitions::Index.new(
          name:   name,
          fields: Array(fields),
          unique: unique
        )
      end

      def fields
        @fields ||= []
      end

      def indices
        @indices ||= []
      end
    end
  end
end
