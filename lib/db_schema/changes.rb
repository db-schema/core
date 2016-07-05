require 'db_schema/definitions'
require 'dry/equalizer'

module DbSchema
  module Changes
    class << self
      def between(desired_schema, actual_schema)
        desired_tables = extract_tables(desired_schema)
        actual_tables  = extract_tables(actual_schema)

        table_names = [desired_tables, actual_tables].flatten.map(&:name).uniq

        table_changes = table_names.each.with_object([]) do |table_name, changes|
          desired = desired_tables.find { |table| table.name == table_name }
          actual  = actual_tables.find  { |table| table.name == table_name }

          if desired && !actual
            changes << CreateTable.new(
              table_name,
              fields:  desired.fields,
              indices: desired.indices,
              checks:  desired.checks
            )

            fkey_operations = desired.foreign_keys.map do |fkey|
              CreateForeignKey.new(table_name, fkey)
            end
            changes.concat(fkey_operations)
          elsif actual && !desired
            changes << DropTable.new(table_name)

            actual.foreign_keys.each do |fkey|
              changes << DropForeignKey.new(table_name, fkey.name)
            end
          elsif actual != desired
            field_operations = field_changes(desired.fields, actual.fields)
            index_operations = index_changes(desired.indices, actual.indices)
            check_operations = check_changes(desired.checks, actual.checks)
            fkey_operations  = foreign_key_changes(table_name, desired.foreign_keys, actual.foreign_keys)

            if field_operations.any? || index_operations.any? || check_operations.any?
              changes << AlterTable.new(
                table_name,
                fields:  field_operations,
                indices: index_operations,
                checks:  check_operations
              )
            end

            changes.concat(fkey_operations)
          end
        end

        desired_enums = extract_enums(desired_schema)
        actual_enums  = extract_enums(actual_schema)

        enum_names = [desired_enums, actual_enums].flatten.map(&:name).uniq

        enum_changes = enum_names.each_with_object([]) do |enum_name, changes|
          desired = desired_enums.find { |enum| enum.name == enum_name }
          actual  = actual_enums.find  { |enum| enum.name == enum_name }

          if desired && !actual
            changes << CreateEnum.new(enum_name, desired.values)
          elsif actual && !desired
            changes << DropEnum.new(enum_name)
          elsif actual != desired
            new_values     = desired.values - actual.values
            dropped_values = actual.values - desired.values

            if dropped_values.any?
              raise UnsupportedOperation, "Enum #{enum_name.inspect} contains values #{dropped_values.inspect} that are not present in the database; dropping values from enums is not supported."
            end

            if desired.values - new_values != actual.values
              raise UnsupportedOperation, "Enum #{enum_name.inspect} contains values #{(desired.values - new_values).inspect} that are present in the database in a different order (#{actual.values.inspect}); reordering values in enums is not supported."
            end

            new_values.reverse.each do |value|
              value_index = desired.values.index(value)

              if value_index == desired.values.count - 1
                changes << AddValueToEnum.new(enum_name, value)
              else
                next_value = desired.values[value_index + 1]
                changes << AddValueToEnum.new(enum_name, value, before: next_value)
              end
            end
          end
        end

        table_changes + enum_changes
      end

    private
      def field_changes(desired_fields, actual_fields)
        field_names = [desired_fields, actual_fields].flatten.map(&:name).uniq

        field_names.each.with_object([]) do |field_name, table_changes|
          desired = desired_fields.find { |field| field.name == field_name }
          actual  = actual_fields.find  { |field| field.name == field_name }

          if desired && !actual
            table_changes << CreateColumn.new(desired)
          elsif actual && !desired
            table_changes << DropColumn.new(field_name)
          elsif actual != desired
            if (actual.class.type != desired.class.type) || (actual.attributes != desired.attributes)
              if desired.custom_type?
                table_changes << AlterColumnType.new(field_name, new_type: desired.type_name)
              else
                table_changes << AlterColumnType.new(
                  field_name,
                  new_type: desired.class.type,
                  **desired.attributes
                )
              end
            end

            if desired.primary_key? && !actual.primary_key?
              table_changes << CreatePrimaryKey.new(field_name)
            end

            if actual.primary_key? && !desired.primary_key?
              table_changes << DropPrimaryKey.new(field_name)
            end

            if desired.null? && !actual.null?
              table_changes << AllowNull.new(field_name)
            end

            if actual.null? && !desired.null?
              table_changes << DisallowNull.new(field_name)
            end

            if actual.default != desired.default
              table_changes << AlterColumnDefault.new(field_name, new_default: desired.default)
            end
          end
        end
      end

      def index_changes(desired_indices, actual_indices)
        index_names = [desired_indices, actual_indices].flatten.map(&:name).uniq

        index_names.each.with_object([]) do |index_name, table_changes|
          desired = desired_indices.find { |index| index.name == index_name }
          actual  = actual_indices.find  { |index| index.name == index_name }

          if desired && !actual
            table_changes << CreateIndex.new(
              name:      index_name,
              fields:    desired.fields,
              unique:    desired.unique?,
              type:      desired.type,
              condition: desired.condition
            )
          elsif actual && !desired
            table_changes << DropIndex.new(index_name)
          elsif actual != desired
            table_changes << DropIndex.new(index_name)
            table_changes << CreateIndex.new(
              name:      index_name,
              fields:    desired.fields,
              unique:    desired.unique?,
              type:      desired.type,
              condition: desired.condition
            )
          end
        end
      end

      def check_changes(desired_checks, actual_checks)
        check_names = [desired_checks, actual_checks].flatten.map(&:name).uniq

        check_names.each.with_object([]) do |check_name, table_changes|
          desired = desired_checks.find { |check| check.name == check_name }
          actual  = actual_checks.find  { |check| check.name == check_name }

          if desired && !actual
            table_changes << CreateCheckConstraint.new(
              name:      check_name,
              condition: desired.condition
            )
          elsif actual && !desired
            table_changes << DropCheckConstraint.new(check_name)
          elsif actual != desired
            table_changes << DropCheckConstraint.new(check_name)
            table_changes << CreateCheckConstraint.new(
              name:      check_name,
              condition: desired.condition
            )
          end
        end
      end

      def foreign_key_changes(table_name, desired_foreign_keys, actual_foreign_keys)
        key_names = [desired_foreign_keys, actual_foreign_keys].flatten.map(&:name).uniq

        key_names.each.with_object([]) do |key_name, table_changes|
          desired = desired_foreign_keys.find { |key| key.name == key_name }
          actual  = actual_foreign_keys.find  { |key| key.name == key_name }

          foreign_key = Definitions::ForeignKey.new(
            name:       key_name,
            fields:     desired.fields,
            table:      desired.table,
            keys:       desired.keys,
            on_delete:  desired.on_delete,
            on_update:  desired.on_update,
            deferrable: desired.deferrable?
          ) if desired

          if desired && !actual
            table_changes << CreateForeignKey.new(table_name, foreign_key)
          elsif actual && !desired
            table_changes << DropForeignKey.new(table_name, key_name)
          elsif actual != desired
            table_changes << DropForeignKey.new(table_name, key_name)
            table_changes << CreateForeignKey.new(table_name, foreign_key)
          end
        end
      end

      def extract_tables(schema)
        Utils.filter_by_class(schema, Definitions::Table)
      end

      def extract_enums(schema)
        Utils.filter_by_class(schema, Definitions::Enum)
      end
    end

    class CreateTable
      include Dry::Equalizer(:name, :fields, :indices, :checks)
      attr_reader :name, :fields, :indices, :checks

      def initialize(name, fields: [], indices: [], checks: [])
        @name    = name
        @fields  = fields
        @indices = indices
        @checks  = checks
      end
    end

    class DropTable
      include Dry::Equalizer(:name)
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end

    class AlterTable
      include Dry::Equalizer(:name, :fields, :indices, :checks)
      attr_reader :name, :fields, :indices, :checks

      def initialize(name, fields: [], indices: [], checks: [])
        @name    = name
        @fields  = fields
        @indices = indices
        @checks  = checks
      end
    end

    # Abstract base class for single-column toggle operations.
    class ColumnOperation
      include Dry::Equalizer(:name)
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end

    class CreateColumn
      include Dry::Equalizer(:field)
      attr_reader :field

      def initialize(field)
        @field = field
      end

      def name
        field.name
      end

      def type
        field.class.type
      end

      def primary_key?
        field.primary_key?
      end

      def options
        field.options
      end
    end

    class DropColumn < ColumnOperation
    end

    class RenameColumn
      attr_reader :old_name, :new_name

      def initialize(old_name:, new_name:)
        @old_name = old_name
        @new_name = new_name
      end
    end

    class AlterColumnType
      include Dry::Equalizer(:name, :new_type, :new_attributes)
      attr_reader :name, :new_type, :new_attributes

      def initialize(name, new_type:, **new_attributes)
        @name           = name
        @new_type       = new_type
        @new_attributes = new_attributes
      end
    end

    class CreatePrimaryKey < ColumnOperation
    end

    class DropPrimaryKey < ColumnOperation
    end

    class AllowNull < ColumnOperation
    end

    class DisallowNull < ColumnOperation
    end

    class AlterColumnDefault
      include Dry::Equalizer(:name, :new_default)
      attr_reader :name, :new_default

      def initialize(name, new_default:)
        @name        = name
        @new_default = new_default
      end
    end

    class CreateIndex < Definitions::Index
    end

    class DropIndex < ColumnOperation
    end

    class CreateCheckConstraint < Definitions::CheckConstraint
    end

    class DropCheckConstraint < ColumnOperation
    end

    class CreateForeignKey
      include Dry::Equalizer(:table_name, :foreign_key)
      attr_reader :table_name, :foreign_key

      def initialize(table_name, foreign_key)
        @table_name  = table_name
        @foreign_key = foreign_key
      end
    end

    class DropForeignKey
      include Dry::Equalizer(:table_name, :fkey_name)
      attr_reader :table_name, :fkey_name

      def initialize(table_name, fkey_name)
        @table_name = table_name
        @fkey_name  = fkey_name
      end
    end

    class CreateEnum < Definitions::Enum
    end

    class DropEnum < ColumnOperation
    end

    class AddValueToEnum
      include Dry::Equalizer(:enum_name, :new_value, :before)
      attr_reader :enum_name, :new_value, :before

      def initialize(enum_name, new_value, before: nil)
        @enum_name = enum_name
        @new_value = new_value
        @before    = before
      end

      def add_to_the_end?
        before.nil?
      end
    end
  end
end
