module DbSchema
  module Definitions
    class ForeignKey
      include Dry::Equalizer(:name, :fields, :table, :keys, :on_update, :on_delete, :deferrable?)
      attr_reader :name, :fields, :table, :keys, :on_update, :on_delete

      def initialize(name:, fields:, table:, keys: [], on_update: :no_action, on_delete: :no_action, deferrable: false)
        @name       = name
        @fields     = fields
        @table      = table
        @keys       = keys
        @on_update  = on_update
        @on_delete  = on_delete
        @deferrable = deferrable
      end

      def references_primary_key?
        keys.empty?
      end

      def deferrable?
        @deferrable
      end

      def options
        {
          deferrable: deferrable?,
          name:       name,
          on_delete:  on_delete,
          on_update:  on_update
        }.tap do |options|
          options[:key] = keys unless references_primary_key?
        end
      end
    end

    class NullForeignKey < ForeignKey
      def initialize
        @fields = []
        @keys   = []
      end
    end
  end
end
