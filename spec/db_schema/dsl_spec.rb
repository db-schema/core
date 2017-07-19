require 'spec_helper'

RSpec.describe DbSchema::DSL do
  let(:schema_block) do
    -> (db) do
      db.enum :user_status, %i(user moderator admin)

      db.extension :hstore

      db.table :users do |t|
        t.primary_key :id
        t.varchar     :name, null: false, unique: true, check: 'char_length(name) > 0'
        t.varchar     :email, default: 'mail@example.com'
        t.char        :sex, index: true
        t.integer     :city_id, references: :cities
        t.array       :strings, of: :varchar
        t.user_status :status, null: false
        t.array       :previous_statuses, of: :user_status
        t.happiness   :mood, index: true
        t.timestamptz :created_at, default: :'now()'

        t.index :email, name: :users_email_idx, unique: true, where: 'email IS NOT NULL'
        t.index :strings, using: :gin
        t.index 'lower(email)'

        t.check :valid_sex, "sex IN ('M', 'F')"
      end

      db.enum :happiness, [:sad, :ok, :good, :happy]

      db.table :cities do |t|
        t.primary_key :id
        t.varchar :name, null: false
      end

      db.table :posts do |t|
        t.primary_key :id
        t.varchar :title
        t.integer :user_id
        t.varchar :user_name
        t.integer :col1
        t.integer :col2
        t.integer :col3
        t.integer :col4

        t.index :user_id
        t.index col1: :asc, col2: :desc, col3: :asc_nulls_first, col4: :desc_nulls_last
        t.index 'col2 - col1' => :desc, 'col3 + col4' => :asc_nulls_first

        t.foreign_key :user_id, references: :users, on_delete: :set_null, deferrable: true
        t.foreign_key :user_name, references: [:users, :name], name: :user_name_fkey, on_update: :cascade
      end

      db.migrate 'Rename people to users' do |migration|
        migration.apply_if do |schema|
          schema.has_table?(:people)
        end

        migration.run do |migrator|
          migrator.rename_table :people, to: :users
        end
      end

      db.migrate 'Join first_name & last_name into name' do |migration|
        migration.apply_if do |schema|
          schema.table(:users).has_field?(:first_name)
        end

        migration.apply_if do |schema|
          schema.table(:users).has_field?(:last_name)
        end

        migration.skip_if do |schema|
          schema.table(:users).has_field?(:name)
        end

        migration.run do |migrator|
          migrator.alter_table(:users) do |t|
            t.add_column :name, :varchar
            # copy data from first_name & last_name to name
            t.disallow_null :name
            t.drop_column :first_name
            t.drop_column :last_name
          end
        end
      end
    end
  end

  subject { DbSchema::DSL.new(schema_block) }

  describe '#schema' do
    it 'returns a schema definition' do
      schema = subject.schema

      users, cities, posts   = schema.tables
      user_status, happiness = schema.enums
      hstore                 = schema.extensions.first

      expect(user_status.name).to eq(:user_status)
      expect(user_status.values).to eq(%i(user moderator admin))

      expect(hstore).to eq(DbSchema::Definitions::Extension.new(:hstore))

      expect(users.name).to eq(:users)
      expect(users.fields.count).to eq(10)
      expect(cities.name).to eq(:cities)
      expect(cities.fields.count).to eq(2)
      expect(posts.name).to eq(:posts)
      expect(posts.fields.count).to eq(8)

      id, name, email, sex, city_id, strings, status, previous_statuses, mood, created_at = users.fields

      expect(id).to be_a(DbSchema::Definitions::Field::Integer)
      expect(id.name).to eq(:id)
      expect(id).to be_primary_key

      expect(name).to be_a(DbSchema::Definitions::Field::Varchar)
      expect(name.name).to eq(:name)
      expect(name).not_to be_null

      expect(email).to be_a(DbSchema::Definitions::Field::Varchar)
      expect(email.name).to eq(:email)
      expect(email.default).to eq('mail@example.com')

      expect(sex).to be_a(DbSchema::Definitions::Field::Char)
      expect(sex.name).to eq(:sex)
      expect(sex.options[:length]).to eq(1)

      expect(city_id).to be_a(DbSchema::Definitions::Field::Integer)
      expect(city_id.name).to eq(:city_id)

      expect(strings).to be_a(DbSchema::Definitions::Field::Array)
      expect(strings.name).to eq(:strings)
      expect(strings.options[:element_type]).to eq(:varchar)

      expect(status).to be_a(DbSchema::Definitions::Field::Custom)
      expect(status.name).to eq(:status)
      expect(status.type).to eq(:user_status)
      expect(status).not_to be_null

      expect(previous_statuses).to be_a(DbSchema::Definitions::Field::Array)
      expect(previous_statuses.name).to eq(:previous_statuses)
      expect(previous_statuses.options[:element_type]).to eq(:user_status)

      expect(mood).to be_a(DbSchema::Definitions::Field::Custom)
      expect(mood.name).to eq(:mood)
      expect(mood.type).to eq(:happiness)

      expect(created_at).to be_a(DbSchema::Definitions::Field::Timestamptz)
      expect(created_at.name).to eq(:created_at)
      expect(created_at.default).to eq(:'now()')

      expect(users.indices.count).to eq(6)
      name_index, sex_index, mood_index, email_index, strings_index, lower_email_index = users.indices
      expect(name_index.name).to eq(:users_name_index)
      expect(name_index.columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:name)
      ])
      expect(name_index).to be_unique
      expect(sex_index.name).to eq(:users_sex_index)
      expect(sex_index.columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:sex)
      ])
      expect(sex_index).not_to be_unique
      expect(mood_index.name).to eq(:users_mood_index)
      expect(mood_index.columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:mood)
      ])
      expect(mood_index).not_to be_unique
      expect(email_index.name).to eq(:users_email_idx)
      expect(email_index.columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:email)
      ])
      expect(email_index).to be_unique
      expect(email_index).to be_btree
      expect(email_index.condition).to eq('email IS NOT NULL')
      expect(strings_index.name).to eq(:users_strings_index)
      expect(strings_index.type).to eq(:gin)
      expect(lower_email_index.name).to eq(:users_lower_email_index)
      expect(lower_email_index.columns).to eq([
        DbSchema::Definitions::Index::Expression.new('lower(email)')
      ])

      expect(posts.indices.count).to eq(3)

      user_id_index, sorted_index, expression_index = posts.indices
      expect(user_id_index.name).to eq(:posts_user_id_index)
      expect(user_id_index.columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:user_id)
      ])
      expect(user_id_index).not_to be_unique

      expect(sorted_index.name).to eq(:posts_col1_col2_col3_col4_index)
      expect(sorted_index.columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:col1),
        DbSchema::Definitions::Index::TableField.new(:col2, order: :desc),
        DbSchema::Definitions::Index::TableField.new(:col3, nulls: :first),
        DbSchema::Definitions::Index::TableField.new(:col4, order: :desc, nulls: :last)
      ])

      expect(expression_index.name).to eq(:posts_col2_col1_col3_col4_index)
      expect(expression_index.columns).to eq([
        DbSchema::Definitions::Index::Expression.new('col2 - col1', order: :desc),
        DbSchema::Definitions::Index::Expression.new('col3 + col4', nulls: :first)
      ])

      expect(users.foreign_keys.count).to eq(1)
      city_id_fkey = users.foreign_keys.first
      expect(city_id_fkey.name).to eq(:users_city_id_fkey)
      expect(city_id_fkey.fields).to eq([:city_id])
      expect(city_id_fkey.table).to eq(:cities)
      expect(city_id_fkey.references_primary_key?).to eq(true)

      expect(users.checks.count).to eq(2)
      name_check, sex_check = users.checks
      expect(name_check.name).to eq(:users_name_check)
      expect(name_check.condition).to eq('char_length(name) > 0')
      expect(sex_check.name).to eq(:valid_sex)
      expect(sex_check.condition).to eq("sex IN ('M', 'F')")

      expect(posts.foreign_keys.count).to eq(2)
      user_id_fkey, user_name_fkey = posts.foreign_keys
      expect(user_id_fkey.name).to eq(:posts_user_id_fkey)
      expect(user_id_fkey.fields).to eq([:user_id])
      expect(user_id_fkey.table).to eq(:users)
      expect(user_id_fkey.references_primary_key?).to eq(true)
      expect(user_id_fkey.on_delete).to eq(:set_null)
      expect(user_id_fkey.on_update).to eq(:no_action)
      expect(user_id_fkey).to be_deferrable
      expect(user_name_fkey.name).to eq(:user_name_fkey)
      expect(user_name_fkey.fields).to eq([:user_name])
      expect(user_name_fkey.table).to eq(:users)
      expect(user_name_fkey.keys).to eq([:name])
      expect(user_name_fkey.on_delete).to eq(:no_action)
      expect(user_name_fkey.on_update).to eq(:cascade)
      expect(user_name_fkey).not_to be_deferrable

      expect(happiness).to be_a(DbSchema::Definitions::Enum)
      expect(happiness.name).to eq(:happiness)
      expect(happiness.values).to eq(%i(sad ok good happy))
    end
  end

  describe '#migrations' do
    it 'returns all conditional migrations' do
      migrations = subject.migrations
      expect(migrations.count).to eq(2)

      rename_people_to_users, join_names = migrations

      expect(rename_people_to_users.name).to eq('Rename people to users')
      expect(rename_people_to_users.conditions[:apply].count).to eq(1)
      expect(rename_people_to_users.conditions[:skip]).to be_empty
      expect(rename_people_to_users.changes).to eq([
        DbSchema::Operations::RenameTable.new(old_name: :people, new_name: :users)
      ])

      expect(join_names.name).to eq('Join first_name & last_name into name')
      expect(join_names.conditions[:apply].count).to eq(2)
      expect(join_names.conditions[:skip].count).to eq(1)
      expect(join_names.changes).to eq([
        DbSchema::Operations::AlterTable.new(
          :users,
          [
            DbSchema::Operations::CreateColumn.new(
              DbSchema::Definitions::Field::Varchar.new(:name)
            ),
            DbSchema::Operations::DisallowNull.new(:name),
            DbSchema::Operations::DropColumn.new(:first_name),
            DbSchema::Operations::DropColumn.new(:last_name)
          ]
        )
      ])
    end
  end
end
