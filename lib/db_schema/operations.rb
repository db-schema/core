module DbSchema
  module Operations
    # Abstract base class for rename operations.
    class RenameOperation
      include Dry::Equalizer(:old_name, :new_name)
      attr_reader :old_name, :new_name

      def initialize(old_name:, new_name:)
        @old_name = old_name
        @new_name = new_name
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

    class RenameTable < RenameOperation
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

      def options
        field.options
      end
    end

    class DropColumn < ColumnOperation
    end

    class RenameColumn < RenameOperation
    end

    class AlterColumnType
      SERIAL_TYPES = [:smallserial, :serial, :bigserial].freeze

      include Dry::Equalizer(:name, :old_type, :new_type, :using, :new_attributes)
      attr_reader :name, :old_type, :new_type, :using, :new_attributes

      def initialize(name, old_type:, new_type:, using: nil, **new_attributes)
        @name           = name
        @old_type       = old_type
        @new_type       = new_type
        @using          = using
        @new_attributes = new_attributes
      end

      def from_serial?
        SERIAL_TYPES.include?(old_type)
      end

      def to_serial?
        SERIAL_TYPES.include?(new_type)
      end
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

      def primary?
        index.primary?
      end

      def name
        index.name
      end

      def columns
        index.columns
      end
    end

    class DropIndex
      include Dry::Equalizer(:name, :primary?)
      attr_reader :name

      def initialize(name, primary)
        @name    = name
        @primary = primary
      end

      def primary?
        @primary
      end
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

    class RenameEnum < RenameOperation
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

    class ExecuteQuery
      include Dry::Equalizer(:query)
      attr_reader :query

      def initialize(query)
        @query = query
      end
    end
  end
end
