require 'spec_helper'

RSpec.describe DbSchema do
  let(:database) do
    Sequel.connect(adapter: 'postgres', database: 'db_schema_test').tap do |db|
      db.extension :pg_enum
      db.extension :pg_array
    end
  end

  describe '.describe' do
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
          t.integer :id, primary_key: true
          t.varchar :title, null: false
          t.text    :text
          t.integer :user_id, null: false

          t.index :user_id, name: :posts_author_index
          t.foreign_key :user_id, references: :users
        end

        db.table :countries do |t|
          t.primary_key :id
          t.varchar :name, null: false
        end

        db.table :cities do |t|
          t.integer :id, primary_key: true
          t.varchar :name, null: false
          t.integer :country_id, references: :countries
          t.numeric :lat, precision: 6, scale: 3
          t.decimal :lng, precision: 6, scale: 3
        end
      end

      expect(database.tables).to include(:users)
      expect(database.tables).to include(:posts)
      expect(database.tables).to include(:cities)

      id, email, happiness, first_name, last_name = database.schema(:users)
      expect(id.first).to eq(:id)
      expect(email.first).to eq(:email)
      expect(email.last[:db_type]).to eq('character varying')
      expect(email.last[:allow_null]).to eq(false)
      expect(happiness.first).to eq(:happiness)
      expect(happiness.last[:default]).to eq("'happy'::happiness")
      expect(first_name.first).to eq(:first_name)
      expect(first_name.last[:db_type]).to eq('character varying(30)')
      expect(first_name.last[:allow_null]).to eq(false)
      expect(last_name.first).to eq(:last_name)
      expect(last_name.last[:db_type]).to eq('character varying(30)')
      expect(last_name.last[:allow_null]).to eq(false)

      users_indices = DbSchema::Reader::Postgres.indices_data_for(:users, database)
      name_index  = users_indices.find { |index| index[:name] == :users_name_index }
      email_index = users_indices.find { |index| index[:name] == :users_email_index }

      expect(name_index[:columns]).to eq([
        DbSchema::Definitions::Index::TableField.new(:first_name),
        DbSchema::Definitions::Index::TableField.new(:last_name, order: :desc)
      ])
      expect(name_index[:unique]).to eq(false)
      expect(email_index[:columns]).to eq([DbSchema::Definitions::Index::Expression.new('lower(email::text)')])
      expect(email_index[:unique]).to eq(true)

      id, title, text, user_id = database.schema(:posts)
      expect(id.first).to eq(:id)
      expect(title.first).to eq(:title)
      expect(title.last[:db_type]).to eq('character varying')
      expect(title.last[:allow_null]).to eq(false)
      expect(text.first).to eq(:text)
      expect(text.last[:db_type]).to eq('text')
      expect(text.last[:allow_null]).to eq(true)
      expect(user_id.first).to eq(:user_id)
      expect(user_id.last[:db_type]).to eq('integer')
      expect(user_id.last[:allow_null]).to eq(false)

      user_id_index = database.indexes(:posts)[:posts_author_index]
      expect(user_id_index[:columns]).to eq([:user_id])
      expect(user_id_index[:unique]).to eq(false)

      user_id_fkey = database.foreign_key_list(:posts).first
      expect(user_id_fkey[:name]).to eq(:posts_user_id_fkey)
      expect(user_id_fkey[:columns]).to eq([:user_id])
      expect(user_id_fkey[:table]).to eq(:users)
      expect(user_id_fkey[:key]).to eq([:id])

      id, name, country_id, lat, lng = database.schema(:cities)
      expect(id.first).to eq(:id)
      expect(id.last[:db_type]).to eq('integer')
      expect(id.last[:primary_key]).to eq(true)
      expect(name.first).to eq(:name)
      expect(name.last[:db_type]).to eq('character varying')
      expect(name.last[:allow_null]).to eq(false)
      expect(country_id.first).to eq(:country_id)
      expect(country_id.last[:db_type]).to eq('integer')
      expect(lat.first).to eq(:lat)
      expect(lat.last[:db_type]).to eq('numeric(6,3)')
      expect(lng.first).to eq(:lng)
      expect(lng.last[:db_type]).to eq('numeric(6,3)')

      expect(database.indexes(:cities)).to be_empty

      country_id_fkey = database.foreign_key_list(:cities).first
      expect(country_id_fkey[:name]).to eq(:cities_country_id_fkey)
      expect(country_id_fkey[:columns]).to eq([:country_id])
      expect(country_id_fkey[:table]).to eq(:countries)
      expect(country_id_fkey[:key]).to eq([:id])

      enums = DbSchema::Reader.read_enums(database)
      expect(enums.count).to eq(1)

      happiness = enums.first
      expect(happiness.name).to eq(:happiness)
      expect(happiness.values).to eq(%i(happy ok unhappy))
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

        users = DbSchema::Reader.read_table(:users, database)
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

        expect(DbSchema::Reader.read_table(:users, database).fields.count).to eq(4)
        expect(DbSchema::Reader.read_table(:users, external_connection).fields.count).to eq(2)
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
        }.not_to change { DbSchema::Reader.read_schema(database) }
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
          }.not_to change { DbSchema::Reader.read_schema(database) }
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
      database.tables.each do |table_name|
        database.foreign_key_list(table_name).each do |foreign_key|
          database.alter_table(table_name) do
            drop_foreign_key([], name: foreign_key[:name])
          end
        end
      end

      DbSchema::Reader.read_enums(database).each do |enum|
        database.drop_enum(enum.name, cascade: true)
      end

      database.tables.each do |table_name|
        database.drop_table(table_name)
      end
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
          DbSchema::Configuration.new(
            host:     'localhost',
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
          DbSchema::Configuration.new(
            host:     'localhost',
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
            DbSchema::Configuration.new(
              host:     'localhost',
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
