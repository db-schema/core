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
            changes << Operations::CreateTable.new(desired)

            fkey_operations = desired.foreign_keys.map do |fkey|
              Operations::CreateForeignKey.new(table_name, fkey)
            end
            changes.concat(fkey_operations)
          elsif actual && !desired
            changes << Operations::DropTable.new(table_name)

            actual.foreign_keys.each do |fkey|
              changes << Operations::DropForeignKey.new(table_name, fkey.name)
            end
          elsif actual != desired
            field_operations = field_changes(desired.fields, actual.fields)
            index_operations = index_changes(desired.indices, actual.indices)
            check_operations = check_changes(desired.checks, actual.checks)
            fkey_operations  = foreign_key_changes(table_name, desired.foreign_keys, actual.foreign_keys)

            if field_operations.any? || index_operations.any? || check_operations.any?
              changes << Operations::AlterTable.new(
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
            changes << Operations::CreateEnum.new(desired)
          elsif actual && !desired
            changes << Operations::DropEnum.new(enum_name)
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

            changes << Operations::AlterEnumValues.new(enum_name, desired.values, fields)
          end
        end

        extension_changes = (desired_schema.extensions - actual_schema.extensions).map do |extension|
          Operations::CreateExtension.new(extension)
        end + (actual_schema.extensions - desired_schema.extensions).map do |extension|
          Operations::DropExtension.new(extension.name)
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
            table_changes << Operations::CreateColumn.new(desired)
          elsif actual && !desired
            table_changes << Operations::DropColumn.new(field_name)
          elsif actual != desired
            if (actual.type != desired.type) || (actual.attributes != desired.attributes)
              table_changes << Operations::AlterColumnType.new(
                field_name,
                new_type: desired.type,
                **desired.attributes
              )
            end

            if desired.primary_key? && !actual.primary_key?
              table_changes << Operations::CreatePrimaryKey.new(field_name)
            end

            if actual.primary_key? && !desired.primary_key?
              table_changes << Operations::DropPrimaryKey.new(field_name)
            end

            if desired.null? && !actual.null?
              table_changes << Operations::AllowNull.new(field_name)
            end

            if actual.null? && !desired.null?
              table_changes << Operations::DisallowNull.new(field_name)
            end

            if actual.default != desired.default
              table_changes << Operations::AlterColumnDefault.new(field_name, new_default: desired.default)
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
            table_changes << Operations::CreateIndex.new(desired)
          elsif actual && !desired
            table_changes << Operations::DropIndex.new(index_name)
          elsif actual != desired
            table_changes << Operations::DropIndex.new(index_name)
            table_changes << Operations::CreateIndex.new(desired)
          end
        end
      end

      def check_changes(desired_checks, actual_checks)
        check_names = [desired_checks, actual_checks].flatten.map(&:name).uniq

        check_names.each.with_object([]) do |check_name, table_changes|
          desired = desired_checks.find { |check| check.name == check_name }
          actual  = actual_checks.find  { |check| check.name == check_name }

          if desired && !actual
            table_changes << Operations::CreateCheckConstraint.new(desired)
          elsif actual && !desired
            table_changes << Operations::DropCheckConstraint.new(check_name)
          elsif actual != desired
            table_changes << Operations::DropCheckConstraint.new(check_name)
            table_changes << Operations::CreateCheckConstraint.new(desired)
          end
        end
      end

      def foreign_key_changes(table_name, desired_foreign_keys, actual_foreign_keys)
        key_names = [desired_foreign_keys, actual_foreign_keys].flatten.map(&:name).uniq

        key_names.each.with_object([]) do |key_name, table_changes|
          desired = desired_foreign_keys.find { |key| key.name == key_name }
          actual  = actual_foreign_keys.find  { |key| key.name == key_name }

          if desired && !actual
            table_changes << Operations::CreateForeignKey.new(table_name, desired)
          elsif actual && !desired
            table_changes << Operations::DropForeignKey.new(table_name, key_name)
          elsif actual != desired
            table_changes << Operations::DropForeignKey.new(table_name, key_name)
            table_changes << Operations::CreateForeignKey.new(table_name, desired)
          end
        end
      end

      def sort_all_changes(changes)
        Utils.sort_by_class(
          changes,
          [
            Operations::CreateExtension,
            Operations::DropForeignKey,
            Operations::AlterEnumValues,
            Operations::CreateEnum,
            Operations::CreateTable,
            Operations::AlterTable,
            Operations::DropTable,
            Operations::DropEnum,
            Operations::CreateForeignKey,
            Operations::DropExtension
          ]
        )
      end

      def sort_alter_table_changes(changes)
        Utils.sort_by_class(
          changes,
          [
            Operations::DropPrimaryKey,
            Operations::DropCheckConstraint,
            Operations::DropIndex,
            Operations::DropColumn,
            Operations::AlterColumnType,
            Operations::AllowNull,
            Operations::DisallowNull,
            Operations::AlterColumnDefault,
            Operations::CreateColumn,
            Operations::CreateIndex,
            Operations::CreateCheckConstraint,
            Operations::CreatePrimaryKey
          ]
        )
      end
    end
  end
end
