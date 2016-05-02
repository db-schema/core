module DbSchema
  class Runner
    attr_reader :tables

    def initialize(tables)
      @tables = tables
    end

    def run!
      tables.each do |table|
        DbSchema.connection.create_table(table.name) do
          table.fields.each do |field|
            field_options = {}
            field_options[:primary_key] = true if field.primary_key?
            field_options[:null] = false unless field.null?
            field_options[:default] = field.default unless field.default.nil?

            column(field.name, field.type, field_options)
          end
        end
      end
    end
  end
end
