require 'db_schema/definitions'

module DbSchema
  module Changes
    class CreateTable < Definitions::Table
    end

    class DropTable
      attr_reader :name

      def initialize(name:)
        @name = name
      end
    end

    class AlterTable
      attr_reader :name, :fields, :indices

      def initialize(name:, fields:, indices:)
        @name    = name
        @fields  = fields
        @indices = indices
      end
    end

    # Abstract base class for single-column toggle operations.
    class ColumnOperation
      attr_reader :name

      def initialize(name:)
        @name = name
      end
    end

    class CreateColumn < Definitions::Field
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
      attr_reader :name, :new_type

      def initialize(name:, new_type:)
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
      attr_reader :name, :new_default

      def initialize(name:, new_default:)
        @name        = name
        @new_default = new_default
      end
    end

    class CreateIndex < Definitions::Index
    end

    class DropIndex
      attr_reader :name

      def initialize(name:)
        @name = name
      end
    end
  end
end
