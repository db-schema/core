require 'db_schema/definitions'
require 'dry/equalizer'

module DbSchema
  module Changes
    class << self
      def between(desired_schema, actual_schema)
        table_names = [desired_schema.tables, actual_schema.tables].flatten.map(&:name).uniq

        table_changes = table_names.each.with_object([]) do |table_name, changes|
          desired = desired_schema.tables.find { |table| table.name == table_name }
          actual  = actual_schema.tables.find  { |table| table.name == table_name }

          if desired && !actual
            changes << CreateTable.new(desired)

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
                sort_alter_table_changes(field_operations + index_operations + check_operations)
              )
            end

            changes.concat(fkey_operations)
          end
        end

        enum_names = [desired_schema.enums, actual_schema.enums].flatten.map(&:name).uniq

        enum_changes = enum_names.each_with_object([]) do |enum_name, changes|
          desired = desired_schema.enums.find { |enum| enum.name == enum_name }
          actual  = actual_schema.enums.find  { |enum| enum.name == enum_name }

          if desired && !actual
            changes << CreateEnum.new(desired)
          elsif actual && !desired
            changes << DropEnum.new(enum_name)
          elsif actual != desired
            fields = actual_schema.tables.flat_map do |table|
              table.fields.select do |field|
                if field.array?
                  field.attributes[:element_type] == enum_name
                else
                  field.type == enum_name
                end
              end.map do |field|
                if desired_field = desired_schema[table.name][field.name]
                  new_default = desired_field.default
                end

                {
                  table_name:  table.name,
                  field_name:  field.name,
                  new_default: new_default,
                  array:       field.array?
                }
              end
            end

            changes << AlterEnumValues.new(enum_name, desired.values, fields)
          end
        end

        extension_changes = (desired_schema.extensions - actual_schema.extensions).map do |extension|
          CreateExtension.new(extension)
        end + (actual_schema.extensions - desired_schema.extensions).map do |extension|
          DropExtension.new(extension.name)
        end

        sort_all_changes(table_changes + enum_changes + extension_changes)
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
            if (actual.type != desired.type) || (actual.attributes != desired.attributes)
              table_changes << AlterColumnType.new(
                field_name,
                new_type: desired.type,
                **desired.attributes
              )
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
            table_changes << CreateIndex.new(desired)
          elsif actual && !desired
            table_changes << DropIndex.new(index_name)
          elsif actual != desired
            table_changes << DropIndex.new(index_name)
            table_changes << CreateIndex.new(desired)
          end
        end
      end

      def check_changes(desired_checks, actual_checks)
        check_names = [desired_checks, actual_checks].flatten.map(&:name).uniq

        check_names.each.with_object([]) do |check_name, table_changes|
          desired = desired_checks.find { |check| check.name == check_name }
          actual  = actual_checks.find  { |check| check.name == check_name }

          if desired && !actual
            table_changes << CreateCheckConstraint.new(desired)
          elsif actual && !desired
            table_changes << DropCheckConstraint.new(check_name)
          elsif actual != desired
            table_changes << DropCheckConstraint.new(check_name)
            table_changes << CreateCheckConstraint.new(desired)
          end
        end
      end

      def foreign_key_changes(table_name, desired_foreign_keys, actual_foreign_keys)
        key_names = [desired_foreign_keys, actual_foreign_keys].flatten.map(&:name).uniq

        key_names.each.with_object([]) do |key_name, table_changes|
          desired = desired_foreign_keys.find { |key| key.name == key_name }
          actual  = actual_foreign_keys.find  { |key| key.name == key_name }

          if desired && !actual
            table_changes << CreateForeignKey.new(table_name, desired)
          elsif actual && !desired
            table_changes << DropForeignKey.new(table_name, key_name)
          elsif actual != desired
            table_changes << DropForeignKey.new(table_name, key_name)
            table_changes << CreateForeignKey.new(table_name, desired)
          end
        end
      end

      def sort_all_changes(changes)
        Utils.sort_by_class(
          changes,
          [
            CreateExtension,
            DropForeignKey,
            AlterEnumValues,
            CreateEnum,
            CreateTable,
            AlterTable,
            DropTable,
            DropEnum,
            CreateForeignKey,
            DropExtension
          ]
        )
      end

      def sort_alter_table_changes(changes)
        Utils.sort_by_class(
          changes,
          [
            DropPrimaryKey,
            DropCheckConstraint,
            DropIndex,
            DropColumn,
            AlterColumnType,
            AllowNull,
            DisallowNull,
            AlterColumnDefault,
            CreateColumn,
            CreateIndex,
            CreateCheckConstraint,
            CreatePrimaryKey
          ]
        )
      end
    end

    class CreateTable
      include Dry::Equalizer(:table)
      attr_reader :table

      def initialize(table)
        @table = table
      end
    end

    class DropTable
      include Dry::Equalizer(:name)
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end

    class RenameTable
      include Dry::Equalizer(:old_name, :new_name)
      attr_reader :old_name, :new_name

      def initialize(old_name:, new_name:)
        @old_name = old_name
        @new_name = new_name
      end
    end

    class AlterTable
      include Dry::Equalizer(:table_name, :changes)
      attr_reader :table_name, :changes

      def initialize(table_name, changes = [])
        @table_name = table_name
        @changes    = changes
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
        field.type
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
      include Dry::Equalizer(:old_name, :new_name)
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

    class CreateIndex
      include Dry::Equalizer(:index)
      attr_reader :index

      def initialize(index)
        @index = index
      end
    end

    class DropIndex < ColumnOperation
    end

    class CreateCheckConstraint
      include Dry::Equalizer(:check)
      attr_reader :check

      def initialize(check)
        @check = check
      end
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

    class CreateEnum
      include Dry::Equalizer(:enum)
      attr_reader :enum

      def initialize(enum)
        @enum = enum
      end
    end

    class DropEnum < ColumnOperation
    end

    class AlterEnumValues
      include Dry::Equalizer(:enum_name, :new_values, :enum_fields)
      attr_reader :enum_name, :new_values, :enum_fields

      def initialize(enum_name, new_values, enum_fields)
        @enum_name   = enum_name
        @new_values  = new_values
        @enum_fields = enum_fields
      end
    end

    class CreateExtension
      include Dry::Equalizer(:extension)
      attr_reader :extension

      def initialize(extension)
        @extension = extension
      end
    end

    class DropExtension < ColumnOperation
    end
  end
end
