module DbSchema
  module Definitions
    class Schema
      include Dry::Equalizer(:tables, :enums, :extensions)
      attr_reader :tables, :enums, :extensions
      attr_writer :tables

      def initialize(tables: [], enums: [], extensions: [])
        @tables     = tables
        @enums      = enums
        @extensions = extensions
      end

      def [](table_name)
        tables.find { |table| table.name == table_name } || NullTable.new
      end
    end
  end
end
