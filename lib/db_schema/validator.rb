module DbSchema
  module Validator
    class << self
      def validate(schema)
        errors = schema.each_with_object([]) do |table, errors|
          field_names = table.fields.map(&:name)

          table.indices.each do |index|
            index.fields.map(&:name).each do |field_name|
              unless field_names.include?(field_name)
                error_message = %(Index "#{index.name}" refers to a missing field "#{table.name}.#{field_name}")
                errors << error_message
              end
            end
          end
        end

        Result.new(errors)
      end
    end

    class Result
      attr_reader :errors

      def initialize(errors)
        @errors = errors
      end

      def valid?
        errors.empty?
      end
    end
  end
end
