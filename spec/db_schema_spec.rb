RSpec.describe DbSchema do
  let(:database) do
    Sequel.connect(adapter: 'postgres', database: 'db_schema_test').tap do |db|
      db.extension :pg_enum
      db.extension :pg_array
    end
  end

  describe '.describe' do
    let(:schema) { DbSchema::Reader.reader_for(database).read_schema }

    before(:each) do
      subject.configure(database: 'db_schema_test', log_changes: false)

      database.create_enum :happiness, %i(good ok bad)

      database.create_table :users do
        primary_key :id

        column :name,      :Varchar, null: false
        column :email,     :Varchar, size: 100
        column :happiness, :happiness, default: 'ok'

        index :email
      end

      database.create_table :posts do
        primary_key :id

        column :title,   :Varchar
        column :text,    :Varchar
        column :user_id, :Integer, null: false

        foreign_key [:user_id], :users
      end
    end

    it 'applies the schema to the database' do
      subject.describe do |db|
        db.enum :happiness, %i(happy ok unhappy)

        db.table :users do |t|
          t.primary_key :id
          t.varchar :first_name,  null: false, length: 30
          t.varchar :last_name,   null: false, length: 30
          t.varchar :email,       null: false
          t.happiness :happiness, default: 'happy'

          t.index :first_name, last_name: :desc, name: :users_name_index
          t.index 'lower(email)', name: :users_email_index, unique: true
        end

        db.table :posts do |t|
          t.bigint  :id, primary_key: true
          t.varchar :title, null: false
          t.text    :text
          t.integer :user_id, null: false

          t.index :user_id, name: :posts_author_index
          t.foreign_key :user_id, references: :users
        end

        db.table :countries do |t|
          t.uuid :id, primary_key: true
          t.varchar :name, null: false
        end

        db.table :cities do |t|
          t.integer :id, primary_key: true
          t.varchar :name, null: false
          t.uuid    :country_id, references: :countries
          t.numeric :lat, precision: 6, scale: 3
          t.decimal :lng, precision: 6, scale: 3
        end
      end

      expect(schema).to have_table(:users)
      expect(schema).to have_table(:posts)
      expect(schema).to have_table(:cities)

      users = schema.table(:users)

      expect(users.field(:id)).to be_primary_key
      expect(users.field(:email).type).to eq(:varchar)
      expect(users.field(:email)).not_to be_null
      expect(users.field(:happiness).type).to eq(:happiness)
      expect(users.field(:happiness).default).to eq('happy')
      expect(users.field(:first_name).type).to eq(:varchar)
      expect(users.field(:first_name).options[:length]).to eq(30)
      expect(users.field(:first_name)).not_to be_null
      expect(users.field(:last_name).type).to eq(:varchar)
      expect(users.field(:last_name).options[:length]).to eq(30)
      expect(users.field(:last_name)).not_to be_null

      expect(users.index(:users_name_index).columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:first_name),
        DbSchema::Definitions::Index::TableField.new(:last_name, order: :desc)
      ])
      expect(users.index(:users_email_index).columns).to eq([
        DbSchema::Definitions::Index::Expression.new('lower(email::text)')
      ])
      expect(users.index(:users_email_index)).to be_unique

      posts = schema.table(:posts)
      expect(posts.field(:id)).to be_primary_key
      expect(posts.field(:id).type).to eq(:bigint)
      expect(posts.field(:title).type).to eq(:varchar)
      expect(posts.field(:title)).not_to be_null
      expect(posts.field(:text).type).to eq(:text)
      expect(posts.field(:text)).to be_null
      expect(posts.field(:user_id).type).to eq(:integer)
      expect(posts.field(:user_id)).not_to be_null

      expect(posts.index(:posts_author_index).columns).to eq([
        DbSchema::Definitions::Index::TableField.new(:user_id)
      ])
      expect(posts.index(:posts_author_index)).not_to be_unique

      expect(posts.foreign_key(:posts_user_id_fkey).fields).to eq([:user_id])
      expect(posts.foreign_key(:posts_user_id_fkey).table).to eq(:users)
      expect(posts.foreign_key(:posts_user_id_fkey).references_primary_key?).to eq(true)

      cities = schema.table(:cities)
      expect(cities.field(:id).type).to eq(:integer)
      expect(cities.field(:id)).to be_primary_key
      expect(cities.field(:name).type).to eq(:varchar)
      expect(cities.field(:name)).not_to be_null
      expect(cities.field(:country_id).type).to eq(:uuid)
      expect(cities.field(:lat).type).to eq(:numeric)
      expect(cities.field(:lat).options).to eq(precision: 6, scale: 3)
      expect(cities.field(:lng).type).to eq(:numeric)
      expect(cities.field(:lng).options).to eq(precision: 6, scale: 3)

      expect(cities.indexes).to be_empty

      expect(cities.foreign_key(:cities_country_id_fkey).fields).to eq([:country_id])
      expect(cities.foreign_key(:cities_country_id_fkey).table).to eq(:countries)
      expect(cities.foreign_key(:cities_country_id_fkey).references_primary_key?).to eq(true)

      expect(schema.enums.count).to eq(1)
      expect(schema.enum(:happiness).values).to eq(%i(happy ok unhappy))
    end

    context 'with conditional migrations' do
      it 'first runs the applicable migrations, then applies the schema' do
        database[:users].insert(name: 'John Smith', email: 'john@smith.com')

        subject.describe do |db|
          db.table :users do |t|
            t.primary_key :id
            t.varchar :first_name,  null: false, length: 30
            t.varchar :last_name,   null: false, length: 30
            t.varchar :email,       null: false

            t.index :first_name, last_name: :desc, name: :users_name_index
            t.index 'lower(email)', name: :users_email_index, unique: true
          end

          db.table :posts do |t|
            t.integer :id, primary_key: true
            t.varchar :title, null: false
            t.text    :text
            t.integer :user_id, null: false

            t.index :user_id, name: :posts_author_index
            t.foreign_key :user_id, references: :users
          end

          db.migrate 'Rename people to users' do |migration|
            migration.apply_if { |schema| schema.has_table?(:people) }

            migration.run do |migrator|
              migrator.rename_table :people, to: :users
            end
          end

          db.migrate 'Split name into first_name & last_name' do |migration|
            migration.apply_if do |schema|
              schema.has_table?(:users)
            end

            migration.skip_if do |schema|
              schema.table(:users).has_field?(:first_name)
            end

            migration.run do |migrator|
              migrator.alter_table :users do |t|
                t.add_column :first_name, :varchar, length: 30
                t.add_column :last_name,  :varchar, length: 30
              end

              migrator.execute <<-SQL
