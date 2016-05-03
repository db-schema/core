require 'spec_helper'

RSpec.describe DbSchema::DSL do
  describe '#schema' do
    let(:schema_block) do
      -> (db) do
        db.table :users do |t|
          t.integer :id, primary_key: true
          t.varchar :name, null: false
          t.varchar :email, default: 'mail@example.com'
        end

        db.table :posts do |t|
          t.integer :id, primary_key: true
          t.varchar :title
          t.integer :user_id, null: false
        end
      end
    end

    subject { DbSchema::DSL.new(schema_block) }

    it 'returns an array of Definitions::Table instances' do
      users, posts = subject.schema

      expect(users.name).to eq(:users)
      expect(users.fields.count).to eq(3)
      expect(posts.name).to eq(:posts)
      expect(posts.fields.count).to eq(3)

      id, name, email = users.fields

      expect(id.name).to eq(:id)
      expect(id.type).to eq(:integer)
      expect(id).to be_primary_key

      expect(name.name).to eq(:name)
      expect(name.type).to eq(:varchar)
      expect(name).not_to be_null

      expect(email.name).to eq(:email)
      expect(email.type).to eq(:varchar)
      expect(email.default).to eq('mail@example.com')
    end
  end
end
