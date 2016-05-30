require 'db_schema/definitions'
require 'dry/equalizer'

module DbSchema
  module Changes
    class << self
      def between(desired_schema, actual_schema)
        table_names = [desired_schema, actual_schema].flatten.map(&:name).uniq

        table_names.each.with_object([]) do |table_name, changes|
          desired = desired_schema.find { |table| table.name == table_name }
          actual  = actual_schema.find { |table| table.name == table_name }

          if desired && !actual
            changes << CreateTable.new(
              table_name,
              fields:       desired.fields,
              indices:      desired.indices,
              foreign_keys: desired.foreign_keys
            )
          elsif actual && !desired
            changes << DropTable.new(table_name)
          elsif actual != desired
            field_operations       = field_changes(desired.fields, actual.fields)
            index_operations       = index_changes(desired.indices, actual.indices)
            foreign_key_operations = foreign_key_changes(desired.foreign_keys, actual.foreign_keys)

            changes << AlterTable.new(
              table_name,
              fields:       field_operations,
              indices:      index_operations,
              foreign_keys: foreign_key_operations
            )
          end
        end
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
            if actual.class.type != desired.class.type
              table_changes << AlterColumnType.new(field_name, new_type: desired.class.type)
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
              condition: desired.condition
            )
          elsif actual && !desired
            table_changes << DropIndex.new(name: index_name)
          elsif actual != desired
            table_changes << DropIndex.new(name: index_name)
            table_changes << CreateIndex.new(
              name:      index_name,
              fields:    desired.fields,
              unique:    desired.unique?,
              condition: desired.condition
            )
          end
        end
      end

      def foreign_key_changes(desired_foreign_keys, actual_foreign_keys)
        key_names = [desired_foreign_keys, actual_foreign_keys].flatten.map(&:name).uniq

        key_names.each.with_object([]) do |key_name, table_changes|
          desired = desired_foreign_keys.find { |key| key.name == key_name }
          actual  = actual_foreign_keys.find  { |key| key.name == key_name }

          if desired && !actual
            table_changes << CreateForeignKey.new(
              name:       key_name,
              fields:     desired.fields,
              table:      desired.table,
              keys:       desired.keys,
              on_delete:  desired.on_delete,
              on_update:  desired.on_update,
              deferrable: desired.deferrable?
            )
          elsif actual && !desired
            table_changes << DropForeignKey.new(name: key_name)
          elsif actual != desired
            table_changes << DropForeignKey.new(name: key_name)
            table_changes << CreateForeignKey.new(
              name:       key_name,
              fields:     desired.fields,
              table:      desired.table,
              keys:       desired.keys,
              on_delete:  desired.on_delete,
              on_update:  desired.on_update,
              deferrable: desired.deferrable?
            )
          end
        end
      end
    end

    class CreateTable < Definitions::Table
    end

    class DropTable
      include Dry::Equalizer(:name)
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end

    class AlterTable
      attr_reader :name, :fields, :indices, :foreign_keys

      def initialize(name, fields:, indices:, foreign_keys:)
        @name         = name
        @fields       = fields
        @indices      = indices
        @foreign_keys = foreign_keys
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
      include Dry::Equalizer(:name, :new_type)
      attr_reader :name, :new_type

      def initialize(name, new_type:)
        @name     = name
        @new_type = new_type
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

    class CreateForeignKey < Definitions::ForeignKey
    end

    class DropForeignKey < ColumnOperation
    end
  end
end
