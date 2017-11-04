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

      expect(migration.body).to be_a(Proc)
    end
  end
end
