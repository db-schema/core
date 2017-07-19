require 'spec_helper'

RSpec.describe DbSchema::DSL::Migration do
  describe '#migration' do
    let(:schema) do
      schema_block = -> (db) do
        db.table :people do |t|
          t.primary_key :id
        end
      end

      DbSchema::DSL.new(schema_block).schema
    end

    let(:migration_block) do
      -> (migration) do
        migration.apply_if do |schema|
          schema.has_table?(:people)
        end

        migration.skip_if do |schema|
          schema.has_table?(:users)
        end

        migration.run do |migrator|
          migrator.create_table :users do |t|
            t.primary_key :id
            t.varchar :first_name
            t.varchar :last_name
            t.integer :city_id, null: false, references: :cities
          end

          migrator.drop_table :people

          migrator.rename_table :comments, to: :messages

          migrator.alter_table :messages do |t|
            t.add_column :title, :varchar, null: false
            t.drop_column :updated_at
            t.rename_column :body, to: :text
            t.alter_column_type :created_at, :timestamptz
            t.alter_column_type :read, :boolean, using: 'read::boolean'
            t.allow_null :text
            t.disallow_null :created_at
            t.alter_column_default :created_at, :'now()'

            t.add_index :user_id
            t.drop_index :messages_created_at_index

            t.add_check :title_length, 'char_length(title) >= 5'
            t.drop_check :text_length

            t.add_foreign_key :user_id, references: :users
            t.drop_foreign_key :messages_section_id_fkey
          end

          migrator.create_enum :user_role, %i(guest user admin)
          migrator.drop_enum :user_mood

          migrator.create_extension :ltree
          migrator.drop_extension :hstore

          migrator.execute 'UPDATE messages SET read = "t"'
        end
      end
    end

    subject { DbSchema::DSL::Migration.new('Migration name', migration_block) }

    it 'returns the migration object' do
      migration = subject.migration

      expect(migration.name).to eq('Migration name')

      expect(migration.conditions[:apply].count).to eq(1)
      expect(migration.conditions[:apply].first.call(schema)).to eq(true)
      expect(migration.conditions[:skip].count).to eq(1)
      expect(migration.conditions[:skip].first.call(schema)).to eq(false)

      expect(migration.changes).to eq([
        DbSchema::Operations::CreateTable.new(
          DbSchema::Definitions::Table.new(
            :users,
            fields: [
              DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
              DbSchema::Definitions::Field::Varchar.new(:first_name),
              DbSchema::Definitions::Field::Varchar.new(:last_name),
              DbSchema::Definitions::Field::Integer.new(:city_id, null: false)
            ],
            foreign_keys: [
              DbSchema::Definitions::ForeignKey.new(name: :users_city_id_fkey, fields: [:city_id], table: :cities)
            ]
          )
        ),
        DbSchema::Operations::CreateForeignKey.new(
          :users,
          DbSchema::Definitions::ForeignKey.new(name: :users_city_id_fkey, fields: [:city_id], table: :cities)
        ),
        DbSchema::Operations::DropTable.new(:people),
        DbSchema::Operations::RenameTable.new(old_name: :comments, new_name: :messages),
        DbSchema::Operations::CreateForeignKey.new(
          :messages,
          DbSchema::Definitions::ForeignKey.new(
            name: :messages_user_id_fkey,
            fields: [:user_id],
            table: :users
          )
        ),
        DbSchema::Operations::DropForeignKey.new(:messages, :messages_section_id_fkey),
        DbSchema::Operations::AlterTable.new(
          :messages,
          [
            DbSchema::Operations::CreateColumn.new(
              DbSchema::Definitions::Field::Varchar.new(:title, null: false)
            ),
            DbSchema::Operations::DropColumn.new(:updated_at),
            DbSchema::Operations::RenameColumn.new(old_name: :body, new_name: :text),
            DbSchema::Operations::AlterColumnType.new(:created_at, new_type: :timestamptz),
            DbSchema::Operations::AlterColumnType.new(:read, new_type: :boolean, using: 'read::boolean'),
            DbSchema::Operations::AllowNull.new(:text),
            DbSchema::Operations::DisallowNull.new(:created_at),
            DbSchema::Operations::AlterColumnDefault.new(:created_at, new_default: :'now()'),
            DbSchema::Operations::CreateIndex.new(
              DbSchema::Definitions::Index.new(
                name: :messages_user_id_index,
                columns: [
                  DbSchema::Definitions::Index::TableField.new(:user_id)
                ]
              )
            ),
            DbSchema::Operations::DropIndex.new(:messages_created_at_index),
            DbSchema::Operations::CreateCheckConstraint.new(
              DbSchema::Definitions::CheckConstraint.new(name: :title_length, condition: 'char_length(title) >= 5')
            ),
            DbSchema::Operations::DropCheckConstraint.new(:text_length)
          ]
        ),
        DbSchema::Operations::CreateEnum.new(
          DbSchema::Definitions::Enum.new(:user_role, %i(guest user admin))
        ),
        DbSchema::Operations::DropEnum.new(:user_mood),
        DbSchema::Operations::CreateExtension.new(
          DbSchema::Definitions::Extension.new(:ltree)
        ),
        DbSchema::Operations::DropExtension.new(:hstore),
        DbSchema::Operations::ExecuteQuery.new('UPDATE messages SET read = "t"')
      ])
    end
  end
end
