require 'spec_helper'

RSpec.describe DbSchema::Reader do
  describe '.read_schema' do
    context 'on an empty database' do
      it 'returns an empty array' do
        expect(subject.read_schema).to eq([])
      end
    end

    context 'on a database with tables' do
      before(:each) do
        DbSchema.connection.create_table :users do
          column :id, :serial, primary_key: true
          column :name, :varchar, null: false
          column :email, :varchar, default: 'mail@example.com'

          index :email, unique: true
        end

        DbSchema.connection.create_table :posts do
          column :id, :integer, primary_key: true
          column :title, :varchar
          column :user_id, :integer, null: false

          index :user_id
        end
      end

      it 'returns the database schema' do
        users, posts = subject.read_schema
        expect(users.name).to eq(:users)
        expect(posts.name).to eq(:posts)

        id, name, email = users.fields
        expect(id.name).to eq(:id)
        expect(id.type).to eq(:integer)
        expect(id).to be_primary_key
        expect(id).to have_sequence
        expect(name.name).to eq(:name)
        expect(name.type).to eq(:varchar)
        expect(name).not_to be_null
        expect(name).not_to have_sequence
        expect(email.name).to eq(:email)
        expect(email.type).to eq(:varchar)
        expect(email).to be_null
        expect(email.default).to eq('mail@example.com')
        expect(email).not_to have_sequence

        id, title, user_id = posts.fields
        expect(id.name).to eq(:id)
        expect(id.type).to eq(:integer)
        expect(id).to be_primary_key
        expect(id).not_to have_sequence
        expect(title.name).to eq(:title)
        expect(title.type).to eq(:varchar)
        expect(title).to be_null
        expect(user_id.name).to eq(:user_id)
        expect(user_id.type).to eq(:integer)
        expect(user_id).not_to be_null

        expect(users.indices.count).to eq(1)
        email_index = users.indices.first
        expect(email_index.fields).to eq([:email])
        expect(email_index).to be_unique

        expect(posts.indices.count).to eq(1)
        user_id_index = posts.indices.first
        expect(user_id_index.fields).to eq([:user_id])
        expect(user_id_index).not_to be_unique
      end

      after(:each) do
        DbSchema.connection.tables.each do |table_name|
          DbSchema.connection.drop_table(table_name)
        end
      end
    end
  end
end
