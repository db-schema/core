require 'dry/equalizer'

module DbSchema
  module Definitions
    class Field
      include Dry::Equalizer(:name, :type, :primary_key?, :null?, :default)
      attr_reader :name, :type, :default

      def initialize(name:, type:, primary_key: false, null: true, default: nil)
        @name         = name.to_sym
        @type         = type.to_sym
        @primary_key  = primary_key
        @null         = null
        @default      = default
      end

      def primary_key?
        @primary_key
      end

      def null?
        !primary_key? && @null
      end

      def options
        {}.tap do |options|
          options[:null] = false unless null?
          options[:default] = default unless default.nil?
        end
      end
    end

    class Index
      include Dry::Equalizer(:name, :fields, :unique?)
      attr_reader :name, :fields

      def initialize(name:, fields:, unique: false)
        @name   = name.to_sym
        @fields = fields.map(&:to_sym)
        @unique = unique
      end

      def unique?
        @unique
      end
    end

    class ForeignKey
      attr_reader :name, :fields, :table, :keys

      def initialize(name:, fields:, table:, keys: [])
        @name   = name
        @fields = fields
        @table  = table
        @keys   = keys
      end

      def references_primary_key?
        keys.empty?
      end
    end

    class Table
      include Dry::Equalizer(:name, :fields, :indices, :foreign_keys)
      attr_reader :name, :fields, :indices, :foreign_keys

      def initialize(name:, fields: [], indices: [], foreign_keys: [])
        @name         = name.to_sym
        @fields       = fields
        @indices      = indices
        @foreign_keys = foreign_keys
      end
    end
  end
end
