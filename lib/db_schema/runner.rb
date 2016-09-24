module DbSchema
  class Runner
    attr_reader :changes

    def initialize(changes)
      @changes = preprocess_changes(changes)
    end

    def run!
      DbSchema.connection.transaction do
        changes.each do |change|
          case change
          when Changes::CreateTable
            self.class.create_table(change)
          when Changes::DropTable
            self.class.drop_table(change)
          when Changes::AlterTable
            self.class.alter_table(change)
          when Changes::CreateForeignKey
            self.class.create_foreign_key(change)
          when Changes::DropForeignKey
            self.class.drop_foreign_key(change)
          when Changes::CreateEnum
            self.class.create_enum(change)
          when Changes::DropEnum
            self.class.drop_enum(change)
          when Changes::CreateExtension
            self.class.create_extension(change)
          when Changes::DropExtension
            self.class.drop_extension(change)
          end
        end
      end

      # Postgres doesn't allow modifying enums inside a transaction
      Utils.filter_by_class(changes, Changes::AddValueToEnum).each do |change|
        self.class.add_value_to_enum(change)
      end
    end

  private
    def preprocess_changes(changes)
      Utils.sort_by_class(
        changes,
        [
          Changes::CreateExtension,
          Changes::AddValueToEnum,
          Changes::DropForeignKey,
          Changes::CreateEnum,
          Changes::CreateTable,
          Changes::AlterTable,
          Changes::DropTable,
          Changes::DropEnum,
          Changes::CreateForeignKey,
          Changes::DropExtension
        ]
      )
    end

    class << self
      def create_table(change)
        DbSchema.connection.create_table(change.name) do
          change.fields.each do |field|
            if field.primary_key?
              primary_key(field.name)
            else
              options = Runner.map_options(field.class.type, field.options)
              column(field.name, field.type.capitalize, options)
            end
          end

          change.indices.each do |index|
            fields = if index.btree?
              index.fields.map(&:to_sequel)
            else
              index.fields.map(&:name)
            end

            index(
              fields,
              name:   index.name,
              unique: index.unique?,
              type:   index.type,
              where:  index.condition
            )
          end

          change.checks.each do |check|
            constraint(check.name, check.condition)
          end
        end
      end

      def drop_table(change)
        DbSchema.connection.drop_table(change.name)
      end

      def alter_table(change)
        DbSchema.connection.alter_table(change.name) do
          Utils.sort_by_class(
            change.fields + change.indices + change.checks,
            [
              DbSchema::Changes::DropPrimaryKey,
              DbSchema::Changes::DropCheckConstraint,
              DbSchema::Changes::DropIndex,
              DbSchema::Changes::DropColumn,
              DbSchema::Changes::RenameColumn,
              DbSchema::Changes::AlterColumnType,
              DbSchema::Changes::AllowNull,
              DbSchema::Changes::DisallowNull,
              DbSchema::Changes::AlterColumnDefault,
              DbSchema::Changes::CreateColumn,
              DbSchema::Changes::CreateIndex,
              DbSchema::Changes::CreateCheckConstraint,
              DbSchema::Changes::CreatePrimaryKey
            ]
          ).each do |element|
            case element
            when Changes::CreateColumn
              if element.primary_key?
                add_primary_key(element.name)
              else
                options = Runner.map_options(element.type, element.options)
                add_column(element.name, element.type.capitalize, options)
              end
            when Changes::DropColumn
              drop_column(element.name)
            when Changes::RenameColumn
              rename_column(element.old_name, element.new_name)
            when Changes::AlterColumnType
              attributes = Runner.map_options(element.new_type, element.new_attributes)
              set_column_type(element.name, element.new_type.capitalize, attributes)
            when Changes::CreatePrimaryKey
              raise NotImplementedError, 'Converting an existing column to primary key is currently unsupported'
            when Changes::DropPrimaryKey
              raise NotImplementedError, 'Removing a primary key while leaving the column is currently unsupported'
            when Changes::AllowNull
              set_column_allow_null(element.name)
            when Changes::DisallowNull
              set_column_not_null(element.name)
            when Changes::AlterColumnDefault
              set_column_default(element.name, element.new_default)
            when Changes::CreateIndex
              fields = if element.btree?
                element.fields.map(&:to_sequel)
              else
                element.fields.map(&:name)
              end

              add_index(
                fields,
                name:   element.name,
                unique: element.unique?,
                type:   element.type,
                where:  element.condition
              )
            when Changes::DropIndex
              drop_index([], name: element.name)
            when Changes::CreateCheckConstraint
              add_constraint(element.name, element.condition)
            when Changes::DropCheckConstraint
              drop_constraint(element.name)
            end
          end
        end
      end

      def create_foreign_key(change)
        DbSchema.connection.alter_table(change.table_name) do
          add_foreign_key(change.foreign_key.fields, change.foreign_key.table, change.foreign_key.options)
        end
      end

      def drop_foreign_key(change)
        DbSchema.connection.alter_table(change.table_name) do
          drop_foreign_key([], name: change.fkey_name)
        end
      end

      def create_enum(change)
        DbSchema.connection.create_enum(change.name, change.values)
      end

      def drop_enum(change)
        DbSchema.connection.drop_enum(change.name)
      end

      def add_value_to_enum(change)
        if change.add_to_the_end?
          DbSchema.connection.add_enum_value(change.enum_name, change.new_value)
        else
          DbSchema.connection.add_enum_value(change.enum_name, change.new_value, before: change.before)
        end
      end

      def create_extension(change)
        DbSchema.connection.run(%Q(CREATE EXTENSION "#{change.name}"))
      end

      def drop_extension(change)
        DbSchema.connection.run(%Q(DROP EXTENSION "#{change.name}"))
      end

      def map_options(type, options)
        mapping = case type
        when :char, :varchar, :bit, :varbit
          Utils.rename_keys(options, length: :size)
        when :numeric
          Utils.rename_keys(options) do |new_options|
            precision, scale = Utils.delete_at(new_options, :precision, :scale)

            if precision
              if scale
                new_options[:size] = [precision, scale]
              else
                new_options[:size] = precision
              end
            end
          end
        when :interval
          Utils.rename_keys(options, precision: :size) do |new_options|
            new_options[:type] = "INTERVAL #{new_options.delete(:fields).upcase}"
          end
        when :array
          Utils.rename_keys(options) do |new_options|
            new_options[:type] = "#{new_options.delete(:element_type)}[]"
          end
        else
          options
        end
      end
    end
  end
end
