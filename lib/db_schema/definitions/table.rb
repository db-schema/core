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

      def field(field_name)
        fields.find { |field| field.name == field_name } || NullField.new
      end
      alias_method :[], :field

      def has_field?(field_name)
        !field(field_name).is_a?(NullField)
      end

      def index(index_name)
        indices.find { |index| index.name == index_name } || NullIndex.new
      end

      def has_index?(index_name)
        !index(index_name).is_a?(NullIndex)
      end

      def has_index_on?(*field_names)
        indices.any? do |index|
          index.columns.none?(&:expression?) && index.columns.map(&:name) == field_names
        end
      end

      def has_unique_index_on?(*field_names)
        indices.any? do |index|
          index.unique? && index.columns.none?(&:expression?) && index.columns.map(&:name) == field_names
        end
      end

      def check(check_name)
        checks.find { |check| check.name == check_name } || NullCheckConstraint.new
      end

      def has_check?(check_name)
        !check(check_name).is_a?(NullCheckConstraint)
      end

      def foreign_key(fkey_name)
        foreign_keys.find { |fkey| fkey.name == fkey_name } || NullForeignKey.new
      end

      def has_foreign_key?(fkey_name)
        !foreign_key(fkey_name).is_a?(NullForeignKey)
      end

      def has_foreign_key_to?(other_table_name)
        foreign_keys.any? { |fkey| fkey.table == other_table_name }
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
