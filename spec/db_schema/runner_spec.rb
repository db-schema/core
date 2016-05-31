require 'spec_helper'

RSpec.describe DbSchema::Runner do
  let(:database) { DbSchema.connection }

  before(:each) do
    database.create_table :people do
      primary_key :id
      column :name,         :Varchar
      column :address,      :Varchar, null: false, size: 150
      column :country_name, :Varchar

      index :address
    end

    database.create_table :countries do
      primary_key :id
      column :name, :varchar, null: false

      index :name, unique: true
    end
  end

  let(:users_fields) do
    [
      DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
      DbSchema::Definitions::Field::Varchar.new(:name, null: false, length: 50),
      DbSchema::Definitions::Field::Varchar.new(:email, default: 'mail@example.com'),
      DbSchema::Definitions::Field::Integer.new(:country_id, null: false)
    ]
  end

  let(:users_indices) do
    [
      DbSchema::Definitions::Index.new(
        name:   :index_users_on_name,
        fields: [:name]
      ),
      DbSchema::Definitions::Index.new(
        name:      :index_users_on_email,
        fields:    [:email],
        unique:    true,
        condition: 'email IS NOT NULL'
      )
    ]
  end

  let(:users_foreign_keys) do
    [
      DbSchema::Definitions::ForeignKey.new(
        name:      :users_country_id_fkey,
        fields:    [:country_id],
        table:     :countries,
        on_delete: :set_null
      )
    ]
  end

  subject { DbSchema::Runner.new(changes) }

  describe '#run!' do
    context 'with CreateTable & DropTable' do
      let(:changes) do
        [
          DbSchema::Changes::CreateTable.new(
            :users,
            fields:       users_fields,
            indices:      users_indices,
            foreign_keys: users_foreign_keys
          ),
          DbSchema::Changes::DropTable.new(:people)
        ]
      end

      it 'applies all the changes' do
        subject.run!

        expect(DbSchema.connection.tables).not_to include(:people)
        expect(DbSchema.connection.tables).to include(:users)

        expect(database.primary_key(:users)).to eq('id')
        expect(database.primary_key_sequence(:users)).to eq('"public"."users_id_seq"')

        id, name, email = database.schema(:users)
        expect(id.first).to eq(:id)
        expect(id.last[:db_type]).to eq('integer')
        expect(name.first).to eq(:name)
        expect(name.last[:db_type]).to eq('character varying(50)')
        expect(name.last[:allow_null]).to eq(false)
        expect(email.first).to eq(:email)
        expect(email.last[:db_type]).to eq('character varying')
        expect(email.last[:default]).to eq("'mail@example.com'::character varying")

        indices = DbSchema::Reader::Postgres.indices_data_for(:users)
        name_index  = indices.find { |index| index[:name] == :index_users_on_name }
        email_index = indices.find { |index| index[:name] == :index_users_on_email }
        expect(name_index[:fields]).to eq([:name])
        expect(name_index[:unique]).to eq(false)
        expect(email_index[:fields]).to eq([:email])
        expect(email_index[:unique]).to eq(true)
        expect(email_index[:condition]).to eq('email IS NOT NULL')

        expect(database.foreign_key_list(:users).count).to eq(1)
        users_country_id_fkey = database.foreign_key_list(:users).first
        expect(users_country_id_fkey[:name]).to eq(:users_country_id_fkey)
        expect(users_country_id_fkey[:columns]).to eq([:country_id])
        expect(users_country_id_fkey[:table]).to eq(:countries)
        expect(users_country_id_fkey[:key]).to eq([:id])
        expect(users_country_id_fkey[:on_delete]).to eq(:set_null)
        expect(users_country_id_fkey[:on_update]).to eq(:no_action)
        expect(users_country_id_fkey[:deferrable]).to eq(false)
      end
    end

    context 'with AlterTable' do
      let(:changes) do
        [
          DbSchema::Changes::AlterTable.new(
            :people,
            fields:       field_changes,
            indices:      index_changes,
            foreign_keys: foreign_key_changes
          )
        ]
      end

      let(:field_changes) { [] }
      let(:index_changes) { [] }
      let(:foreign_key_changes) { [] }

      context 'containing CreateColumn & DropColumn' do
        let(:field_changes) do
          [
            DbSchema::Changes::CreateColumn.new(DbSchema::Definitions::Field::Varchar.new(:first_name)),
            DbSchema::Changes::CreateColumn.new(
              DbSchema::Definitions::Field::Varchar.new(:last_name, length: 30, null: false)
            ),
            DbSchema::Changes::CreateColumn.new(DbSchema::Definitions::Field::Integer.new(:age, null: false)),
            DbSchema::Changes::DropColumn.new(:name),
            DbSchema::Changes::DropColumn.new(:id),
            DbSchema::Changes::CreateColumn.new(DbSchema::Definitions::Field::Integer.new(:uid, primary_key: true))
          ]
        end

        it 'applies all the changes' do
          subject.run!

          expect(database.primary_key(:people)).to eq('uid')
          expect(database.primary_key_sequence(:people)).to eq('"public"."people_uid_seq"')

          address, country_name, first_name, last_name, age, uid = DbSchema.connection.schema(:people)
          expect(address.first).to eq(:address)
          expect(first_name.first).to eq(:first_name)
          expect(first_name.last[:db_type]).to eq('character varying')
          expect(last_name.first).to eq(:last_name)
          expect(last_name.last[:db_type]).to eq('character varying(30)')
          expect(last_name.last[:allow_null]).to eq(false)
          expect(age.first).to eq(:age)
          expect(age.last[:db_type]).to eq('integer')
          expect(age.last[:allow_null]).to eq(false)
          expect(uid.first).to eq(:uid)
        end
      end

      context 'containing RenameColumn' do
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
          expect(full_name.last[:db_type]).to eq('character varying')
        end
      end

      context 'containing AlterColumnType' do
        let(:field_changes) do
          [
            DbSchema::Changes::AlterColumnType.new(:name, new_type: :text)
          ]
        end

        it 'applies all the changes' do
          subject.run!

          id, name = database.schema(:people)
          expect(name.last[:db_type]).to eq('text')
        end

        context 'that changes field attributes' do
          let(:field_changes) do
            [
              DbSchema::Changes::AlterColumnType.new(:address, new_type: :varchar),
              DbSchema::Changes::AlterColumnType.new(:country_name, new_type: :varchar, length: 40)
            ]
          end

          it 'applies all the changes' do
            subject.run!

            schema = DbSchema::Reader.read_schema
            people = schema.find { |table| table.name == :people }
            address, country_name = people.fields.last(2)

            expect(address).to be_a(DbSchema::Definitions::Field::Varchar)
            expect(address.options[:length]).to be_nil
            expect(country_name).to be_a(DbSchema::Definitions::Field::Varchar)
            expect(country_name.options[:length]).to eq(40)
          end
        end
      end

      context 'containing CreatePrimaryKey' do
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

      context 'containing DropPrimaryKey' do
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

      context 'containing AllowNull & DisallowNull' do
        let(:field_changes) do
          [
            DbSchema::Changes::AllowNull.new(:address),
            DbSchema::Changes::DisallowNull.new(:name)
          ]
        end

        it 'applies all the changes' do
          subject.run!

          id, name, address = database.schema(:people)
          expect(name.last[:allow_null]).to eq(false)
          expect(address.last[:allow_null]).to eq(true)
        end
      end

      context 'containing AlterColumnDefault' do
        let(:field_changes) do
          [
            DbSchema::Changes::AlterColumnDefault.new(:name, new_default: 'John Smith')
          ]
        end

        it 'applies all the changes' do
          subject.run!

          name = database.schema(:people)[1]
          expect(name.last[:default]).to eq("'John Smith'::character varying")
        end
      end

      context 'containing CreateIndex & DropIndex' do
        let(:field_changes) do
          [
            DbSchema::Changes::CreateColumn.new(DbSchema::Definitions::Field::Varchar.new(:email))
          ]
        end

        let(:index_changes) do
          [
            DbSchema::Changes::CreateIndex.new(
              name:      :people_name_index,
              fields:    [:name],
              condition: 'name IS NOT NULL'
            ),
            DbSchema::Changes::DropIndex.new(:people_address_index)
          ]
        end

        it 'applies all the changes' do
          subject.run!

          indices = DbSchema::Reader::Postgres.indices_data_for(:people)
          expect(indices.count).to eq(1)
          name_index = indices.first
          expect(name_index[:fields]).to eq([:name])
          expect(name_index[:unique]).to eq(false)
          expect(name_index[:condition]).to eq('name IS NOT NULL')
        end
      end

      context 'containing CreateForeignKey & DropForeignKey' do
        before(:each) do
          database.create_table :cities do
            primary_key :id
            column :name, :varchar, null: false

            index :name, unique: true
          end

          database.alter_table :people do
            add_column :city_name, :varchar
            add_column :city_id, :integer

            add_foreign_key [:city_name], :cities, key: :name
          end
        end

        let(:foreign_key_changes) do
          [
            DbSchema::Changes::DropForeignKey.new(:people_city_name_fkey),
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
