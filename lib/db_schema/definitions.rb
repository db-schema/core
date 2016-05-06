require 'dry/equalizer'

module DbSchema
  module Definitions
    class Field
      attr_reader :name, :type, :default

      def initialize(name:, type:, primary_key: false, null: true, default: nil, has_sequence: false)
        @name         = name.to_sym
        @type         = type.to_sym
        @primary_key  = primary_key
        @null         = null
        @default      = default
        @has_sequence = has_sequence
      end

      def primary_key?
        @primary_key
      end

      def null?
        @null
      end

      def has_sequence?
        @has_sequence
      end
    end

    class Index
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

    class Table
      include Dry::Equalizer(:name, :fields, :indices)
      attr_reader :name, :fields, :indices

      def initialize(name:, fields: [], indices: [])
        @name    = name.to_sym
        @fields  = fields
        @indices = indices
      end
    end
  end
end
