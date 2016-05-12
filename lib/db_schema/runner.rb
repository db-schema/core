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
          column(field.name, field.type, field.options)
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
            add_column(field.name, field.type, field.options)
          when Changes::DropColumn
            drop_column(field.name)
          end
        end
      end
    end
  end
end
