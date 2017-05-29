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

      def table(table_name)
        tables.find { |table| table.name == table_name } || NullTable.new
      end
      alias_method :[], :table

      def has_table?(table_name)
        !table(table_name).is_a?(NullTable)
      end

      def has_enum?(enum_name)
        enums.any? { |enum| enum.name == enum_name }
      end

      def has_extension?(extension_name)
        extensions.any? { |extension| extension.name == extension_name }
      end
    end
  end
end
