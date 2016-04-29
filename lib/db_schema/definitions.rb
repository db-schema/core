module DbSchema
  module Definitions
    class Field
      attr_reader :name, :type

      def initialize(name:, type:)
        @name = name.to_sym
        @type = type.to_sym
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
