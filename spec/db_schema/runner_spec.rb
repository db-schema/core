require 'spec_helper'

RSpec.describe DbSchema::Runner do
  before(:each) do
    DbSchema.connection.create_table :people do
      column :id, :integer, primary_key: true
      column :name, :varchar
    end
  end

  let(:users_fields) do
    [
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
  end

  subject { DbSchema::Runner.new(changes) }

  describe '#run!' do
    context 'with CreateTable & DropTable' do
      let(:changes) do
        [
          DbSchema::Changes::CreateTable.new(name: :users, fields: users_fields),
          DbSchema::Changes::DropTable.new(name: :people)
        ]
      end

      it 'applies all the changes' do
        expect {
          subject.run!
        }.to change { DbSchema.connection.tables }.from([:people]).to([:users])

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
      end
    end
  end

  after(:each) do
    DbSchema.connection.tables.each do |table_name|
      DbSchema.connection.drop_table(table_name)
    end
  end
end