UPDATE users SET first_name = split_part(name, ' ', 1),
                 last_name = split_part(name, ' ', 2)
              SQL

              migrator.alter_table :users do |t|
                t.disallow_null :first_name
                t.disallow_null :last_name
                t.drop_column :name
              end
            end
          end
        end

        users = schema.table(:users)
        expect(users).not_to have_field(:name)
        expect(users.field(:first_name)).not_to be_null
        expect(users.field(:last_name)).not_to be_null

        user = database[:users].first
        expect(user[:first_name]).to eq('John')
        expect(user[:last_name]).to eq('Smith')
      end
    end

    context 'with an external connection' do
      let(:external_connection) do
        Sequel.connect(adapter: 'postgres', database: 'db_schema_test2')
      end

      before(:each) do
        subject.connection = external_connection
      end

      it 'uses it to setup the database' do
        subject.describe do |db|
          db.table :users do |t|
            t.primary_key :id
            t.varchar :name
          end
        end

        expect(DbSchema::Reader.reader_for(database).read_table(:users).fields.count).to eq(4)
        expect(DbSchema::Reader.reader_for(external_connection).read_table(:users).fields.count).to eq(2)
      end

      after(:each) do
        external_connection.tables.each do |table_name|
          external_connection.drop_table(table_name)
        end

        external_connection.disconnect
        subject.reset!
      end
    end

    context 'with an invalid schema' do
      it 'raises an InvalidSchemaError' do
        message = <<-MSG
Requested schema is invalid:

