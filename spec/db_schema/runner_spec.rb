require 'spec_helper'

RSpec.describe DbSchema::Runner do
  let(:database) { DbSchema.connection }

  let(:enums) do
    DbSchema::Utils.filter_by_class(
      DbSchema::Reader.read_schema,
      DbSchema::Definitions::Enum
    )
  end

  let(:extensions) do
    DbSchema::Utils.filter_by_class(
      DbSchema::Reader.read_schema,
      DbSchema::Definitions::Extension
    )
  end

  before(:each) do
    database.create_table :people do
      primary_key :id
      column :name,         :Varchar
      column :address,      :Varchar, null: false, size: 150
      column :country_name, :Varchar
      column :created_at,   :Timestamptz

      index :address

      constraint :address_length, Sequel.function(:char_length, :address) => 3..50
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
        name:    :index_users_on_name,
        columns: [DbSchema::Definitions::Index::Expression.new('lower(name)')]
      ),
      DbSchema::Definitions::Index.new(
        name:      :index_users_on_email,
        columns:   [DbSchema::Definitions::Index::TableField.new(:email, order: :desc, nulls: :last)],
        unique:    true,
        condition: 'email IS NOT NULL'
      ),
      DbSchema::Definitions::Index.new(
        name:    :users_names_index,
        columns: [DbSchema::Definitions::Index::TableField.new(:names)],
        type:    :gin
      )
    ]
  end

  let(:users_checks) {
    [
      DbSchema::Definitions::CheckConstraint.new(
        name:      :min_name_length,
        condition: 'character_length(name::text) > 4'
      )
    ]
  }

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
            fields:  users_fields,
            indices: users_indices,
            checks:  users_checks
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

        expect(name_index[:columns]).to eq([DbSchema::Definitions::Index::Expression.new('lower(name::text)')])
        expect(name_index[:unique]).to eq(false)
        expect(name_index[:type]).to eq(:btree)
        expect(email_index[:columns]).to eq([DbSchema::Definitions::Index::TableField.new(:email, order: :desc, nulls: :last)])
        expect(email_index[:unique]).to eq(true)
        expect(email_index[:type]).to eq(:btree)
        expect(email_index[:condition]).to eq('email IS NOT NULL')
        expect(names_index[:columns]).to eq([DbSchema::Definitions::Index::TableField.new(:names)])
        expect(names_index[:type]).to eq(:gin)

        expect(users.checks.count).to eq(1)
        name_length_check = users.checks.first
        expect(name_length_check.name).to eq(:min_name_length)
        expect(name_length_check.condition).to eq('character_length(name::text) > 4')
      end
    end

    context 'with AlterTable' do
      let(:changes) do
        [
          DbSchema::Changes::AlterTable.new(
            :people,
            fields:  field_changes,
            indices: index_changes,
            checks:  check_changes
          )
        ]
      end

      let(:field_changes) { [] }
      let(:index_changes) { [] }
      let(:check_changes) { [] }

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
              DbSchema::Definitions::Field::Timestamp.new(:updated_at, null: false)
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
              DbSchema::Changes::AlterColumnType.new(:created_at, new_type: :timestamp)
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
            DbSchema::Changes::CreateColumn.new(DbSchema::Definitions::Field::Array.new(:interests, of: :varchar))
          ]
        end

        let(:index_changes) do
          [
            DbSchema::Changes::CreateIndex.new(
              name:      :people_name_index,
              columns:   [DbSchema::Definitions::Index::Expression.new('lower(name)', order: :desc)],
              condition: 'name IS NOT NULL'
            ),
            DbSchema::Changes::DropIndex.new(:people_address_index),
            DbSchema::Changes::CreateIndex.new(
              name:    :people_interests_index,
              columns: [DbSchema::Definitions::Index::TableField.new(:interests)],
              type:    :gin
            )
          ]
        end

        it 'applies all the changes' do
          subject.run!

          indices = DbSchema::Reader::Postgres.indices_data_for(:people)
          expect(indices.count).to eq(2)
          name_index = indices.find { |index| index[:name] == :people_name_index }
          interests_index = indices.find { |index| index[:name] == :people_interests_index }

          expect(name_index[:columns]).to eq([
            DbSchema::Definitions::Index::Expression.new('lower(name::text)', order: :desc)
          ])
          expect(name_index[:unique]).to eq(false)
          expect(name_index[:type]).to eq(:btree)
          expect(name_index[:condition]).to eq('name IS NOT NULL')
          # non-BTree indexes don't support index ordering
          expect(interests_index[:columns]).to eq([
            DbSchema::Definitions::Index::TableField.new(:interests)
          ])
          expect(interests_index[:type]).to eq(:gin)
        end
      end

      context 'containing CreateCheckConstraint & DropCheckConstraint' do
        let(:check_changes) do
          [
            DbSchema::Changes::DropCheckConstraint.new(:address_length),
            DbSchema::Changes::CreateCheckConstraint.new(
              name:      :min_address_length,
              condition: 'character_length(address) >= 10'
            )
          ]
        end

        it 'applies all the changes' do
          subject.run!

          people = DbSchema::Reader.read_schema.find { |table| table.name == :people }
          expect(people.checks.count).to eq(1)
          address_check = people.checks.first
          expect(address_check.name).to eq(:min_address_length)
          expect(address_check.condition).to eq('character_length(address::text) >= 10')
        end
      end

      context "creating a field along with it's index" do
        let(:field_changes) do
          [
            DbSchema::Changes::CreateColumn.new(
              DbSchema::Definitions::Field::Varchar.new(:email)
            )
          ]
        end

        let(:index_changes) do
          [
            DbSchema::Changes::CreateIndex.new(
              name: :people_email_index,
              columns: [
                DbSchema::Definitions::Index::TableField.new(:email)
              ]
            )
          ]
        end

        it 'creates the field before creating the index' do
          subject.run!

          people = DbSchema::Reader.read_schema.find do |table|
            table.name == :people
          end

          expect(people.fields.map(&:name)).to include(:email)
          expect(people.indices).to include(
            DbSchema::Definitions::Index.new(
              name: :people_email_index,
              columns: [
                DbSchema::Definitions::Index::TableField.new(:email)
              ]
            )
          )
        end
      end

      context "dropping a field along with it's index" do
        let(:field_changes) do
          [
            DbSchema::Changes::DropColumn.new(:address)
          ]
        end

        let(:index_changes) do
          [
            DbSchema::Changes::DropIndex.new(:people_address_index)
          ]
        end

        it 'drops the index before dropping the field' do
          subject.run!

          people = DbSchema::Reader.read_schema.find do |table|
            table.name == :people
          end

          expect(people.fields.map(&:name)).not_to include(:address)
          expect(people.indices).to be_empty
        end
      end

      context "creating a field along with it's check constraint" do
        let(:field_changes) do
          [
            DbSchema::Changes::CreateColumn.new(
              DbSchema::Definitions::Field::Varchar.new(:email)
            )
          ]
        end

        let(:check_changes) do
          [
            DbSchema::Changes::CreateCheckConstraint.new(
              name:      :email_length,
              condition: 'char_length(email) > 5'
            )
          ]
        end

        it 'creates the field before creating the check' do
          subject.run!

          people = DbSchema::Reader.read_schema.find do |table|
            table.name == :people
          end

          expect(people.fields.map(&:name)).to include(:email)
          expect(people.checks).to include(
            DbSchema::Definitions::CheckConstraint.new(
              name:      :email_length,
              condition: 'char_length(email::text) > 5'
            )
          )
        end
      end

      context "dropping a field along with it's check constraint" do
        let(:field_changes) do
          [
            DbSchema::Changes::DropColumn.new(:address)
          ]
        end

        let(:check_changes) do
          [
            DbSchema::Changes::DropCheckConstraint.new(:address_length)
          ]
        end

        it 'drops the check before dropping the field' do
          subject.run!

          people = DbSchema::Reader.read_schema.find do |table|
            table.name == :people
          end

          expect(people.fields.map(&:name)).not_to include(:address)
          expect(people.checks).to be_empty
        end
      end
    end

    context 'with CreateForeignKey & DropForeignKey' do
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

      let(:changes) do
        [
          DbSchema::Changes::DropForeignKey.new(:people, :people_city_name_fkey),
          DbSchema::Changes::CreateForeignKey.new(
            :people,
            DbSchema::Definitions::ForeignKey.new(
              name:      :people_city_id_fkey,
              fields:    [:city_id],
              table:     :cities,
              on_delete: :set_null
            )
          ),
          DbSchema::Changes::CreateForeignKey.new(
            :people,
            DbSchema::Definitions::ForeignKey.new(
              name:      :people_country_name_fkey,
              fields:    [:country_name],
              table:     :countries,
              keys:      [:name],
              on_update: :cascade
            )
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

    context 'with conflicting operations on foreign keys and tables' do
      before(:each) do
        DbSchema.connection.create_table :old_table do
          primary_key :id
        end

        DbSchema.connection.create_table :other_old_table do
          primary_key :id
          foreign_key :old_id, :old_table
        end

        DbSchema.connection.create_table :referenced_table do
          primary_key :id
          integer :referenced_field, unique: true
        end

        DbSchema.connection.create_table :referring_table do
          integer :new_id
          foreign_key :old_id, :old_table
          foreign_key :referenced_field, :referenced_table, key: :referenced_field
        end
      end

      let(:changes) do
        [
          DbSchema::Changes::DropTable.new(:old_table),
          DbSchema::Changes::DropTable.new(:other_old_table),
          DbSchema::Changes::DropForeignKey.new(:other_old_table, :other_old_table_old_id_fkey),
          DbSchema::Changes::AlterTable.new(
            :referenced_table,
            fields: [
              DbSchema::Changes::DropColumn.new(:referenced_field)
            ],
            indices: [],
            checks:  []
          ),
          DbSchema::Changes::AlterTable.new(
            :referring_table,
            fields:  [],
            indices: [],
            checks:  []
          ),
          DbSchema::Changes::DropForeignKey.new(:referring_table, :referring_table_old_id_fkey),
          DbSchema::Changes::DropForeignKey.new(:referring_table, :referring_table_referenced_field_fkey),
          DbSchema::Changes::CreateForeignKey.new(
            :referring_table,
            DbSchema::Definitions::ForeignKey.new(
              name:   :referring_table_new_id_fkey,
              fields: [:new_id],
              table:  :new_table
            )
          ),
          DbSchema::Changes::CreateTable.new(
            :new_table,
            fields: [
              DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
              DbSchema::Definitions::Field::Integer.new(:other_new_id)
            ],
            indices: []
          ),
          DbSchema::Changes::CreateForeignKey.new(
            :new_table,
            DbSchema::Definitions::ForeignKey.new(
              name:   :new_table_other_new_id_fkey,
              fields: [:other_new_id],
              table:  :other_new_table
            )
          ),
          DbSchema::Changes::CreateTable.new(
            :other_new_table,
            fields: [
              DbSchema::Definitions::Field::Integer.new(:id, primary_key: true)
            ],
            indices: []
          )
        ]
      end

      it 'creates and drops tables and foreign keys in appropriate order' do
        subject.run!

        tables = DbSchema::Reader.read_schema
        expect(tables.count).to eq(6)
      end
    end

    context 'with CreateEnum & DropEnum' do
      before(:each) do
        database.create_enum :status, %i(registered confirmed_email subscriber)
      end

      let(:changes) do
        [
          DbSchema::Changes::CreateEnum.new(:happiness, %i(happy ok sad)),
          DbSchema::Changes::DropEnum.new(:status)
        ]
      end

      it 'applies all the changes' do
        subject.run!

        expect(enums).to eq([
          DbSchema::Definitions::Enum.new(:happiness, %i(happy ok sad))
        ])
      end
    end

    context 'with AddValueToEnum' do
      before(:each) do
        database.create_enum :happiness, %i(good ok bad)
      end

      context 'without a :before option' do
        let(:changes) do
          [
            DbSchema::Changes::AddValueToEnum.new(:happiness, :unhappy)
          ]
        end

        it 'adds the new value to the end of enum values list' do
          subject.run!

          expect(enums.count).to eq(1)
          expect(enums.first.values).to eq(%i(good ok bad unhappy))
        end
      end

      context 'with a :before option' do
        let(:changes) do
          [
            DbSchema::Changes::AddValueToEnum.new(:happiness, :happy, before: :good)
          ]
        end

        it 'adds the new value before the specified existing value' do
          subject.run!

          expect(enums.count).to eq(1)
          expect(enums.first.values).to eq(%i(happy good ok bad))
        end
      end

      context 'adding several consecutive values' do
        let(:changes) do
          [
            DbSchema::Changes::AddValueToEnum.new(:happiness, :depressed),
            DbSchema::Changes::AddValueToEnum.new(:happiness, :unhappy, before: :depressed),
            DbSchema::Changes::AddValueToEnum.new(:happiness, :happy, before: :good)
          ]
        end

        it 'adds the new values correctly' do
          subject.run!

          expect(enums.count).to eq(1)
          expect(enums.first.values).to eq(%i(happy good ok bad unhappy depressed))
        end
      end
    end

    context 'with CreateExtension & DropExtension' do
      before(:each) do
        database.run('CREATE EXTENSION hstore')
      end

      let(:changes) do
        [
          DbSchema::Changes::CreateExtension.new(:ltree),
          DbSchema::Changes::CreateExtension.new(:'uuid-ossp'),
          DbSchema::Changes::DropExtension.new(:hstore)
        ]
      end

      it 'applies all the changes' do
        subject.run!

        expect(extensions).to eq([
          DbSchema::Definitions::Extension.new(:ltree),
          DbSchema::Definitions::Extension.new(:'uuid-ossp')
        ])
      end

      after(:each) do
        database.run('DROP EXTENSION ltree')
        database.run('DROP EXTENSION "uuid-ossp"')
      end
    end

    it 'runs most operations in a transaction' do
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
              name:    :people_city_name_index,
              columns: [DbSchema::Definitions::Index::TableField.new(:city_name)],
              type:    :gist
            )
          ],
          checks: []
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

    enums.each do |enum|
      database.drop_enum(enum.name)
    end

    database.tables.each do |table_name|
      database.drop_table(table_name)
    end
  end
end
