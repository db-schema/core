module DbSchema
  class Migrator
    attr_reader :migration

    def initialize(migration)
      @migration = migration
    end

    def applicable?(schema)
      migration.conditions[:apply].all? do |condition|
        condition.call(schema)
      end && migration.conditions[:skip].none? do |condition|
        condition.call(schema)
      end
    end

    def run!
      Runner.new(migration.changes).run!
    end
  end
end
