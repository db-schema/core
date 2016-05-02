require 'spec_helper'

RSpec.describe DbSchema::Runner do
  let(:tables) do
    [
      DbSchema::Definitions::Table.new(
        name: :users,
        fields: [
          DbSchema::Definitions::Field.new(
            name: :id,
            type: :integer,
            primary_key: true
          ),
          DbSchema::Definitions::Field.new(
            name: :name,
            type: :varchar,
            null: false
          ),
          DbSchema::Definitions::Field.new(
            name: :email,
            type: :varchar,
            default: 'mail@example.com'
          )
        ]
      ),
      DbSchema::Definitions::Table.new(
        name: :posts,
        fields: [
          DbSchema::Definitions::Field.new(
            name: :id,
            type: :integer,
            primary_key: :true
          ),
          DbSchema::Definitions::Field.new(
            name: :title,
            type: :varchar
          ),
          DbSchema::Definitions::Field.new(
            name: :user_id,
            type: :integer,
            null: false
          )
        ]
      )
    ]
  end

  subject { DbSchema::Runner.new(tables) }

  describe '#run' do
    it 'creates all the tables' do
      subject.run!

      expect(DbSchema.connection.tables).to eq([:users, :posts])

      id, name, email = DbSchema.connection.schema(:users)
      expect(id.first).to eq(:id)
      expect(id.last[:db_type]).to eq('integer')
      expect(id.last[:primary_key]).to eq(true)
      expect(name.first).to eq(:name)
      expect(name.last[:db_type]).to eq('character varying(255)')
      expect(name.last[:allow_null]).to eq(false)
      expect(email.first).to eq(:email)
      expect(email.last[:db_type]).to eq('character varying(255)')
      expect(email.last[:default]).to eq("'mail@example.com'::character varying")

      id, title, user_id = DbSchema.connection.schema(:posts)
      expect(id.first).to eq(:id)
      expect(id.last[:db_type]).to eq('integer')
      expect(id.last[:primary_key]).to eq(true)
      expect(title.first).to eq(:title)
      expect(title.last[:db_type]).to eq('character varying(255)')
      expect(user_id.first).to eq(:user_id)
      expect(user_id.last[:db_type]).to eq('integer')
      expect(user_id.last[:allow_null]).to eq(false)
    end
  end

  after(:each) do
    DbSchema.connection.tables.each do |table_name|
      DbSchema.connection.drop_table(table_name)
    end
  end
end
