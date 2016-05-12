require 'dry/equalizer'

module DbSchema
  module Definitions
    class Field
      include Dry::Equalizer(:name, :type, :primary_key?, :null?, :default, :has_sequence?)
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

      def options
        {}.tap do |options|
          options[:primary_key] = true if primary_key?
          options[:null] = false unless null?
          options[:default] = default unless default.nil?
        end
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
