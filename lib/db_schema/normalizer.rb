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

        schema.tables = schema.tables.map do |table|
          if table.has_expressions?
            Table.new(table, hash, connection).normalized_table
          else
            table
          end
        end

        raise Sequel::Rollback
      end
    end

  private
    def create_extensions!
      operations = (schema.extensions - Reader.read_extensions(connection)).map do |extension|
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

    def append_hash(name)
      "#{name}_#{hash}"
    end

    def hash
      @hash ||= begin
        names = schema.tables.flat_map do |table|
          [table.name] + table.fields.map(&:name) + table.indices.map(&:name) + table.checks.map(&:name)
        end

        Digest::MD5.hexdigest(names.join(','))[0..9]
      end
    end

    class Table
      attr_reader :table, :hash, :connection

      def initialize(table, hash, connection)
        @table      = table
        @hash       = hash
        @connection = connection
      end

      def normalized_table
        create_temporary_table!
        read_temporary_table
      end

    private
      def create_temporary_table!
        operation = Operations::CreateTable.new(
          table.with_name(temporary_table_name)
            .with_fields(rename_types(table.fields))
            .with_indices(rename_indices(table.indices))
        )

        Runner.new([operation], connection).run!
      end

      def read_temporary_table
        temporary_table = Reader.read_table(temporary_table_name, connection)

        temporary_table.with_name(table.name)
          .with_fields(rename_types_back(temporary_table.fields))
          .with_indices(rename_indices_back(temporary_table.indices))
          .with_foreign_keys(table.foreign_keys)
      end

      def rename_types(fields)
        fields.map do |field|
          if field.custom?
            field.with_type(append_hash(field.type))
          elsif field.array? && field.custom_element_type?
            field.with_attribute(:element_type, append_hash(field.element_type.type).to_sym)
          else
            field
          end
        end
      end

      def rename_types_back(fields)
        fields.map do |field|
          if field.custom?
            field.with_type(remove_hash(field.type))
          elsif field.array? && field.custom_element_type?
            field.with_attribute(:element_type, remove_hash(field.element_type.type).to_sym)
          else
            field
          end
        end
      end

      def rename_indices(indices)
        indices.map do |index|
          index.with_name(append_hash(index.name))
        end
      end

      def rename_indices_back(indices)
        indices.map do |index|
          index.with_name(remove_hash(index.name))
        end
      end

      def temporary_table_name
        append_hash(table.name)
      end

      def append_hash(name)
        "#{name}_#{hash}"
      end

      def remove_hash(name)
        name.to_s.sub(/_#{Regexp.escape(hash)}$/, '').to_sym
      end
    end
  end
end
