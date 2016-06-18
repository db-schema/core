require 'spec_helper'

RSpec.describe DbSchema::Runner do
  let(:database) { DbSchema.connection }

  before(:each) do
    database.create_table :people do
      primary_key :id
      column :name,         :Varchar
      column :address,      :Varchar, null: false, size: 150
      column :country_name, :Varchar
      column :created_at,   :Timestamptz

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
      DbSchema::Definitions::Field::Integer.new(:country_id, null: false),
      DbSchema::Definitions::Field::Timestamp.new(:created_at, null: false),
      DbSchema::Definitions::Field::Interval.new(:period, fields: :second, precision: 5),
      DbSchema::Definitions::Field::Bit.new(:some_bit),
      DbSchema::Definitions::Field::Bit.new(:some_bits, length: 7),
      DbSchema::Definitions::Field::Varbit.new(:some_varbit, length: 250),
      DbSchema::Definitions::Field::Array.new(:names, of: :varchar)
    ]
  end

  let(:users_indices) do
    [
      DbSchema::Definitions::Index.new(
        name:   :index_users_on_name,
        fields: [DbSchema::Definitions::Index::Field.new(:name)]
      ),
      DbSchema::Definitions::Index.new(
        name:      :index_users_on_email,
        fields:    [DbSchema::Definitions::Index::Field.new(:email, order: :desc, nulls: :last)],
        unique:    true,
        condition: 'email IS NOT NULL'
      ),
      DbSchema::Definitions::Index.new(
        name:   :users_names_index,
        fields: [DbSchema::Definitions::Index::Field.new(:names)],
        type:   :gin
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
    before(:each) do
      pending 'Refactoring foreign keys in Changes'
    end

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

        users = DbSchema::Reader.read_schema.find { |table| table.name == :users }
        id, name, email, country_id, created_at, period, some_bit, some_bits, some_varbit, names = users.fields
        expect(id.name).to eq(:id)
        expect(id).to be_a(DbSchema::Definitions::Field::Integer)
        expect(id).to be_primary_key
        expect(name.name).to eq(:name)
        expect(name).to be_a(DbSchema::Definitions::Field::Varchar)
        expect(name.options[:length]).to eq(50)
        expect(name).not_to be_null
        expect(email.name).to eq(:email)
        expect(email).to be_a(DbSchema::Definitions::Field::Varchar)
        expect(email.default).to eq('mail@example.com')
        expect(created_at.name).to eq(:created_at)
        expect(created_at).to be_a(DbSchema::Definitions::Field::Timestamp)
        expect(created_at).not_to be_null
        expect(created_at.options[:precision]).to eq(6)
        expect(period.name).to eq(:period)
        expect(period).to be_a(DbSchema::Definitions::Field::Interval)
        expect(period.options[:fields]).to eq(:second)
        expect(period.options[:precision]).to eq(5)
        expect(some_bit.name).to eq(:some_bit)
        expect(some_bit).to be_a(DbSchema::Definitions::Field::Bit)
        expect(some_bit.options[:length]).to eq(1)
        expect(some_bits.name).to eq(:some_bits)
        expect(some_bits).to be_a(DbSchema::Definitions::Field::Bit)
        expect(some_bits.options[:length]).to eq(7)
        expect(some_varbit.name).to eq(:some_varbit)
        expect(some_varbit).to be_a(DbSchema::Definitions::Field::Varbit)
        expect(some_varbit.options[:length]).to eq(250)
        expect(names.name).to eq(:names)
        expect(names).to be_a(DbSchema::Definitions::Field::Array)
        expect(names.options[:element_type]).to eq(:varchar)

        indices = DbSchema::Reader::Postgres.indices_data_for(:users)
        name_index  = indices.find { |index| index[:name] == :index_users_on_name }
        email_index = indices.find { |index| index[:name] == :index_users_on_email }
        names_index = indices.find { |index| index[:name] == :users_names_index }

        expect(name_index[:fields]).to eq([DbSchema::Definitions::Index::Field.new(:name)])
        expect(name_index[:unique]).to eq(false)
        expect(name_index[:type]).to eq(:btree)
        expect(email_index[:fields]).to eq([DbSchema::Definitions::Index::Field.new(:email, order: :desc, nulls: :last)])
        expect(email_index[:unique]).to eq(true)
        expect(email_index[:type]).to eq(:btree)
        expect(email_index[:condition]).to eq('email IS NOT NULL')
        expect(names_index[:fields]).to eq([DbSchema::Definitions::Index::Field.new(:names)])
        expect(names_index[:type]).to eq(:gin)

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
            DbSchema::Changes::CreateColumn.new(
              DbSchema::Definitions::Field::Integer.new(:uid, primary_key: true)
            ),
            DbSchema::Changes::CreateColumn.new(
              DbSchema::Definitions::Field::Timestamp.new(:updated_at, null: false, precision: 3)
            )
          ]
        end

        it 'applies all the changes' do
          subject.run!

          expect(database.primary_key(:people)).to eq('uid')
          expect(database.primary_key_sequence(:people)).to eq('"public"."people_uid_seq"')

          people = DbSchema::Reader.read_schema.find { |table| table.name == :people }
          address, country_name, created_at, first_name, last_name, age, uid, updated_at = people.fields
          expect(address.name).to eq(:address)
          expect(created_at.name).to eq(:created_at)
          expect(created_at).to be_a(DbSchema::Definitions::Field::Timestamptz)
          expect(created_at.options[:precision]).to eq(6)
          expect(first_name.name).to eq(:first_name)
          expect(first_name).to be_a(DbSchema::Definitions::Field::Varchar)
          expect(last_name.name).to eq(:last_name)
          expect(last_name).to be_a(DbSchema::Definitions::Field::Varchar)
          expect(last_name.options[:length]).to eq(30)
          expect(last_name).not_to be_null
          expect(age.name).to eq(:age)
          expect(age).to be_a(DbSchema::Definitions::Field::Integer)
          expect(age).not_to be_null
          expect(uid.name).to eq(:uid)
          expect(updated_at.name).to eq(:updated_at)
          expect(updated_at).to be_a(DbSchema::Definitions::Field::Timestamp)
          expect(updated_at.options[:precision]).to eq(3)
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
              DbSchema::Changes::AlterColumnType.new(:country_name, new_type: :varchar, length: 40),
              DbSchema::Changes::AlterColumnType.new(:created_at, new_type: :timestamp, precision: 2)
            ]
          end

          it 'applies all the changes' do
            subject.run!

            schema = DbSchema::Reader.read_schema
            people = schema.find { |table| table.name == :people }
            address, country_name, created_at = people.fields.last(3)

            expect(address).to be_a(DbSchema::Definitions::Field::Varchar)
            expect(address.options[:length]).to be_nil
            expect(country_name).to be_a(DbSchema::Definitions::Field::Varchar)
            expect(country_name.options[:length]).to eq(40)
            expect(created_at).to be_a(DbSchema::Definitions::Field::Timestamp)
            expect(created_at.options[:precision]).to eq(2)
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
              fields:    [DbSchema::Definitions::Index::Field.new(:name, order: :desc)],
              condition: 'name IS NOT NULL'
            ),
            DbSchema::Changes::DropIndex.new(:people_address_index),
            DbSchema::Changes::CreateIndex.new(
              name:   :people_created_at_index,
              fields: [DbSchema::Definitions::Index::Field.new(:created_at, nulls: :first)],
              type:   :brin
            )
          ]
        end

        it 'applies all the changes' do
          subject.run!

          indices = DbSchema::Reader::Postgres.indices_data_for(:people)
          expect(indices.count).to eq(2)
          name_index = indices.find { |index| index[:name] == :people_name_index }
          time_index = indices.find { |index| index[:name] == :people_created_at_index }

          expect(name_index[:fields]).to eq([DbSchema::Definitions::Index::Field.new(:name, order: :desc)])
          expect(name_index[:unique]).to eq(false)
          expect(name_index[:type]).to eq(:btree)
          expect(name_index[:condition]).to eq('name IS NOT NULL')
          # non-BTree indexes don't support index ordering
          expect(time_index[:fields]).to eq([DbSchema::Definitions::Index::Field.new(:created_at)])
          expect(time_index[:type]).to eq(:brin)
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

    it 'runs all operations in a transaction' do
      changes = [
        DbSchema::Changes::AlterTable.new(
          :people,
          fields: [
            DbSchema::Changes::CreateColumn.new(
              DbSchema::Definitions::Field::Varchar.new(:city_name)
            )
          ],
          indices: [
            DbSchema::Changes::CreateIndex.new(
              name:   :people_city_name_index,
              fields: [DbSchema::Definitions::Index::Field.new(:city_name)],
              type:   :gist
            )
          ],
          foreign_keys: []
        )
      ]

      expect {
        expect {
          described_class.new(changes).run!
        }.to raise_error(Sequel::DatabaseError)
      }.not_to change { DbSchema.connection.schema(:people).count }
    end
  end

  describe '.map_options' do
    context 'with a :numeric type' do
      let(:type) { :numeric }

      context 'with both :precision and :scale' do
        let(:options) do
          { null: false, precision: 10, scale: 2 }
        end

        it 'returns :size with both precision and scale' do
          expect(DbSchema::Runner.map_options(type, options)).to eq(null: false, size: [10, 2])
        end
      end

      context 'with just the :precision' do
        let(:options) do
          { null: false, precision: 7 }
        end

        it 'returns :size with precision' do
          expect(DbSchema::Runner.map_options(type, options)).to eq(null: false, size: 7)
        end
      end

      context 'without :precision' do
        let(:options) do
          { null: false, scale: 5 }
        end

        it 'does not return :size' do
          expect(DbSchema::Runner.map_options(type, options)).to eq(null: false)
        end
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
