module DbSchema
  class Runner
    attr_reader :changes, :connection

    def initialize(changes, connection)
      @changes    = changes
      @connection = connection
    end

    def run!
      changes.each do |change|
        case change
        when Operations::CreateTable
          create_table(change)
        when Operations::DropTable
          drop_table(change)
        when Operations::RenameTable
          rename_table(change)
        when Operations::AlterTable
          alter_table(change)
        when Operations::CreateForeignKey
          create_foreign_key(change)
        when Operations::DropForeignKey
          drop_foreign_key(change)
        when Operations::CreateEnum
          create_enum(change)
        when Operations::DropEnum
          drop_enum(change)
        when Operations::RenameEnum
          rename_enum(change)
        when Operations::AlterEnumValues
          alter_enum_values(change)
        when Operations::CreateExtension
          create_extension(change)
        when Operations::DropExtension
          drop_extension(change)
        when Operations::ExecuteQuery
          execute_query(change)
        end
      end
    end

  private
    def create_table(change)
      connection.create_table(change.table.name) do
        change.table.fields.each do |field|
          options = Runner.map_options(field.class.type, field.options)
          column(field.name, field.type.capitalize, options)
        end

        change.table.indexes.each do |index|
          if index.primary?
            primary_key(index.columns.map(&:name), name: index.name)
          else
            index(
              index.columns_to_sequel,
              name:   index.name,
              unique: index.unique?,
              type:   index.type,
              where:  index.condition
            )
          end
        end

        change.table.checks.each do |check|
          constraint(check.name, check.condition)
        end
      end
    end

    def drop_table(change)
      connection.drop_table(change.name)
    end

    def rename_table(change)
      connection.rename_table(change.old_name, change.new_name)
    end

    def alter_table(change)
      connection.alter_table(change.table_name) do
        change.changes.each do |element|
          case element
          when Operations::CreateColumn
            options = Runner.map_options(element.type, element.options)
            add_column(element.name, element.type.capitalize, options)
          when Operations::DropColumn
            drop_column(element.name)
          when Operations::RenameColumn
            rename_column(element.old_name, element.new_name)
          when Operations::AlterColumnType
            if element.from_serial?
              raise NotImplementedError, 'Changing a SERIAL column to another type is not supported'
            end

            if element.to_serial?
              raise NotImplementedError, 'Changing a column type to SERIAL is not supported'
            end

            attributes = Runner.map_options(element.new_type, element.new_attributes)
            set_column_type(element.name, element.new_type.capitalize, using: element.using, **attributes)
          when Operations::AllowNull
            set_column_allow_null(element.name)
          when Operations::DisallowNull
            set_column_not_null(element.name)
          when Operations::AlterColumnDefault
            set_column_default(element.name, Runner.default_to_sequel(element.new_default))
          when Operations::CreateIndex
            if element.primary?
              add_primary_key(element.columns.map(&:name), name: element.name)
            else
              add_index(
                element.index.columns_to_sequel,
                name:   element.index.name,
                unique: element.index.unique?,
                type:   element.index.type,
                where:  element.index.condition
              )
            end
          when Operations::DropIndex
            if element.primary?
              drop_constraint(element.name)
            else
              drop_index([], name: element.name)
            end
          when Operations::CreateCheckConstraint
            add_constraint(element.check.name, element.check.condition)
          when Operations::DropCheckConstraint
            drop_constraint(element.name)
          end
        end
      end
    end

    def create_foreign_key(change)
      connection.alter_table(change.table_name) do
        add_foreign_key(change.foreign_key.fields, change.foreign_key.table, change.foreign_key.options)
      end
    end

    def drop_foreign_key(change)
      connection.alter_table(change.table_name) do
        drop_foreign_key([], name: change.fkey_name)
      end
    end

    def create_enum(change)
      connection.create_enum(change.enum.name, change.enum.values)
    end

    def drop_enum(change)
      connection.drop_enum(change.name)
    end

    def rename_enum(change)
      old_name = connection.quote_identifier(change.old_name)
      new_name = connection.quote_identifier(change.new_name)

      connection.run(%Q(ALTER TYPE #{old_name} RENAME TO #{new_name}))
    end

    def alter_enum_values(change)
      change.enum_fields.each do |field_data|
        connection.alter_table(field_data[:table_name]) do
          set_column_type(field_data[:field_name], :VARCHAR)
          set_column_default(field_data[:field_name], nil)
        end
      end

      connection.drop_enum(change.enum_name)
      connection.create_enum(change.enum_name, change.new_values)

      change.enum_fields.each do |field_data|
        connection.alter_table(field_data[:table_name]) do
          field_type = if field_data[:array]
            "#{change.enum_name}[]"
          else
            change.enum_name
          end

          set_column_type(
            field_data[:field_name],
            field_type,
            using: "#{field_data[:field_name]}::#{field_type}"
          )

          set_column_default(field_data[:field_name], field_data[:new_default]) unless field_data[:new_default].nil?
        end
      end
    end

    def create_extension(change)
      connection.run(%Q(CREATE EXTENSION #{connection.quote_identifier(change.extension.name)}))
    end

    def drop_extension(change)
      connection.run(%Q(DROP EXTENSION #{connection.quote_identifier(change.name)}))
    end

    def execute_query(change)
      connection.run(change.query)
    end

    class << self
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

        if mapping.key?(:default)
          mapping.merge(default: default_to_sequel(mapping[:default]))
        else
          mapping
        end
      end

      def default_to_sequel(default)
        if default.is_a?(Symbol)
          Sequel.lit(default.to_s)
        else
          default
        end
      end
    end
  end
end
