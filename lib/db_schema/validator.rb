module DbSchema
  module Validator
    class << self
      def validate(schema)
        tables = Utils.filter_by_class(schema, Definitions::Table)

        errors = tables.each_with_object([]) do |table, errors|
          primary_keys_count = table.fields.select(&:primary_key?).count
          if primary_keys_count > 1
            error_message = %(Table "#{table.name}" has #{primary_keys_count} primary keys)
            errors << error_message
          end

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
