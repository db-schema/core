require 'digest/md5'

module DbSchema
  class Normalizer
    attr_reader :schema, :connection

    def initialize(schema, connection)
      @schema     = schema
      @connection = connection
    end

    def normalize_tables
      connection.transaction do
        create_extensions!
        create_enums!
        create_temporary_tables!
        normalized_tables = read_temporary_tables

        schema.tables = schema.tables.map do |table|
          if table.has_expressions?
            normalized_tables.fetch(table.name)
          else
            table
          end
        end

        raise Sequel::Rollback
      end
    end

  private
    def create_extensions!
      operations = (schema.extensions - Reader.reader_for(connection).read_extensions).map do |extension|
        Operations::CreateExtension.new(extension)
      end

      Runner.new(operations, connection).run!
    end

    def create_enums!
      operations = schema.enums.map do |enum|
        Operations::CreateEnum.new(enum.with_name(append_hash(enum.name)))
      end

      Runner.new(operations, connection).run!
    end

    def create_temporary_tables!
      schema.tables.select(&:has_expressions?).each do |table|
        temporary_table_name = append_hash(table.name)

        operation = Operations::CreateTable.new(
          table.with_name(temporary_table_name)
            .with_fields(rename_types(table.fields))
            .with_indexes(rename_indexes(table.indexes))
            .with_checks(rename_types_in_checks(table.checks))
        )

        Runner.new([operation], connection).run!
      end
    end

    def read_temporary_tables
      all_tables = Reader.reader_for(connection).read_tables

      schema.tables.select(&:has_expressions?).reduce({}) do |normalized_tables, table|
        temporary_table = all_tables.find do |t|
          t.name == append_hash(table.name).to_sym
        end || raise

        normalized_tables.merge(
          table.name => temporary_table.with_name(table.name)
                          .with_fields(rename_types_back(temporary_table.fields))
                          .with_indexes(rename_indexes_back(temporary_table.indexes))
                          .with_checks(rename_types_in_checks_back(temporary_table.checks))
                          .with_foreign_keys(table.foreign_keys)
        )
      end
    end

    def rename_types(fields)
      fields.map do |field|
        new_default = if field.default_is_expression?
          rename_all_types_in(field.default.to_s).to_sym
        else
          field.default
        end

        if field.custom?
          field.with_type(append_hash(field.type))
        elsif field.array? && field.custom_element_type?
          field.with_attribute(:element_type, append_hash(field.element_type.type).to_sym)
        else
          field
        end.with_default(new_default)
      end
    end

    def rename_types_back(fields)
      fields.map do |field|
        new_default = if field.default_is_expression?
          rename_all_types_back_in(field.default.to_s).to_sym
        else
          field.default
        end

        if field.custom?
          field.with_type(remove_hash(field.type))
        elsif field.array? && field.custom_element_type?
          field.with_attribute(:element_type, remove_hash(field.element_type.type).to_sym)
        else
          field
        end.with_default(new_default)
      end
    end

    def rename_indexes(indexes)
      indexes.map do |index|
        index
          .with_name(append_hash(index.name))
          .with_condition(rename_all_types_in(index.condition))
      end
    end

    def rename_indexes_back(indexes)
      indexes.map do |index|
        index
          .with_name(remove_hash(index.name))
          .with_condition(rename_all_types_back_in(index.condition))
      end
    end

    def rename_types_in_checks(checks)
      checks.map do |check|
        check.with_condition(rename_all_types_in(check.condition))
      end
    end

    def rename_types_in_checks_back(checks)
      checks.map do |check|
        check.with_condition(rename_all_types_back_in(check.condition))
      end
    end

    def append_hash(name)
      "#{name}_#{hash}"
    end

    def remove_hash(name)
      name.to_s.sub(/_#{Regexp.escape(hash)}$/, '').to_sym
    end

    def rename_all_types_in(string)
      return string unless string.is_a?(String)

      enum_renaming.reduce(string) do |new_string, (from, to)|
        new_string.gsub(from, to)
      end
    end

    def rename_all_types_back_in(string)
      return string unless string.is_a?(String)

      enum_renaming.invert.reduce(string) do |new_string, (from, to)|
        new_string.gsub(from, to)
      end
    end

    def enum_renaming
      schema.enums.reduce({}) do |hash, enum|
        hash.merge("::#{enum.name}" => "::#{append_hash(enum.name)}")
      end
    end

    def hash
      @hash ||= begin
        names = schema.tables.flat_map do |table|
          [table.name] + table.fields.map(&:name) + table.indexes.map(&:name) + table.checks.map(&:name)
        end

        Digest::MD5.hexdigest(names.join(','))[0..9]
      end
    end
  end
end
