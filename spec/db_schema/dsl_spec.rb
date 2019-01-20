RSpec.describe DbSchema::DSL do
  let(:schema_block) do
    -> (db) do
      db.enum :user_status, %i(user moderator admin)

      db.extension :hstore

      db.table :users do |t|
        t.serial      :id, null: false, default: 1, primary_key: true
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
        t.serial  :id,   primary_key: true
        t.varchar :name, null: false
      end

      db.table :posts do |t|
        t.serial :id
        t.varchar :title
        t.integer :user_id
        t.varchar :user_name
        t.integer :col1
        t.integer :col2
        t.integer :col3
        t.integer :col4

        t.primary_key :id, name: :my_pkey

        t.index :user_id
        t.index col1: :asc, col2: :desc, col3: :asc_nulls_first, col4: :desc_nulls_last
        t.index 'col2 - col1' => :desc, 'col3 + col4' => :asc_nulls_first

        t.foreign_key :user_id, references: :users, on_delete: :set_null, deferrable: true
        t.foreign_key :user_name, references: [:users, :name], name: :user_name_fkey, on_update: :cascade
      end

      db.table :points do |t|
        t.decimal :lat
        t.decimal :lng

        t.primary_key :lat, :lng
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
            t.execute "UPDATE users SET name = first_name || ' ' || last_name"
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
    let(:schema) { subject.schema }

    it 'returns fields' do
      users  = schema.table(:users)
      posts  = schema.table(:posts)
      cities = schema.table(:cities)

      expect(users.fields.count).to eq(10)
      expect(posts.fields.count).to eq(8)
      expect(cities.fields.count).to eq(2)

      expect(users.field(:id).type).to eq(:serial)
      expect(users.field(:id)).to be_null
      expect(users.field(:id).default).to be_nil

      expect(users.field(:name).type).to eq(:varchar)
      expect(users.field(:name)).not_to be_null

      expect(users.field(:email).type).to eq(:varchar)
      expect(users.field(:email).default).to eq('mail@example.com')

      expect(users.field(:sex).type).to eq(:char)
      expect(users.field(:sex).options[:length]).to eq(1)

      expect(users.field(:city_id).type).to eq(:integer)

      expect(users.field(:strings)).to be_array
      expect(users.field(:strings).options[:element_type]).to eq(:varchar)

      expect(users.field(:status)).to be_custom
      expect(users.field(:status).type).to eq(:user_status)
      expect(users.field(:status)).not_to be_null

      expect(users.field(:previous_statuses)).to be_array
      expect(users.field(:previous_statuses).options[:element_type]).to eq(:user_status)

      expect(users.field(:mood)).to be_custom
      expect(users.field(:mood).type).to eq(:happiness)

      expect(users.field(:created_at).type).to eq(:timestamptz)
      expect(users.field(:created_at).default).to eq(:'now()')
    end

    it 'returns indexes' do
      users  = schema.table(:users)
      posts  = schema.table(:posts)
      points = schema.table(:points)

      expect(users.indexes.count).to eq(7)
      expect(posts.indexes.count).to eq(4)
      expect(points.indexes.count).to eq(1)

      expect(users.index(:users_pkey).columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:id)
      ])
      expect(users.index(:users_pkey)).to be_primary

      expect(users.index(:users_name_index).columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:name)
      ])
      expect(users.index(:users_name_index)).to be_unique

      expect(users.index(:users_sex_index).columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:sex)
      ])
      expect(users.index(:users_sex_index)).not_to be_unique

      expect(users.index(:users_mood_index).columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:mood)
      ])
      expect(users.index(:users_mood_index)).not_to be_unique

      expect(users.index(:users_email_idx).columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:email)
      ])
      expect(users.index(:users_email_idx)).to be_unique
      expect(users.index(:users_email_idx)).to be_btree
      expect(users.index(:users_email_idx).condition).to eq('email IS NOT NULL')

      expect(users.index(:users_strings_index).type).to eq(:gin)

      expect(users.index(:users_lower_email_index).columns).to eq([
        DbSchema::Definitions::Index::Expression.new('lower(email)')
      ])

      expect(posts.index(:my_pkey).columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:id)
      ])
      expect(posts.index(:my_pkey)).to be_primary

      expect(posts.index(:posts_user_id_index).columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:user_id)
      ])
      expect(posts.index(:posts_user_id_index)).not_to be_unique

      expect(posts.index(:posts_col1_col2_col3_col4_index).columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:col1),
        DbSchema::Definitions::Index::TableField.new(:col2, order: :desc),
        DbSchema::Definitions::Index::TableField.new(:col3, nulls: :first),
        DbSchema::Definitions::Index::TableField.new(:col4, order: :desc, nulls: :last)
      ])

      expect(posts.index(:posts_col2_col1_col3_col4_index).columns).to eq([
        DbSchema::Definitions::Index::Expression.new('col2 - col1', order: :desc),
        DbSchema::Definitions::Index::Expression.new('col3 + col4', nulls: :first)
      ])

      expect(points.index(:points_pkey).columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:lat),
        DbSchema::Definitions::Index::TableField.new(:lng)
      ])
      expect(points.index(:points_pkey)).to be_primary
    end

    it 'returns check constraints' do
      users = schema.table(:users)
      expect(users.checks.count).to eq(2)

      expect(users.check(:users_name_check).condition).to eq('char_length(name) > 0')
      expect(users.check(:valid_sex).condition).to eq("sex IN ('M', 'F')")
    end

    it 'returns foreign keys' do
      users = schema.table(:users)
      posts = schema.table(:posts)

      expect(users.foreign_keys.count).to eq(1)
      expect(users.foreign_key(:users_city_id_fkey).fields).to eq([:city_id])
      expect(users.foreign_key(:users_city_id_fkey).table).to eq(:cities)
      expect(users.foreign_key(:users_city_id_fkey).references_primary_key?).to eq(true)

      expect(posts.foreign_keys.count).to eq(2)
      expect(posts.foreign_key(:posts_user_id_fkey).fields).to eq([:user_id])
      expect(posts.foreign_key(:posts_user_id_fkey).table).to eq(:users)
      expect(posts.foreign_key(:posts_user_id_fkey).references_primary_key?).to eq(true)
      expect(posts.foreign_key(:posts_user_id_fkey).on_delete).to eq(:set_null)
      expect(posts.foreign_key(:posts_user_id_fkey).on_update).to eq(:no_action)
      expect(posts.foreign_key(:posts_user_id_fkey)).to be_deferrable
      expect(posts.foreign_key(:user_name_fkey).fields).to eq([:user_name])
      expect(posts.foreign_key(:user_name_fkey).table).to eq(:users)
      expect(posts.foreign_key(:user_name_fkey).keys).to eq([:name])
      expect(posts.foreign_key(:user_name_fkey).on_delete).to eq(:no_action)
      expect(posts.foreign_key(:user_name_fkey).on_update).to eq(:cascade)
      expect(posts.foreign_key(:user_name_fkey)).not_to be_deferrable
    end

    it 'returns enum types' do
      expect(schema.enums.count).to eq(2)

      expect(schema.enum(:happiness).values).to eq(%i(sad ok good happy))
      expect(schema.enum(:user_status).values).to eq(%i(user moderator admin))
    end

    it 'returns extensions' do
      expect(schema.extensions.count).to eq(1)
      expect(schema).to have_extension(:hstore)
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
      expect(rename_people_to_users.body).to be_a(Proc)

      expect(join_names.name).to eq('Join first_name & last_name into name')
      expect(join_names.conditions[:apply].count).to eq(2)
      expect(join_names.conditions[:skip].count).to eq(1)
      expect(join_names.body).to be_a(Proc)
    end
  end
end
