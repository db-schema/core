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

    context 'with AlterTable' do
      let(:changes) do
        [
          DbSchema::Changes::AlterTable.new(
            name:    :people,
            fields:  field_changes,
            indices: index_changes
          )
        ]
      end

      let(:field_changes) { [] }
      let(:index_changes) { [] }

      context 'with CreateColumn & DropColumn' do
        let(:field_changes) do
          [
            DbSchema::Changes::CreateColumn.new(name: :first_name, type: :varchar),
            DbSchema::Changes::CreateColumn.new(name: :last_name, type: :varchar),
            DbSchema::Changes::CreateColumn.new(name: :age, type: :integer, null: false),
            DbSchema::Changes::DropColumn.new(name: :name)
          ]
        end

        it 'applies all the changes' do
          subject.run!

          id, first_name, last_name, age = DbSchema.connection.schema(:people)
          expect(id.first).to eq(:id)
          expect(first_name.first).to eq(:first_name)
          expect(first_name.last[:db_type]).to eq('character varying(255)')
          expect(last_name.first).to eq(:last_name)
          expect(last_name.last[:db_type]).to eq('character varying(255)')
          expect(age.first).to eq(:age)
          expect(age.last[:db_type]).to eq('integer')
          expect(age.last[:allow_null]).to eq(false)
        end
      end

      context 'with RenameColumn' do
        let(:field_changes) do
          [
            DbSchema::Changes::RenameColumn.new(old_name: :name, new_name: :full_name)
          ]
        end

        it 'applies all the changes' do
          subject.run!

          id, full_name = DbSchema.connection.schema(:people)
          expect(id.first).to eq(:id)
          expect(full_name.first).to eq(:full_name)
          expect(full_name.last[:db_type]).to eq('character varying(255)')
        end
      end

      context 'with AlterColumnType' do
        let(:field_changes) do
          [
            DbSchema::Changes::AlterColumnType.new(name: :name, new_type: :text)
          ]
        end

        it 'applies all the changes' do
          subject.run!

          id, name = DbSchema.connection.schema(:people)
          expect(name.last[:db_type]).to eq('text')
        end
      end

      context 'with CreatePrimaryKey & DropPrimaryKey' do
        let(:field_changes) do
          [
            DbSchema::Changes::DropPrimaryKey.new(name: :id),
            DbSchema::Changes::CreatePrimaryKey.new(name: :name)
          ]
        end

        it 'applies all the changes' do
          subject.run!

          id, name = DbSchema.connection.schema(:people)
          expect(id.last[:primary_key]).to eq(false)
          expect(name.last[:primary_key]).to eq(true)
        end
      end
    end
  end

  after(:each) do
    DbSchema.connection.tables.each do |table_name|
      DbSchema.connection.drop_table(table_name)
    end
  end
end
