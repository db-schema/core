require 'spec_helper'

RSpec.describe DbSchema do
  let(:database) { DbSchema.connection }

  describe '.describe' do
    before(:each) do
      subject.configure(database: 'db_schema_test', log_changes: false)

      database.create_table :users do
        column :id,    :Integer, primary_key: true
        column :name,  :Varchar, null: false
        column :email, :Varchar, size: 100

        index :email
      end

      database.create_table :posts do
        column :id,    :Integer, primary_key: true
        column :title, :Varchar
        column :text,  :Varchar
      end
    end

    it 'applies the schema to the database' do
      subject.describe do |db|
        db.table :users do |t|
          t.integer :id, primary_key: true
          t.varchar :first_name, null: false, length: 30
          t.varchar :last_name,  null: false, length: 30
          t.varchar :email,      null: false

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

        db.table :cities do |t|
          t.integer :id, primary_key: true
          t.varchar :name, null: false
          t.numeric :lat, precision: 6, scale: 3
          t.decimal :lng, precision: 6, scale: 3
        end
      end

      expect(database.tables).to include(:users)
      expect(database.tables).to include(:posts)
      expect(database.tables).to include(:cities)

      id, email, first_name, last_name = database.schema(:users)
      expect(id.first).to eq(:id)
      expect(email.first).to eq(:email)
      expect(email.last[:db_type]).to eq('character varying')
      expect(email.last[:allow_null]).to eq(false)
      expect(first_name.first).to eq(:first_name)
      expect(first_name.last[:db_type]).to eq('character varying(30)')
      expect(first_name.last[:allow_null]).to eq(false)
      expect(last_name.first).to eq(:last_name)
      expect(last_name.last[:db_type]).to eq('character varying(30)')
      expect(last_name.last[:allow_null]).to eq(false)

      users_indices = DbSchema::Reader::Postgres.indices_data_for(:users)
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

      id, name, lat, lng = database.schema(:cities)
      expect(id.first).to eq(:id)
      expect(id.last[:db_type]).to eq('integer')
      expect(id.last[:primary_key]).to eq(true)
      expect(name.first).to eq(:name)
      expect(name.last[:db_type]).to eq('character varying')
      expect(name.last[:allow_null]).to eq(false)
      expect(lat.first).to eq(:lat)
      expect(lat.last[:db_type]).to eq('numeric(6,3)')
      expect(lng.first).to eq(:lng)
      expect(lng.last[:db_type]).to eq('numeric(6,3)')

      expect(database.indexes(:cities)).to be_empty
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
        DbSchema.configure(database: 'db_schema_test', log_changes: false, dry_run: true)
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
        }.not_to change { DbSchema::Reader.read_schema }
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
          DbSchema.configure(database: 'db_schema_test', log_changes: false, post_check: false)
        end

        it 'ignores the mismatch' do
          expect {
            apply_schema
          }.not_to raise_error
        end
      end
    end

    after(:each) do
      database.tables.each do |table_name|
        database.foreign_key_list(table_name).each do |foreign_key|
          database.alter_table(table_name) do
            drop_foreign_key([], name: foreign_key[:name])
          end
        end
      end

      database.tables.each do |table_name|
        database.drop_table(table_name)
      end
    end
  end

  describe '.configure' do
    it 'stores the connection parameters in configuration object' do
      subject.configure(
        host:     'localhost',
        database: 'db_schema_test',
        user:     '7even',
        password: 'secret'
      )

      expect(subject.configuration.host).to eq('localhost')
      expect(subject.configuration.database).to eq('db_schema_test')
      expect(subject.configuration.user).to eq('7even')
      expect(subject.configuration.password).to eq('secret')
    end

    after(:each) do
      subject.reset!
    end
  end

  describe '.configure_from_yaml' do
    let(:path) { Pathname.new('../support/database.yml').expand_path(__FILE__) }

    it 'configures the connection from a YAML file' do
      subject.configure_from_yaml(path, :development)

      expect(subject.configuration.adapter).to eq('postgres')
      expect(subject.configuration.host).to eq('localhost')
      expect(subject.configuration.port).to eq(5432)
      expect(subject.configuration.database).to eq('db_schema_dev')
      expect(subject.configuration.user).to eq('7even')
      expect(subject.configuration.password).to eq(nil)
    end

    context 'with extra options' do
      it 'passes them to configuration object' do
        subject.configure_from_yaml(path, :development, log_changes: true)

        expect(subject.configuration.database).to eq('db_schema_dev')
        expect(subject.configuration).to be_log_changes
      end
    end

    after(:each) do
      subject.reset!
    end
  end

  describe '.configuration' do
    context 'without a prior call to .configure' do
      before(:each) do
        subject.reset!
      end

      it 'raises a RuntimeError' do
        expect {
          subject.configuration
        }.to raise_error(RuntimeError, /DbSchema\.configure/)
      end
    end
  end
end
