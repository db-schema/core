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
        when ::DbSchema::Definitions::Table
          :dbschema_table
        when ::DbSchema::Definitions::Field::Base
          :dbschema_field
        when ::DbSchema::Definitions::Index
          :dbschema_index
        when ::DbSchema::Definitions::Index::Field
          :dbschema_index_field
        when ::DbSchema::Definitions::CheckConstraint
          :dbschema_check_constraint
        when ::DbSchema::Definitions::ForeignKey
          :dbschema_foreign_key
        when ::DbSchema::Changes::CreateTable
          :dbschema_create_table
        when ::DbSchema::Changes::DropTable
          :dbschema_drop_table
        when ::DbSchema::Changes::AlterTable
          :dbschema_alter_table
        when ::DbSchema::Changes::CreateColumn
          :dbschema_create_column
        when ::DbSchema::Changes::DropColumn
          :dbschema_column_operation
        when ::DbSchema::Changes::RenameColumn
          :dbschema_rename_column
        when ::DbSchema::Changes::AlterColumnType
          :dbschema_alter_column_type
        when ::DbSchema::Changes::CreatePrimaryKey,
             ::DbSchema::Changes::DropPrimaryKey,
             ::DbSchema::Changes::AllowNull,
             ::DbSchema::Changes::DisallowNull
          :dbschema_column_operation
        when ::DbSchema::Changes::AlterColumnDefault
          :dbschema_alter_column_default
        when ::DbSchema::Changes::CreateIndex
          :dbschema_index
        when ::DbSchema::Changes::DropIndex
          :dbschema_column_operation
        when ::DbSchema::Changes::CreateCheckConstraint
          :dbschema_check_constraint
        when ::DbSchema::Changes::DropCheckConstraint
          :dbschema_column_operation
        when ::DbSchema::Changes::CreateForeignKey
          :dbschema_create_foreign_key
        when ::DbSchema::Changes::DropForeignKey
          :dbschema_drop_foreign_key
        else
          cast_without_dbschema(object, type)
        end
      end

    private
      def awesome_dbschema_table(object)
        data = ["fields: #{object.fields.ai}"]
        data << "indices: #{object.indices.ai}" if object.indices.any?
        data << "checks: #{object.checks.ai}" if object.checks.any?
        data << "foreign_keys: #{object.foreign_keys.ai}" if object.foreign_keys.any?

        data_string = indent_lines(data.join(', '))
        "#<DbSchema::Definitions::Table #{object.name.ai} #{data_string}>"
      end

      def awesome_dbschema_field(object)
        options = object.options.map do |k, v|
          key = colorize("#{k}:", :symbol)
          "#{key} #{v.ai}"
        end.unshift(nil).join(', ')

        primary_key = if object.primary_key?
          ', ' + colorize('primary key', :nilclass)
        else
          ''
        end

        "#<#{object.class} #{object.name.ai}#{options}#{primary_key}>"
      end

      def awesome_dbschema_index(object)
        fields = format_dbschema_fields(object.fields)
        using = ' using ' + colorize(object.type.to_s, :symbol) unless object.btree?

        data = [nil]
        data << colorize('unique', :nilclass) if object.unique?
        data << colorize('condition: ', :symbol) + object.condition.ai unless object.condition.nil?

        "#<#{object.class} #{object.name.ai} on #{fields}#{using}#{data.join(', ')}>"
      end

      def awesome_dbschema_index_field(object)
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

      def awesome_dbschema_create_table(object)
        data = ["fields: #{object.fields.ai}"]
        data << "indices: #{object.indices.ai}" if object.indices.any?
        data << "checks: #{object.checks.ai}" if object.checks.any?

        data_string = indent_lines(data.join(', '))
        "#<DbSchema::Changes::CreateTable #{object.name.ai} #{data_string}>"
      end

      def awesome_dbschema_drop_table(object)
        "#<DbSchema::Changes::DropTable #{object.name.ai}>"
      end

      def awesome_dbschema_alter_table(object)
        data = ["fields: #{object.fields.ai}"]
        data << "indices: #{object.indices.ai}" if object.indices.any?
        data << "checks: #{object.checks.ai}" if object.checks.any?

        data_string = indent_lines(data.join(', '))
        "#<DbSchema::Changes::AlterTable #{object.name.ai} #{data_string}>"
      end

      def awesome_dbschema_create_column(object)
        "#<DbSchema::Changes::CreateColumn #{object.field.ai}>"
      end

      def awesome_dbschema_drop_column(object)
        "#<DbSchema::Changes::DropColumn #{object.name.ai}>"
      end

      def awesome_dbschema_rename_column(object)
        "#<DbSchema::Changes::RenameColumn #{object.old_name.ai} => #{object.new_name.ai}>"
      end

      def awesome_dbschema_alter_column_type(object)
        attributes = object.new_attributes.map do |k, v|
          key = colorize("#{k}:", :symbol)
          "#{key} #{v.ai}"
        end.join(', ')

        "#<DbSchema::Changes::AlterColumnType #{object.name.ai}, #{object.new_type.ai}, #{attributes}>"
      end

      def awesome_dbschema_alter_column_default(object)
        "#<DbSchema::Changes::AlterColumnDefault #{object.name.ai}, #{object.new_default.ai}>"
      end

      def awesome_dbschema_create_foreign_key(object)
        "#<DbSchema::Changes::CreateForeignKey #{object.foreign_key.ai} on #{object.table_name.ai}>"
      end

      def awesome_dbschema_drop_foreign_key(object)
        "#<DbSchema::Changes::DropForeignKey #{object.fkey_name.ai} on #{object.table_name.ai}>"
      end

      def awesome_dbschema_column_operation(object)
        "#<#{object.class} #{object.name.ai}>"
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
