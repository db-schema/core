require 'spec_helper'

RSpec.describe DbSchema::Runner do
  let(:database) { DbSchema.connection }

  before(:each) do
    database.create_table :people do
      primary_key :id
      column :name, :varchar
      column :address, :varchar, null: false

      index :address
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

  let(:users_indices) do
    [
      DbSchema::Definitions::Index.new(
        name: :index_users_on_name,
        fields: [:name]
      ),
      DbSchema::Definitions::Index.new(
        name: :index_users_on_email,
        fields: [:email],
        unique: true
      )
    ]
  end

  subject { DbSchema::Runner.new(changes) }

  describe '#run!' do
    context 'with CreateTable & DropTable' do
      let(:changes) do
        [
          DbSchema::Changes::CreateTable.new(name: :users, fields: users_fields, indices: users_indices),
          DbSchema::Changes::DropTable.new(name: :people)
        ]
      end

      it 'applies all the changes' do
        expect {
          subject.run!
        }.to change { DbSchema.connection.tables }.from([:people]).to([:users])

        expect(database.primary_key(:users)).to eq('id')
        expect(database.primary_key_sequence(:users)).to eq('"public"."users_id_seq"')

        id, name, email = database.schema(:users)
        expect(id.first).to eq(:id)
        expect(id.last[:db_type]).to eq('integer')
        expect(name.first).to eq(:name)
        expect(name.last[:db_type]).to eq('character varying(255)')
        expect(name.last[:allow_null]).to eq(false)
        expect(email.first).to eq(:email)
        expect(email.last[:db_type]).to eq('character varying(255)')
        expect(email.last[:default]).to eq("'mail@example.com'::character varying")

        indexes = database.indexes(:users)
        expect(indexes[:index_users_on_name][:columns]).to eq([:name])
        expect(indexes[:index_users_on_name][:unique]).to eq(false)
        expect(indexes[:index_users_on_email][:columns]).to eq([:email])
        expect(indexes[:index_users_on_email][:unique]).to eq(true)
      end
    end

    context 'with AlterTable' do
      let(:changes) do
        [
          DbSchema::Changes::AlterTable.new(
            name:         :people,
            fields:       field_changes,
            indices:      index_changes,
            foreign_keys: foreign_key_changes
          )
        ]
      end

      let(:field_changes) { [] }
      let(:index_changes) { [] }
      let(:foreign_key_changes) { [] }

      context 'with CreateColumn & DropColumn' do
        let(:field_changes) do
          [
            DbSchema::Changes::CreateColumn.new(name: :first_name, type: :varchar),
            DbSchema::Changes::CreateColumn.new(name: :last_name, type: :varchar),
            DbSchema::Changes::CreateColumn.new(name: :age, type: :integer, null: false),
            DbSchema::Changes::DropColumn.new(name: :name),
            DbSchema::Changes::DropColumn.new(name: :id),
            DbSchema::Changes::CreateColumn.new(name: :uid, type: :integer, primary_key: true)
          ]
        end

        it 'applies all the changes' do
          subject.run!

          expect(database.primary_key(:people)).to eq('uid')
          expect(database.primary_key_sequence(:people)).to eq('"public"."people_uid_seq"')

          address, first_name, last_name, age, uid = DbSchema.connection.schema(:people)
          expect(address.first).to eq(:address)
          expect(first_name.first).to eq(:first_name)
          expect(first_name.last[:db_type]).to eq('character varying(255)')
          expect(last_name.first).to eq(:last_name)
          expect(last_name.last[:db_type]).to eq('character varying(255)')
          expect(age.first).to eq(:age)
          expect(age.last[:db_type]).to eq('integer')
          expect(age.last[:allow_null]).to eq(false)
          expect(uid.first).to eq(:uid)
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

          id, full_name = database.schema(:people)
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

          id, name = database.schema(:people)
          expect(name.last[:db_type]).to eq('text')
        end
      end

      context 'with CreatePrimaryKey' do
        let(:field_changes) do
          [
            DbSchema::Changes::CreatePrimaryKey.new(name: :name)
          ]
        end

        it 'raises a NotImplementedError' do
          expect {
            subject.run!
          }.to raise_error(NotImplementedError)
        end
      end

      context 'with DropPrimaryKey' do
        let(:field_changes) do
          [
            DbSchema::Changes::DropPrimaryKey.new(name: :id)
          ]
        end

        it 'raises a NotImplementedError' do
          expect {
            subject.run!
          }.to raise_error(NotImplementedError)
        end
      end

      context 'with AllowNull & DisallowNull' do
        let(:field_changes) do
          [
            DbSchema::Changes::AllowNull.new(name: :address),
            DbSchema::Changes::DisallowNull.new(name: :name)
          ]
        end

        it 'applies all the changes' do
          subject.run!

          id, name, address = database.schema(:people)
          expect(name.last[:allow_null]).to eq(false)
          expect(address.last[:allow_null]).to eq(true)
        end
      end

      context 'with AlterColumnDefault' do
        let(:field_changes) do
          [
            DbSchema::Changes::AlterColumnDefault.new(name: :name, new_default: 'John Smith')
          ]
        end

        it 'applies all the changes' do
          subject.run!

          name = database.schema(:people)[1]
          expect(name.last[:default]).to eq("'John Smith'::character varying")
        end
      end

      context 'with CreateIndex & DropIndex' do
        let(:field_changes) do
          [
            DbSchema::Changes::CreateColumn.new(name: :email, type: :varchar)
          ]
        end

        let(:index_changes) do
          [
            DbSchema::Changes::CreateIndex.new(name: :people_name_index, fields: [:name]),
            DbSchema::Changes::DropIndex.new(name: :people_address_index, fields: [:address])
          ]
        end

        it 'applies all the changes' do
          subject.run!

          expect(database.indexes(:people).count).to eq(1)
          name_index = database.indexes(:people)[:people_name_index]
          expect(name_index[:columns]).to eq([:name])
          expect(name_index[:unique]).to eq(false)
        end
      end

      context 'with CreateForeignKey & DropForeignKey' do
        before(:each) do
          database.create_table :cities do
            primary_key :id
            column :name, :varchar, null: false

            index :name, unique: true
          end

          database.create_table :countries do
            primary_key :id
            column :name, :varchar, null: false

            index :name, unique: true
          end

          database.alter_table :people do
            add_column :city_name, :varchar
            add_column :city_id, :integer
            add_column :country_name, :varchar

            add_foreign_key [:city_name], :cities, key: :name
          end
        end

        let(:foreign_key_changes) do
          [
            DbSchema::Changes::DropForeignKey.new(name: :people_city_name_fkey),
            DbSchema::Changes::CreateForeignKey.new(
              name:      :people_city_id_fkey,
              fields:    [:city_id],
              table:     :cities,
              on_delete: :set_null
            ),
            DbSchema::Changes::CreateForeignKey.new(
              name:      :people_country_name_fkey,
              fields:    [:country_name],
              table:     :countries,
              keys:      [:name],
              on_update: :cascade
            )
          ]
        end

        it 'applies all the changes' do
          subject.run!

          expect(database.foreign_key_list(:people).count).to eq(2)
          city_id_fkey, country_name_fkey = database.foreign_key_list(:people)
          expect(city_id_fkey[:name]).to eq(:people_city_id_fkey)
          expect(city_id_fkey[:columns]).to eq([:city_id])
          expect(city_id_fkey[:table]).to eq(:cities)
          expect(city_id_fkey[:on_delete]).to eq(:set_null)
          expect(city_id_fkey[:on_update]).to eq(:no_action)
          expect(country_name_fkey[:name]).to eq(:people_country_name_fkey)
          expect(country_name_fkey[:columns]).to eq([:country_name])
          expect(country_name_fkey[:table]).to eq(:countries)
          expect(country_name_fkey[:key]).to eq([:name])
          expect(country_name_fkey[:on_delete]).to eq(:no_action)
          expect(country_name_fkey[:on_update]).to eq(:cascade)
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
end
