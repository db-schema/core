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
      migration.body.call(BodyYielder) unless migration.body.nil?
    end

    module BodyYielder
      class << self
        def create_table(name, &block)
          table_yielder = DSL::TableYielder.new(name, block)

          table = Definitions::Table.new(
            name,
            fields:       table_yielder.fields,
            indices:      table_yielder.indices,
            checks:       table_yielder.checks,
            foreign_keys: table_yielder.foreign_keys
          )

          run Operations::CreateTable.new(table)

          table.foreign_keys.each do |fkey|
            run Operations::CreateForeignKey.new(table.name, fkey)
          end
        end

        def drop_table(name)
          run Operations::DropTable.new(name)
        end

        def rename_table(from, to:)
          run Operations::RenameTable.new(old_name: from, new_name: to)
        end

        def alter_table(name, &block)
          run AlterTableYielder.new(name).run(block)
        end

        class AlterTableYielder
          attr_reader :alter_table, :fkey_operations

          def initialize(table_name)
            @alter_table = Operations::AlterTable.new(table_name)
            @fkey_operations = []
          end

          def run(block)
            block.call(self)

            [alter_table, *fkey_operations]
          end

          def add_column(name, type, **options)
            alter_table.changes << Operations::CreateColumn.new(
              Definitions::Field.build(name, type, options)
            )
          end

          def drop_column(name)
            alter_table.changes << Operations::DropColumn.new(name)
          end

          def rename_column(from, to:)
            alter_table.changes << Operations::RenameColumn.new(old_name: from, new_name: to)
          end

          def alter_column_type(name, new_type, using: nil, **new_attributes)
            alter_table.changes << Operations::AlterColumnType.new(
              name,
              new_type: new_type,
              using: using,
              **new_attributes
            )
          end

          def allow_null(name)
            alter_table.changes << Operations::AllowNull.new(name)
          end

          def disallow_null(name)
            alter_table.changes << Operations::DisallowNull.new(name)
          end

          def alter_column_default(name, new_default)
            alter_table.changes << Operations::AlterColumnDefault.new(name, new_default: new_default)
          end

          def add_index(*columns, **index_options)
            alter_table.changes << Operations::CreateIndex.new(
              DSL::TableYielder.build_index(
                columns,
                table_name: alter_table.table_name,
                **index_options
              )
            )
          end

          def drop_index(name)
            alter_table.changes << Operations::DropIndex.new(name)
          end

          def add_check(name, condition)
            alter_table.changes << Operations::CreateCheckConstraint.new(
              Definitions::CheckConstraint.new(name: name, condition: condition)
            )
          end

          def drop_check(name)
            alter_table.changes << Operations::DropCheckConstraint.new(name)
          end

          def add_foreign_key(*fkey_fields, **fkey_options)
            fkey_operations << Operations::CreateForeignKey.new(
              alter_table.table_name,
              DSL::TableYielder.build_foreign_key(
                fkey_fields,
                table_name: alter_table.table_name,
                **fkey_options
              )
            )
          end

          def drop_foreign_key(fkey_name)
            fkey_operations << Operations::DropForeignKey.new(
              alter_table.table_name,
              fkey_name
            )
          end
        end

        def create_enum(name, values)
          run Operations::CreateEnum.new(Definitions::Enum.new(name, values))
        end

        def drop_enum(name)
          run Operations::DropEnum.new(name)
        end

        def create_extension(name)
          run Operations::CreateExtension.new(Definitions::Extension.new(name))
        end

        def drop_extension(name)
          run Operations::DropExtension.new(name)
        end

        def execute(query)
          run Operations::ExecuteQuery.new(query)
        end

        private

        def run(operation)
          Runner.new(Array(operation)).run!
        end
      end
    end
  end
end
