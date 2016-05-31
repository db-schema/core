require 'spec_helper'

RSpec.describe DbSchema do
  let(:database) { DbSchema.connection }

  describe '.describe' do
    before(:each) do
      database.create_table :users do
        column :id,    :Integer, primary_key: true
        column :name,  :Varchar, null: false
        column :email, :Varchar, length: 100

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

          t.index [:first_name, :last_name], name: :users_name_index
          t.index [:email], name: :users_email_index, unique: true
        end

        db.table :posts do |t|
          t.integer :id, primary_key: true
          t.varchar :title, null: false
          t.text :text
          t.integer :user_id, null: false

          t.index [:user_id], name: :posts_user_id_index
        end

        db.table :cities do |t|
          t.integer :id, primary_key: true
          t.varchar :name, null: false
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

      users_indices = database.indexes(:users)
      name_index, email_index = users_indices.values_at(:users_name_index, :users_email_index)
      expect(name_index[:columns]).to eq([:first_name, :last_name])
      expect(name_index[:unique]).to eq(false)
      expect(email_index[:columns]).to eq([:email])
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

      user_id_index = database.indexes(:posts)[:posts_user_id_index]
      expect(user_id_index[:columns]).to eq([:user_id])
      expect(user_id_index[:unique]).to eq(false)

      id, name = database.schema(:cities)
      expect(id.first).to eq(:id)
      expect(id.last[:db_type]).to eq('integer')
      expect(id.last[:primary_key]).to eq(true)
      expect(name.first).to eq(:name)
      expect(name.last[:db_type]).to eq('character varying')
      expect(name.last[:allow_null]).to eq(false)

      expect(database.indexes(:cities)).to be_empty
    end

    after(:each) do
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

  describe '.configuration' do
    context 'without a prior call to .configure' do
      it 'raises a RuntimeError' do
        expect {
          subject.configuration
        }.to raise_error(RuntimeError, /DbSchema\.configure/)
      end
    end
  end
end
