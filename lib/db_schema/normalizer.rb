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
        indices: table.indices,
        checks:  table.checks
      )

      Runner.new([operation]).run!
    end

    def cleanup!
      operation = Changes::DropTable.new(temporary_table_name)
      Runner.new([operation]).run!
    end

    def temporary_table_name
      @table_name ||= begin
        names = [table.name] + table.fields.map(&:name) + table.indices.map(&:name) + table.checks.map(&:name)
        hash  = Digest::MD5.hexdigest(names.join(','))[0..9]

        [table.name, hash].join('_')
      end
    end
  end
end
