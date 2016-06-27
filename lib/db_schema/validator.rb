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

          table.foreign_keys.each do |fkey|
            fkey.fields.each do |field_name|
              unless field_names.include?(field_name)
                error_message = %(Foreign key "#{fkey.name}" constrains a missing field "#{table.name}.#{field_name}")
                errors << error_message
              end
            end

            if referenced_table = schema.find { |table| table.name == fkey.table }
              if fkey.references_primary_key?
                unless referenced_table.fields.any?(&:primary_key?)
                  error_message = %(Foreign key "#{fkey.name}" refers to primary key of table "#{fkey.table}" which does not have a primary key)
                  errors << error_message
                end
              else
                referenced_table_field_names = referenced_table.fields.map(&:name)

                fkey.keys.each do |key|
                  unless referenced_table_field_names.include?(key)
                    error_message = %(Foreign key "#{fkey.name}" refers to a missing field "#{fkey.table}.#{key}")
                    errors << error_message
                  end
                end
              end
            else
              error_message = %(Foreign key "#{fkey.name}" refers to a missing table "#{fkey.table}")
              errors << error_message
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
