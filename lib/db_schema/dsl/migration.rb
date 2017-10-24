module DbSchema
  class DSL
    class Migration
      attr_reader :migration

      def initialize(name, block)
        @migration = DbSchema::Migration.new(name)
        block.call(self)
      end

      def apply_if(&block)
        migration.conditions[:apply] << block
      end

      def skip_if(&block)
        migration.conditions[:skip] << block
      end

      def run(&block)
        migration.body = block
      end
    end
  end
end
