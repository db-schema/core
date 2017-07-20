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
        # BodyYielder.new(migration).run(block)
        migration.body = block
      end

      class BodyYielder
        attr_reader :migration

        def initialize(migration)
          @migration = migration
        end

        def run(block)
          block.call(self)
        end

        def create_table(name, &block)
          table_yielder = TableYielder.new(name, block)

          table = Definitions::Table.new(
            name,
            fields:       table_yielder.fields,
            indices:      table_yielder.indices,
            checks:       table_yielder.checks,
            foreign_keys: table_yielder.foreign_keys
          )

          migration.changes << Operations::CreateTable.new(table)

          table.foreign_keys.each do |fkey|
            migration.changes << Operations::CreateForeignKey.new(table.name, fkey)
          end
        end

        def drop_table(name)
          migration.changes << Operations::DropTable.new(name)
        end

        def rename_table(from, to:)
          migration.changes << Operations::RenameTable.new(old_name: from, new_name: to)
        end

        def alter_table(name, &block)
          alter_table = Operations::AlterTable.new(name)
          AlterTableYielder.new(alter_table, migration).run(block)

          migration.changes << alter_table
        end

        class AlterTableYielder
          attr_reader :alter_table, :migration

          def initialize(alter_table, migration)
            @alter_table = alter_table
            @migration   = migration
          end

          def run(block)
            block.call(self)
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
              TableYielder.build_index(
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
            migration.changes << Operations::CreateForeignKey.new(
              alter_table.table_name,
              TableYielder.build_foreign_key(
                fkey_fields,
                table_name: alter_table.table_name,
                **fkey_options
              )
            )
          end

          def drop_foreign_key(fkey_name)
            migration.changes << Operations::DropForeignKey.new(
              alter_table.table_name,
              fkey_name
            )
          end
        end

        def create_enum(name, values)
          migration.changes << Operations::CreateEnum.new(
            Definitions::Enum.new(name, values)
          )
        end

        def drop_enum(name)
          migration.changes << Operations::DropEnum.new(name)
        end

        def create_extension(name)
          migration.changes << Operations::CreateExtension.new(
            Definitions::Extension.new(name)
          )
        end

        def drop_extension(name)
          migration.changes << Operations::DropExtension.new(name)
        end

        def execute(query)
          migration.changes << Operations::ExecuteQuery.new(query)
        end
      end
    end
  end
end
