module DbSchema
  class Validator
    attr_reader :schema

    def initialize(schema)
      @schema = schema
    end

    def valid?
      schema.all? do |table|
        field_names = table.fields.map(&:name)

        table.indices.all? do |index|
          index.fields.map(&:name).all? do |field_name|
            field_names.include?(field_name)
          end
        end
      end
    end
  end
end
