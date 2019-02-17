begin
  require 'awesome_print'
rescue LoadError
end

if defined?(AwesomePrint)
  module AwesomePrint
    module DbSchema
      def self.included(base)
        base.send :alias_method, :cast_without_dbschema, :cast
        base.send :alias_method, :cast, :cast_with_dbschema
      end

      def cast_with_dbschema(object, type)
        case object
        when ::DbSchema::Operations::CreateTable
          :dbschema_create_table
        when ::DbSchema::Operations::DropTable
          :dbschema_drop_table
        when ::DbSchema::Operations::AlterTable
          :dbschema_alter_table
        when ::DbSchema::Operations::CreateColumn
          :dbschema_create_column
        when ::DbSchema::Operations::ColumnOperation
          :dbschema_column_operation
        when ::DbSchema::Operations::RenameOperation
          :dbschema_rename
        when ::DbSchema::Operations::AlterColumnType
          :dbschema_alter_column_type
        when ::DbSchema::Operations::AlterColumnDefault
          :dbschema_alter_column_default
        when ::DbSchema::Operations::CreateIndex
          :dbschema_create_index
        when ::DbSchema::Operations::DropIndex
          :dbschema_drop_index
        when ::DbSchema::Operations::CreateCheckConstraint
          :dbschema_create_check_constraint
        when ::DbSchema::Operations::CreateForeignKey
          :dbschema_create_foreign_key
        when ::DbSchema::Operations::DropForeignKey
          :dbschema_drop_foreign_key
        when ::DbSchema::Operations::CreateEnum
          :dbschema_create_enum
        when ::DbSchema::Operations::AlterEnumValues
          :dbschema_alter_enum_values
        when ::DbSchema::Operations::CreateExtension
          :dbschema_create_extension
        else
          cast_without_dbschema(object, type)
        end
      end

    private
      def awesome_dbschema_create_table(object)
        data = ["fields: #{object.table.fields.ai}"]
        data << "indexes: #{object.table.indexes.ai}" if object.table.indexes.any?
        data << "checks: #{object.table.checks.ai}" if object.table.checks.any?

        data_string = indent_lines(data.join(', '))
        "#<DbSchema::Operations::CreateTable #{object.table.name.ai} #{data_string}>"
      end

      def awesome_dbschema_drop_table(object)
        "#<DbSchema::Operations::DropTable #{object.name.ai}>"
      end

      def awesome_dbschema_alter_table(object)
        "#<DbSchema::Operations::AlterTable #{object.table_name.ai} #{indent_lines(object.changes.ai)}>"
      end

      def awesome_dbschema_create_column(object)
        "#<DbSchema::Operations::CreateColumn #{object.field.ai}>"
      end

      def awesome_dbschema_drop_column(object)
        "#<DbSchema::Operations::DropColumn #{object.name.ai}>"
      end

      def awesome_dbschema_rename(object)
        "#<#{object.class} #{object.old_name.ai} => #{object.new_name.ai}>"
      end

      def awesome_dbschema_alter_column_type(object)
        attributes = object.new_attributes.map do |k, v|
          key = colorize("#{k}:", :symbol)
          "#{key} #{v.ai}"
        end.unshift(nil).join(', ')

        "#<DbSchema::Operations::AlterColumnType #{object.name.ai}, #{object.new_type.ai}#{attributes}>"
      end

      def awesome_dbschema_alter_column_default(object)
        new_default = if object.new_default.is_a?(Symbol)
          colorize(object.new_default.to_s, :string)
        else
          object.new_default.ai
        end

        "#<DbSchema::Operations::AlterColumnDefault #{object.name.ai}, #{new_default}>"
      end

      def awesome_dbschema_create_index(object)
        columns = format_dbschema_fields(object.index.columns)
        using = ' using ' + colorize(object.index.type.to_s, :symbol) unless object.index.btree?

        data = [nil]
        data << colorize('primary key', :nilclass) if object.index.primary?
        data << colorize('unique', :nilclass) if object.index.unique?
        data << colorize('condition: ', :symbol) + object.index.condition.ai unless object.index.condition.nil?

        "#<#{object.class} #{object.index.name.ai} on #{columns}#{using}#{data.join(', ')}>"
      end

      def awesome_dbschema_drop_index(object)
        data = [object.name.ai]
        data << colorize('primary key', :nilclass) if object.primary?

        "#<#{object.class} #{data.join(' ')}>"
      end

      def awesome_dbschema_create_check_constraint(object)
        "#<#{object.class} #{object.check.name.ai} #{object.check.condition.ai}>"
      end

      def awesome_dbschema_create_foreign_key(object)
        "#<DbSchema::Operations::CreateForeignKey #{object.foreign_key.ai} on #{object.table_name.ai}>"
      end

      def awesome_dbschema_drop_foreign_key(object)
        "#<DbSchema::Operations::DropForeignKey #{object.fkey_name.ai} on #{object.table_name.ai}>"
      end

      def awesome_dbschema_create_enum(object)
        values = object.enum.values.map do |value|
          colorize(value.to_s, :string)
        end.join(', ')

        "#<#{object.class} #{object.enum.name.ai} (#{values})>"
      end

      def awesome_dbschema_column_operation(object)
        "#<#{object.class} #{object.name.ai}>"
      end

      def awesome_dbschema_alter_enum_values(object)
        values = object.new_values.map do |value|
          colorize(value.to_s, :string)
        end.join(', ')

        "#<DbSchema::Operations::AlterEnumValues #{object.enum_name.ai} to (#{values})>"
      end

      def awesome_dbschema_create_extension(object)
        "#<#{object.class} #{object.extension.name.ai}>"
      end

      def format_dbschema_fields(fields)
        if fields.one?
          fields.first.ai
        else
          '[' + fields.map(&:ai).join(', ') + ']'
        end
      end

      def indent_lines(text, indent_level = 4)
        text.gsub(/(?<!\A)^/, ' ' * indent_level)
      end
    end
  end

  AwesomePrint::Formatter.send(:include, AwesomePrint::DbSchema)
end
