module DbSchema
  module Definitions
    class Field
      attr_reader :name, :type, :default

      def initialize(name:, type:, primary_key: false, null: true, default: nil)
        @name        = name.to_sym
        @type        = type.to_sym
        @primary_key = primary_key
        @null        = null
        @default     = default
      end

      def primary_key?
        @primary_key
      end

      def null?
        @null
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
      attr_reader :name, :fields, :indices

      def initialize(name:, fields: [], indices: [])
        @name    = name.to_sym
        @fields  = fields
        @indices = indices
      end
    end
  end
end
