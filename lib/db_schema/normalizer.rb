require 'digest/md5'

module DbSchema
  class Normalizer
    attr_reader :table

    def initialize(table)
      @table = table
    end

    def normalized_table
      create_temporary_table!
      Reader.read_table(temporary_table_name)
    ensure
      cleanup!
    end

  private
    def create_temporary_table!
      operation = Changes::CreateTable.new(
        temporary_table_name,
        fields:  table.fields,
        indices: rename_indices(table.indices),
        checks:  table.checks
      )

      Runner.new([operation]).run!
    end

    def cleanup!
      operation = Changes::DropTable.new(temporary_table_name)
      Runner.new([operation]).run!
    end

    def rename_indices(indices)
      indices.map do |index|
        Definitions::Index.new(
          name:      append_hash(index.name),
          columns:   index.columns,
          unique:    index.unique?,
          type:      index.type,
          condition: index.condition
        )
      end
    end

    def temporary_table_name
      append_hash(table.name)
    end

    def append_hash(name)
      "#{name}_#{hash}"
    end

    def hash
      @hash ||= begin
        names = [table.name] + table.fields.map(&:name) + table.indices.map(&:name) + table.checks.map(&:name)
        Digest::MD5.hexdigest(names.join(','))[0..9]
      end
    end
  end
end
