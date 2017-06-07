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
        when ::DbSchema::Definitions::Schema
          :dbschema_schema
        when ::DbSchema::Definitions::NullTable
          :dbschema_null_table
        when ::DbSchema::Definitions::Table
          :dbschema_table
        when ::DbSchema::Definitions::Field::Custom
          :dbschema_custom_field
        when ::DbSchema::Definitions::Field::Base
          :dbschema_field
        when ::DbSchema::Definitions::Index
          :dbschema_index
        when ::DbSchema::Definitions::Index::Column
          :dbschema_index_column
        when ::DbSchema::Definitions::CheckConstraint
          :dbschema_check_constraint
        when ::DbSchema::Definitions::ForeignKey
          :dbschema_foreign_key
        when ::DbSchema::Definitions::Enum
          :dbschema_enum
        when ::DbSchema::Definitions::Extension
          :dbschema_column_operation
        when ::DbSchema::Operations::CreateTable
          :dbschema_create_table
        when ::DbSchema::Operations::DropTable
          :dbschema_drop_table
        when ::DbSchema::Operations::AlterTable
          :dbschema_alter_table
        when ::DbSchema::Operations::CreateColumn
          :dbschema_create_column
        when ::DbSchema::Operations::DropColumn
          :dbschema_column_operation
        when ::DbSchema::Operations::RenameTable,
             ::DbSchema::Operations::RenameColumn
          :dbschema_rename
        when ::DbSchema::Operations::AlterColumnType
          :dbschema_alter_column_type
        when ::DbSchema::Operations::CreatePrimaryKey,
             ::DbSchema::Operations::DropPrimaryKey,
             ::DbSchema::Operations::AllowNull,
             ::DbSchema::Operations::DisallowNull
          :dbschema_column_operation
        when ::DbSchema::Operations::AlterColumnDefault
          :dbschema_alter_column_default
        when ::DbSchema::Operations::CreateIndex
          :dbschema_create_index
        when ::DbSchema::Operations::DropIndex
          :dbschema_column_operation
        when ::DbSchema::Operations::CreateCheckConstraint
          :dbschema_create_check_constraint
        when ::DbSchema::Operations::DropCheckConstraint
          :dbschema_column_operation
        when ::DbSchema::Operations::CreateForeignKey
          :dbschema_create_foreign_key
        when ::DbSchema::Operations::DropForeignKey
          :dbschema_drop_foreign_key
        when ::DbSchema::Operations::CreateEnum
          :dbschema_create_enum
        when ::DbSchema::Operations::DropEnum
          :dbschema_column_operation
        when ::DbSchema::Operations::AlterEnumValues
          :dbschema_alter_enum_values
        when ::DbSchema::Operations::CreateExtension
          :dbschema_create_extension
        when ::DbSchema::Operations::DropExtension
          :dbschema_column_operation
        else
          cast_without_dbschema(object, type)
        end
      end

    private
      def awesome_dbschema_schema(object)
        data = ["tables: #{object.tables.ai}"]
        data << "enums: #{object.enums.ai}" if object.enums.any?
        data << "extensions: #{object.extensions.ai}" if object.extensions.any?

        data_string = data.join(', ')
        "#<DbSchema::Definitions::Schema #{data_string}>"
      end

      def awesome_dbschema_table(object)
        data = ["fields: #{object.fields.ai}"]
        data << "indices: #{object.indices.ai}" if object.indices.any?
        data << "checks: #{object.checks.ai}" if object.checks.any?
        data << "foreign_keys: #{object.foreign_keys.ai}" if object.foreign_keys.any?

        data_string = indent_lines(data.join(', '))
        "#<DbSchema::Definitions::Table #{object.name.ai} #{data_string}>"
      end

      def awesome_dbschema_null_table(object)
        '#<DbSchema::Definitions::NullTable>'
      end

      def awesome_dbschema_field(object)
        options = object.options.map do |k, v|
          key = colorize("#{k}:", :symbol)

          if (k == :default) && v.is_a?(Symbol)
            "#{key} #{colorize(v.to_s, :string)}"
          else
            "#{key} #{v.ai}"
          end
        end.unshift(nil).join(', ')

        primary_key = if object.primary_key?
          ', ' + colorize('primary key', :nilclass)
        else
          ''
        end

        "#<#{object.class} #{object.name.ai}#{options}#{primary_key}>"
      end

      def awesome_dbschema_custom_field(object)
        options = object.options.map do |k, v|
          key = colorize("#{k}:", :symbol)

          if (k == :default) && v.is_a?(Symbol)
            "#{key} #{colorize(v.to_s, :string)}"
          else
            "#{key} #{v.ai}"
          end
        end.unshift(nil).join(', ')

        primary_key = if object.primary_key?
          ', ' + colorize('primary key', :nilclass)
        else
          ''
        end

        "#<DbSchema::Definitions::Field::Custom (#{object.type.ai}) #{object.name.ai}#{options}#{primary_key}>"
      end

      def awesome_dbschema_index(object)
        columns = format_dbschema_fields(object.columns)
        using = ' using ' + colorize(object.type.to_s, :symbol) unless object.btree?

        data = [nil]
        data << colorize('unique', :nilclass) if object.unique?
        data << colorize('condition: ', :symbol) + object.condition.ai unless object.condition.nil?

        "#<#{object.class} #{object.name.ai} on #{columns}#{using}#{data.join(', ')}>"
      end

      def awesome_dbschema_index_column(object)
        data = [object.name.ai]

        if object.desc?
          data << colorize('desc', :nilclass)
          data << colorize('nulls last', :symbol) if object.nulls == :last
        else
          data << colorize('nulls first', :symbol) if object.nulls == :first
        end

        data.join(' ')
      end

      def awesome_dbschema_check_constraint(object)
        "#<#{object.class} #{object.name.ai} #{object.condition.ai}>"
      end

      def awesome_dbschema_foreign_key(object)
        fields = format_dbschema_fields(object.fields)
        references = "#{colorize('references', :class)} #{object.table.ai}"
        references << ' ' + format_dbschema_fields(object.keys) unless object.references_primary_key?

        data = [nil]
        data << colorize("on_update:", :symbol) + " #{object.on_update.ai}" unless object.on_update == :no_action
        data << colorize("on_delete:", :symbol) + " #{object.on_delete.ai}" unless object.on_delete == :no_action
        data << colorize('deferrable', :nilclass) if object.deferrable?

        "#<#{object.class} #{object.name.ai} on #{fields} #{references}#{data.join(', ')}>"
      end

      def awesome_dbschema_enum(object)
        values = object.values.map do |value|
          colorize(value.to_s, :string)
        end.join(', ')

        "#<#{object.class} #{object.name.ai} (#{values})>"
      end

      def awesome_dbschema_create_table(object)
        data = ["fields: #{object.table.fields.ai}"]
        data << "indices: #{object.table.indices.ai}" if object.table.indices.any?
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
        data << colorize('unique', :nilclass) if object.index.unique?
        data << colorize('condition: ', :symbol) + object.index.condition.ai unless object.index.condition.nil?

        "#<#{object.class} #{object.index.name.ai} on #{columns}#{using}#{data.join(', ')}>"
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
