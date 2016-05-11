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
        end
      end
    end

  private
    def create_table(change)
      DbSchema.connection.create_table(change.name) do
        change.fields.each do |field|
          field_options = {}
          field_options[:primary_key] = true if field.primary_key?
          field_options[:null] = false unless field.null?
          field_options[:default] = field.default unless field.default.nil?

          column(field.name, field.type, field_options)
        end
      end
    end

    def drop_table(change)
      DbSchema.connection.drop_table(change.name)
    end
  end
end
