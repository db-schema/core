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
          column :name, :varchar, null: false, unique: true
          column :email, :varchar, default: 'mail@example.com', size: 250

          index [:email, :name], unique: true, where: 'email IS NOT NULL'
        end

        DbSchema.connection.create_table :posts do
          column :id, :integer, primary_key: true
          column :title, :varchar
          column :user_id, :integer, null: false
          column :user_name, :varchar

          index :user_id

          foreign_key [:user_id], :users, on_delete: :set_null, deferrable: true
          foreign_key [:user_name], :users, key: [:name], name: :user_name_fkey, on_update: :cascade
        end
      end

      it 'returns the database schema' do
        users, posts = subject.read_schema
        expect(users.name).to eq(:users)
        expect(posts.name).to eq(:posts)

        id, name, email = users.fields
        expect(id).to be_a(DbSchema::Definitions::Field::Integer)
        expect(id.name).to eq(:id)
        expect(id).to be_primary_key
        expect(name).to be_a(DbSchema::Definitions::Field::Varchar)
        expect(name.name).to eq(:name)
        expect(name).not_to be_null
        expect(email).to be_a(DbSchema::Definitions::Field::Varchar)
        expect(email.name).to eq(:email)
        expect(email).to be_null
        expect(email.default).to eq('mail@example.com')
        expect(email.options[:length]).to eq(250)

        id, title, user_id = posts.fields
        expect(id).to be_a(DbSchema::Definitions::Field::Integer)
        expect(id.name).to eq(:id)
        expect(id).to be_primary_key
        expect(title).to be_a(DbSchema::Definitions::Field::Varchar)
        expect(title.name).to eq(:title)
        expect(title).to be_null
        expect(user_id).to be_a(DbSchema::Definitions::Field::Integer)
        expect(user_id.name).to eq(:user_id)
        expect(user_id).not_to be_null

        expect(users.indices.count).to eq(2)
        email_index = users.indices.first
        expect(email_index.fields).to eq([:email, :name])
        expect(email_index).to be_unique
        expect(email_index.condition).to eq('email IS NOT NULL')

        expect(posts.indices.count).to eq(1)
        user_id_index = posts.indices.first
        expect(user_id_index.fields).to eq([:user_id])
        expect(user_id_index).not_to be_unique

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
      end

      after(:each) do
        DbSchema.connection.drop_table(:posts)
        DbSchema.connection.drop_table(:users)
      end
    end
  end
end