* Index "users_name_index" refers to a missing field "users.name"
* Foreign key "users_city_id_fkey" refers to primary key of table "cities" which does not have a primary key
* Foreign key "cities_country_id_fkey" refers to a missing table "countries"
* Foreign key "posts_user_name_fkey" refers to a missing field "users.name"
        MSG

        expect {
          subject.describe do |db|
            db.table :users do |t|
              t.primary_key :id
              t.varchar :email, null: false
              t.integer :city_id

              t.index :name, unique: true

              t.foreign_key :city_id, references: :cities
            end

            db.table :cities do |t|
              t.varchar :name
              t.integer :country_id

              t.foreign_key :country_id, references: :countries
            end

            db.table :posts do |t|
              t.primary_key :id
              t.varchar :title
              t.integer :user_name

              t.foreign_key :user_name, references: [:users, :name]
            end
          end
        }.to raise_error(DbSchema::InvalidSchemaError, message)
      end
    end

    context 'in dry run mode' do
      before(:each) do
        subject.configure(dry_run: true)
      end

      it 'does not make any changes' do
        expect {
          subject.describe do |db|
            db.table :users do |t|
              t.primary_key :id
              t.varchar :name, null: false
              t.varchar :email, length: 100

              t.index :email
            end
          end
        }.not_to change { DbSchema::Reader.reader_for(database).read_schema }
      end

      context 'with applicable migrations' do
        it 'rolls back both migrations and schema changes' do
          expect {
            subject.describe do |db|
              db.enum :happiness, %i(good ok bad)

              db.table :people do |t|
                t.primary_key :id
                t.varchar     :name, null: false
                t.varchar     :email, length: 100
                t.happiness   :happiness, default: 'ok'

                t.index :email, name: :users_email_index
              end

              db.table :posts do |t|
                t.primary_key :id
                t.varchar     :title
                t.varchar     :text
                t.integer     :user_id, null: false, references: :people
              end

              db.migrate 'Rename users to people' do |migration|
                migration.skip_if do |schema|
                  schema.has_table?(:people)
                end

                migration.run do |migrator|
                  migrator.rename_table :users, to: :people
                end
              end
            end
          }.not_to change { DbSchema::Reader.reader_for(database).read_schema }
        end
      end

      after(:each) do
        subject.configure(dry_run: false)
      end
    end

    context 'with differences left after run' do
      before(:each) do
        allow_any_instance_of(DbSchema::Runner).to receive(:run!)
      end

      def apply_schema
        subject.describe do |db|
          db.table :users do |t|
            t.primary_key :id
            t.varchar :name, null: false
            t.varchar :email, length: 100

            t.index :email
          end
        end
      end

      context 'with post_check enabled' do
        it 'raises a SchemaMismatch' do
          expect {
            apply_schema
          }.to raise_error(DbSchema::SchemaMismatch)
        end
      end

      context 'with post_check disabled' do
        before(:each) do
          subject.configure(post_check: false)
        end

        it 'ignores the mismatch' do
          expect {
            apply_schema
          }.not_to raise_error
        end

        after(:each) do
          subject.configure(post_check: true)
        end
      end
    end

    it 'closes the connection after making the changes' do
      expect {
        subject.describe do |db|
          db.table :users do |t|
            t.primary_key :id
            t.varchar :name, null: false
            t.varchar :email, length: 100

            t.index :email
          end
        end
      }.not_to change { Sequel::DATABASES.count }
    end

    after(:each) do
      clean!
    end
  end

  describe '.current_schema' do
    before(:each) do
      subject.configure(database: 'db_schema_test', log_changes: false)

      database.create_table :users do
        primary_key :id

        column :name,  :Varchar, null: false
        column :email, :Varchar
      end
    end

    def apply_schema
      subject.describe do |db|
        db.table :users do |t|
          t.primary_key :id
          t.varchar :name, null: false
          t.varchar :email
        end

        db.table :posts do |t|
          t.primary_key :id
          t.varchar :title
          t.text    :body
          t.integer :user_id, references: :users
        end
      end
    end

    context 'without dry_run' do
      before(:each) do
        apply_schema
      end

      it 'stores the applied schema' do
        schema = subject.current_schema

        expect(schema).to be_a(DbSchema::Definitions::Schema)
        expect(schema.tables.map(&:name)).to eq(%i(users posts))
      end

      after(:each) do
        database.drop_table(:posts)
        database.drop_table(:users)
      end
    end

    context 'with dry_run' do
      before(:each) do
        subject.configure(dry_run: true)
        apply_schema
      end

      it 'stores the initial schema' do
        schema = subject.current_schema

        expect(schema).to be_a(DbSchema::Definitions::Schema)
        expect(schema.tables.map(&:name)).to eq(%i(users))
      end

      after(:each) do
        database.drop_table(:users)
      end
    end

    after(:each) do
      subject.reset!
    end
  end

  describe '.configuration and .configure' do
    before(:each) do
      subject.reset!
    end

    context 'first call to .configuration' do
      it 'returns default configuration' do
        expect(subject.configuration).to eq(DbSchema::Configuration.new)
      end
    end

    context '.configuration after a .configure call' do
      it 'returns a configuration passed to .configure' do
        subject.configure(
          host:     'localhost',
          database: 'db_schema_test',
          user:     '7even',
          password: 'secret'
        )

        expect(subject.configuration).to eq(
          DbSchema::Configuration.new.merge(
            database: 'db_schema_test',
            user:     '7even',
            password: 'secret'
          )
        )
      end
    end

    context '.configuration after a .configure_from_yaml call' do
      let(:path) { Pathname.new('../support/database.yml').expand_path(__FILE__) }

      it 'returns a configuration set from a YAML file' do
        subject.configure_from_yaml(path, :development)

        expect(subject.configuration).to eq(
          DbSchema::Configuration.new.merge(
            database: 'db_schema_dev',
            user:     '7even',
            password: nil
          )
        )
      end

      context 'with extra options to .configure_from_yaml' do
        it 'passes them to configuration object' do
          subject.configure_from_yaml(path, :development, dry_run: true)

          expect(subject.configuration).to eq(
            DbSchema::Configuration.new.merge(
              database: 'db_schema_dev',
              user:     '7even',
              password: nil,
              dry_run:  true
            )
          )
        end
      end
    end

    after(:each) do
      subject.reset!
    end
  end
end
