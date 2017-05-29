module DbSchema
  module Definitions
    class Table
      include Dry::Equalizer(:name, :fields, :indices, :checks, :foreign_keys)
      attr_reader :name, :fields, :indices, :checks, :foreign_keys

      def initialize(name, fields: [], indices: [], checks: [], foreign_keys: [])
        @name         = name.to_sym
        @fields       = fields
        @indices      = indices
        @checks       = checks
        @foreign_keys = foreign_keys
      end

      def has_expressions?
        fields.any?(&:default_is_expression?) ||
          indices.any?(&:has_expressions?) ||
          checks.any?
      end

      def [](field_name)
        fields.find { |field| field.name == field_name } || NullField.new
      end

      def with_name(new_name)
        Table.new(
          new_name,
          fields:       fields,
          indices:      indices,
          checks:       checks,
          foreign_keys: foreign_keys
        )
      end

      def with_fields(new_fields)
        Table.new(
          name,
          fields:       new_fields,
          indices:      indices,
          checks:       checks,
          foreign_keys: foreign_keys
        )
      end

      def with_indices(new_indices)
        Table.new(
          name,
          fields:       fields,
          indices:      new_indices,
          checks:       checks,
          foreign_keys: foreign_keys
        )
      end

      def with_foreign_keys(new_foreign_keys)
        Table.new(
          name,
          fields:       fields,
          indices:      indices,
          checks:       checks,
          foreign_keys: new_foreign_keys
        )
      end
    end

    class NullTable < Table
      def initialize; end
    end
  end
end
