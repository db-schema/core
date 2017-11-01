require 'db_schema/definitions'
require 'dry/equalizer'

module DbSchema
  module Changes
    class << self
      def between(desired_schema, actual_schema)
        table_names = [desired_schema.tables, actual_schema.tables].flatten.map(&:name).uniq

        table_changes = table_names.each.with_object([]) do |table_name, changes|
          desired = desired_schema.table(table_name)
          actual  = actual_schema.table(table_name)

          if desired_schema.has_table?(table_name) && !actual_schema.has_table?(table_name)
            changes << Operations::CreateTable.new(desired)

            fkey_operations = desired.foreign_keys.map do |fkey|
              Operations::CreateForeignKey.new(table_name, fkey)
            end
            changes.concat(fkey_operations)
          elsif actual_schema.has_table?(table_name) && !desired_schema.has_table?(table_name)
            changes << Operations::DropTable.new(table_name)

            actual.foreign_keys.each do |fkey|
              changes << Operations::DropForeignKey.new(table_name, fkey.name)
            end
          elsif actual != desired
            alter_table_operations = [
              field_changes(desired, actual),
              index_changes(desired, actual),
              check_changes(desired, actual)
            ].reduce(:+)

            fkey_operations = foreign_key_changes(desired, actual)

            if alter_table_operations.any?
              changes << Operations::AlterTable.new(
                table_name,
                sort_alter_table_changes(alter_table_operations)
              )
            end

            changes.concat(fkey_operations)
          end
        end

        enum_names = [desired_schema.enums, actual_schema.enums].flatten.map(&:name).uniq

        enum_changes = enum_names.each_with_object([]) do |enum_name, changes|
          desired = desired_schema.enum(enum_name)
          actual  = actual_schema.enum(enum_name)

          if desired_schema.has_enum?(enum_name) && !actual_schema.has_enum?(enum_name)
            changes << Operations::CreateEnum.new(desired)
          elsif actual_schema.has_enum?(enum_name) && !desired_schema.has_enum?(enum_name)
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
      def field_changes(desired_table, actual_table)
        field_names = [desired_table.fields, actual_table.fields].flatten.map(&:name).uniq

        field_names.each.with_object([]) do |name, table_changes|
          desired = desired_table.field(name)
          actual  = actual_table.field(name)

          if desired_table.has_field?(name) && !actual_table.has_field?(name)
            table_changes << Operations::CreateColumn.new(desired)
          elsif actual_table.has_field?(name) && !desired_table.has_field?(name)
            table_changes << Operations::DropColumn.new(name)
          elsif actual != desired
            if (actual.type != desired.type) || (actual.attributes != desired.attributes)
              table_changes << Operations::AlterColumnType.new(
                name,
                new_type: desired.type,
                **desired.attributes
              )
            end

            if desired.primary_key? && !actual.primary_key?
              table_changes << Operations::CreatePrimaryKey.new(name)
            end

            if actual.primary_key? && !desired.primary_key?
              table_changes << Operations::DropPrimaryKey.new(name)
            end

            if desired.null? && !actual.null?
              table_changes << Operations::AllowNull.new(name)
            end

            if actual.null? && !desired.null?
              table_changes << Operations::DisallowNull.new(name)
            end

            if actual.default != desired.default
              table_changes << Operations::AlterColumnDefault.new(name, new_default: desired.default)
            end
          end
        end
      end

      def index_changes(desired_table, actual_table)
        index_names = [desired_table.indices, actual_table.indices].flatten.map(&:name).uniq

        index_names.each.with_object([]) do |name, table_changes|
          desired = desired_table.index(name)
          actual  = actual_table.index(name)

          if desired_table.has_index?(name) && !actual_table.has_index?(name)
            table_changes << Operations::CreateIndex.new(desired)
          elsif actual_table.has_index?(name) && !desired_table.has_index?(name)
            table_changes << Operations::DropIndex.new(name)
          elsif actual != desired
            table_changes << Operations::DropIndex.new(name)
            table_changes << Operations::CreateIndex.new(desired)
          end
        end
      end

      def check_changes(desired_table, actual_table)
        check_names = [desired_table.checks, actual_table.checks].flatten.map(&:name).uniq

        check_names.each.with_object([]) do |name, table_changes|
          desired = desired_table.check(name)
          actual  = actual_table.check(name)

          if desired_table.has_check?(name) && !actual_table.has_check?(name)
            table_changes << Operations::CreateCheckConstraint.new(desired)
          elsif actual_table.has_check?(name) && !desired_table.has_check?(name)
            table_changes << Operations::DropCheckConstraint.new(name)
          elsif actual != desired
            table_changes << Operations::DropCheckConstraint.new(name)
            table_changes << Operations::CreateCheckConstraint.new(desired)
          end
        end
      end

      def foreign_key_changes(desired_table, actual_table)
        key_names = [desired_table.foreign_keys, actual_table.foreign_keys].flatten.map(&:name).uniq

        key_names.each.with_object([]) do |name, table_changes|
          desired = desired_table.foreign_key(name)
          actual  = actual_table.foreign_key(name)

          if desired_table.has_foreign_key?(name) && !actual_table.has_foreign_key?(name)
            table_changes << Operations::CreateForeignKey.new(actual_table.name, desired)
          elsif actual_table.has_foreign_key?(name) && !desired_table.has_foreign_key?(name)
            table_changes << Operations::DropForeignKey.new(actual_table.name, name)
          elsif actual != desired
            table_changes << Operations::DropForeignKey.new(actual_table.name, name)
            table_changes << Operations::CreateForeignKey.new(actual_table.name, desired)
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
