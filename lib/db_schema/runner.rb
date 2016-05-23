module DbSchema
  class Runner
    attr_reader :changes

    def initialize(changes)
      @changes = changes
    end

    def run!
      changes.each do |change|
        case change
        when Changes::CreateTable
          create_table(change)
        when Changes::DropTable
          drop_table(change)
        when Changes::AlterTable
          alter_table(change)
        end
      end
    end

  private
    def create_table(change)
      DbSchema.connection.create_table(change.name) do
        change.fields.each do |field|
          if field.primary_key?
            primary_key(field.name)
          else
            column(field.name, field.type, field.options)
          end
        end

        change.indices.each do |index|
          index(index.fields, name: index.name, unique: index.unique?)
        end
      end
    end

    def drop_table(change)
      DbSchema.connection.drop_table(change.name)
    end

    def alter_table(change)
      DbSchema.connection.alter_table(change.name) do
        change.fields.each do |field|
          case field
          when Changes::CreateColumn
            if field.primary_key?
              add_primary_key(field.name)
            else
              add_column(field.name, field.type, field.options)
            end
          when Changes::DropColumn
            drop_column(field.name)
          when Changes::RenameColumn
            rename_column(field.old_name, field.new_name)
          when Changes::AlterColumnType
            set_column_type(field.name, field.new_type)
          when Changes::CreatePrimaryKey
            raise NotImplementedError, 'Converting an existing column to primary key is currently unsupported'
          when Changes::DropPrimaryKey
            raise NotImplementedError, 'Removing a primary key while leaving the column is currently unsupported'
          when Changes::AllowNull
            set_column_allow_null(field.name)
          when Changes::DisallowNull
            set_column_not_null(field.name)
          when Changes::AlterColumnDefault
            set_column_default(field.name, field.new_default)
          end
        end

        change.indices.each do |index|
          case index
          when Changes::CreateIndex
            add_index(index.fields, name: index.name, unique: index.unique?)
          when Changes::DropIndex
            drop_index([], name: index.name)
          end
        end

        change.foreign_keys.each do |foreign_key|
          case foreign_key
          when Changes::CreateForeignKey
            add_foreign_key(foreign_key.fields, foreign_key.table, foreign_key.options)
          when Changes::DropForeignKey
            drop_foreign_key([], name: foreign_key.name)
          end
        end
      end
    end
  end
end
