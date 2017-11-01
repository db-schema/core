require 'db_schema/definitions'
require 'dry/equalizer'

module DbSchema
  module Changes
    class << self
      def between(desired_schema, actual_schema)
        sort_all_changes(
          [
            table_changes(desired_schema, actual_schema),
            enum_changes(desired_schema, actual_schema),
            extension_changes(desired_schema, actual_schema)
          ].reduce(:+)
        )
      end

    private
      def table_changes(desired_schema, actual_schema)
        compare_collections(
          desired_schema.tables,
          actual_schema.tables,
          create: -> (table) do
            fkey_operations = table.foreign_keys.map do |fkey|
              Operations::CreateForeignKey.new(table.name, fkey)
            end

            [Operations::CreateTable.new(table), *fkey_operations]
          end,
          drop: -> (table) do
            fkey_operations = table.foreign_keys.map do |fkey|
              Operations::DropForeignKey.new(table.name, fkey.name)
            end

            [Operations::DropTable.new(table.name), *fkey_operations]
          end,
          change: -> (desired, actual) do
            fkey_operations = foreign_key_changes(desired, actual)

            alter_table_operations = [
              field_changes(desired, actual),
              index_changes(desired, actual),
              check_changes(desired, actual)
            ].reduce(:+)

            if alter_table_operations.any?
              alter_table = Operations::AlterTable.new(
                desired.name,
                sort_alter_table_changes(alter_table_operations)
              )

              [alter_table, *fkey_operations]
            else
              fkey_operations
            end
          end
        )
      end

      def field_changes(desired_table, actual_table)
        compare_collections(
          desired_table.fields,
          actual_table.fields,
          create: -> (field) { Operations::CreateColumn.new(field) },
          drop:   -> (field) { Operations::DropColumn.new(field.name) },
          change: -> (desired, actual) do
            [].tap do |operations|
              if (actual.type != desired.type) || (actual.attributes != desired.attributes)
                operations << Operations::AlterColumnType.new(
                  actual.name,
                  new_type: desired.type,
                  **desired.attributes
                )
              end

              if desired.primary_key? && !actual.primary_key?
                operations << Operations::CreatePrimaryKey.new(actual.name)
              end

              if actual.primary_key? && !desired.primary_key?
                operations << Operations::DropPrimaryKey.new(actual.name)
              end

              if desired.null? && !actual.null?
                operations << Operations::AllowNull.new(actual.name)
              end

              if actual.null? && !desired.null?
                operations << Operations::DisallowNull.new(actual.name)
              end

              if actual.default != desired.default
                operations << Operations::AlterColumnDefault.new(actual.name, new_default: desired.default)
              end
            end
          end
        )
      end

      def index_changes(desired_table, actual_table)
        compare_collections(
          desired_table.indices,
          actual_table.indices,
          create: -> (index) { Operations::CreateIndex.new(index) },
          drop:   -> (index) { Operations::DropIndex.new(index.name) },
          change: -> (desired, actual) do
            [
              Operations::DropIndex.new(actual.name),
              Operations::CreateIndex.new(desired)
            ]
          end
        )
      end

      def check_changes(desired_table, actual_table)
        compare_collections(
          desired_table.checks,
          actual_table.checks,
          create: -> (check) { Operations::CreateCheck.new(check) },
          drop:   -> (check) { Operations::DropIndex.new(check.name) },
          change: -> (desired, actual) do
            [
              Operations::DropCheckConstraint.new(actual.name),
              Operations::CreateCheckConstraint.new(desired)
            ]
          end
        )
      end

      def foreign_key_changes(desired_table, actual_table)
        compare_collections(
          desired_table.foreign_keys,
          actual_table.foreign_keys,
          create: -> (foreign_key) { Operations::CreateForeignKey.new(actual_table.name, foreign_key) },
          drop:   -> (foreign_key) { Operations::DropForeignKey.new(actual_table.name, foreign_key.name) },
          change: -> (desired, actual) do
            [
              Operations::DropForeignKey.new(actual_table.name, actual.name),
              Operations::CreateForeignKey.new(actual_table.name, desired)
            ]
          end
        )
      end

      def enum_changes(desired_schema, actual_schema)
        compare_collections(
          desired_schema.enums,
          actual_schema.enums,
          create: -> (enum) { Operations::CreateEnum.new(enum) },
          drop:   -> (enum) { Operations::DropEnum.new(enum.name) },
          change: -> (desired, actual) do
            fields = actual_schema.tables.flat_map do |table|
              table.fields.select do |field|
                if field.array?
                  field.attributes[:element_type] == actual.name
                else
                  field.type == actual.name
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

            Operations::AlterEnumValues.new(actual.name, desired.values, fields)
          end
        )
      end

      def extension_changes(desired_schema, actual_schema)
        compare_collections(
          desired_schema.extensions,
          actual_schema.extensions,
          create: -> (extension) { Operations::CreateExtension.new(extension) },
          drop:   -> (extension) { Operations::DropExtension.new(extension.name) }
        )
      end

      def compare_collections(desired, actual, create:, drop:, change: -> (*) {})
        desired_hash = Utils.to_hash(desired, :name)
        actual_hash  = Utils.to_hash(actual, :name)

        (desired_hash.keys + actual_hash.keys).uniq.flat_map do |name|
          if desired_hash.key?(name) && !actual_hash.key?(name)
            create.(desired_hash[name])
          elsif actual_hash.key?(name) && !desired_hash.key?(name)
            drop.(actual_hash[name])
          elsif actual_hash[name] != desired_hash[name]
            change.(desired_hash[name], actual_hash[name])
          end
        end.compact
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
