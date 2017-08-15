require 'spec_helper'

RSpec.describe DbSchema::Runner do
  let(:database) do
    Sequel.connect(adapter: 'postgres', database: 'db_schema_test').tap do |db|
      db.extension :pg_enum
      db.extension :pg_array
    end
  end

  let(:enums) do
    DbSchema::Reader.read_enums(database)
  end

  let(:extensions) do
    DbSchema::Reader.read_extensions(database)
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
      DbSchema::Definitions::Field::Timestamp.new(:created_at, null: false, default: :'now()'),
      DbSchema::Definitions::Field::Interval.new(:period, fields: :second),
      DbSchema::Definitions::Field::Bit.new(:some_bit),
      DbSchema::Definitions::Field::Bit.new(:some_bits, length: 7),
      DbSchema::Definitions::Field::Varbit.new(:some_varbit, length: 250),
      DbSchema::Definitions::Field::Array.new(:names, element_type: :varchar)
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

  subject { DbSchema::Runner.new(changes, database) }

  describe '#run!' do
    context 'with CreateTable & DropTable' do
      let(:changes) do
        [
          DbSchema::Operations::CreateTable.new(
            DbSchema::Definitions::Table.new(
              :users,
              fields:  users_fields,
              indices: users_indices,
              checks:  users_checks
            )
          ),
          DbSchema::Operations::DropTable.new(:people)
        ]
      end

      it 'applies all the changes' do
        subject.run!

        expect(database.tables).not_to include(:people)
        expect(database.tables).to include(:users)

        expect(database.primary_key(:users)).to eq('id')
        expect(database.primary_key_sequence(:users)).to eq('"public"."users_id_seq"')

        users = DbSchema::Reader.read_table(:users, database)
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
        expect(created_at.default).to eq(:'now()')
        expect(period.name).to eq(:period)
        expect(period).to be_a(DbSchema::Definitions::Field::Interval)
        expect(period.options[:fields]).to eq(:second)
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

        indices = DbSchema::Reader::Postgres.indices_data_for(:users, database)
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

    context 'with RenameTable' do
      let(:changes) do
        [DbSchema::Operations::RenameTable.new(old_name: :people, new_name: :users)]
      end

      it 'applies all the changes' do
        subject.run!

        schema = DbSchema::Reader.read_schema(database)
        expect(schema).not_to have_table(:people)
        expect(schema).to have_table(:users)
      end
    end

    context 'with AlterTable' do
      let(:changes) do
        [DbSchema::Operations::AlterTable.new(:people, table_changes)]
      end

      context 'containing CreateColumn & DropColumn' do
        let(:table_changes) do
          [
            DbSchema::Operations::CreateColumn.new(DbSchema::Definitions::Field::Varchar.new(:first_name)),
            DbSchema::Operations::CreateColumn.new(
              DbSchema::Definitions::Field::Varchar.new(:last_name, length: 30, null: false)
            ),
            DbSchema::Operations::CreateColumn.new(DbSchema::Definitions::Field::Integer.new(:age, null: false)),
            DbSchema::Operations::DropColumn.new(:name),
            DbSchema::Operations::DropColumn.new(:id),
            DbSchema::Operations::CreateColumn.new(
              DbSchema::Definitions::Field::Integer.new(:uid, primary_key: true)
            ),
            DbSchema::Operations::CreateColumn.new(
              DbSchema::Definitions::Field::Timestamp.new(:updated_at, null: false, default: :'now()')
            )
          ]
        end

        it 'applies all the changes' do
          subject.run!

          expect(database.primary_key(:people)).to eq('uid')
          expect(database.primary_key_sequence(:people)).to eq('"public"."people_uid_seq"')

          people = DbSchema::Reader.read_table(:people, database)
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
          expect(updated_at.default).to eq(:'now()')
        end
      end

      context 'containing RenameColumn' do
        let(:table_changes) do
          [
            DbSchema::Operations::RenameColumn.new(old_name: :name, new_name: :full_name)
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
        let(:table_changes) do
          [
            DbSchema::Operations::AlterColumnType.new(:name, new_type: :text)
          ]
        end

        it 'applies all the changes' do
          subject.run!

          id, name = database.schema(:people)
          expect(name.last[:db_type]).to eq('text')
        end

        context 'that changes field attributes' do
          let(:table_changes) do
            [
              DbSchema::Operations::AlterColumnType.new(:address, new_type: :varchar),
              DbSchema::Operations::AlterColumnType.new(:country_name, new_type: :varchar, length: 40),
              DbSchema::Operations::AlterColumnType.new(:created_at, new_type: :timestamp)
            ]
          end

          it 'applies all the changes' do
            subject.run!

            people = DbSchema::Reader.read_table(:people, database)
            address, country_name, created_at = people.fields.last(3)

            expect(address).to be_a(DbSchema::Definitions::Field::Varchar)
            expect(address.options[:length]).to be_nil
            expect(country_name).to be_a(DbSchema::Definitions::Field::Varchar)
            expect(country_name.options[:length]).to eq(40)
            expect(created_at).to be_a(DbSchema::Definitions::Field::Timestamp)
          end
        end

        context 'with a :using option' do
          let(:table_changes) do
            [
              DbSchema::Operations::AlterColumnType.new(:name, new_type: :integer, using: 'name::integer')
            ]
          end

          it 'applies all the changes' do
            subject.run!

            people = DbSchema::Reader.read_table(:people, database)
            expect(people[:name].type).to eq(:integer)
          end
        end
      end

      context 'containing CreatePrimaryKey' do
        let(:table_changes) do
          [
            DbSchema::Operations::CreatePrimaryKey.new(name: :name)
          ]
        end

        it 'raises a NotImplementedError' do
          expect {
            subject.run!
          }.to raise_error(NotImplementedError)
        end
      end

      context 'containing DropPrimaryKey' do
        let(:table_changes) do
          [
            DbSchema::Operations::DropPrimaryKey.new(name: :id)
          ]
        end

        it 'raises a NotImplementedError' do
          expect {
            subject.run!
          }.to raise_error(NotImplementedError)
        end
      end

      context 'containing AllowNull & DisallowNull' do
        let(:table_changes) do
          [
            DbSchema::Operations::AllowNull.new(:address),
            DbSchema::Operations::DisallowNull.new(:name)
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
        let(:table_changes) do
          [
            DbSchema::Operations::AlterColumnDefault.new(:name, new_default: 'John Smith')
          ]
        end

        it 'applies all the changes' do
          subject.run!

          name = database.schema(:people)[1]
          expect(name.last[:default]).to eq("'John Smith'::character varying")
        end

        context 'with an expression' do
          let(:table_changes) do
            [
              DbSchema::Operations::AlterColumnDefault.new(:created_at, new_default: :'now()')
            ]
          end

          it 'applies all the changes' do
            subject.run!

            created_at = database.schema(:people).last
            expect(created_at.last[:default]).to eq('now()')
          end
        end
      end

      context 'containing CreateIndex & DropIndex' do
        let(:table_changes) do
          [
            DbSchema::Operations::CreateColumn.new(
              DbSchema::Definitions::Field::Array.new(:interests, element_type: :varchar)
            ),
            DbSchema::Operations::CreateIndex.new(
              DbSchema::Definitions::Index.new(
                name:      :people_name_index,
                columns:   [DbSchema::Definitions::Index::Expression.new('lower(name)', order: :desc)],
                condition: 'name IS NOT NULL'
              )
            ),
            DbSchema::Operations::DropIndex.new(:people_address_index),
            DbSchema::Operations::CreateIndex.new(
              DbSchema::Definitions::Index.new(
                name:    :people_interests_index,
                columns: [DbSchema::Definitions::Index::TableField.new(:interests)],
                type:    :gin
              )
            )
          ]
        end

        it 'applies all the changes' do
          subject.run!

          indices = DbSchema::Reader::Postgres.indices_data_for(:people, database)
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
        let(:table_changes) do
          [
            DbSchema::Operations::DropCheckConstraint.new(:address_length),
            DbSchema::Operations::CreateCheckConstraint.new(
              DbSchema::Definitions::CheckConstraint.new(
                name:      :min_address_length,
                condition: 'character_length(address) >= 10'
              )
            )
          ]
        end

        it 'applies all the changes' do
          subject.run!

          people = DbSchema::Reader.read_table(:people, database)
          expect(people.checks.count).to eq(1)
          address_check = people.checks.first
          expect(address_check.name).to eq(:min_address_length)
          expect(address_check.condition).to eq('character_length(address::text) >= 10')
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
          DbSchema::Operations::DropForeignKey.new(:people, :people_city_name_fkey),
          DbSchema::Operations::CreateForeignKey.new(
            :people,
            DbSchema::Definitions::ForeignKey.new(
              name:      :people_city_id_fkey,
              fields:    [:city_id],
              table:     :cities,
              on_delete: :set_null
            )
          ),
          DbSchema::Operations::CreateForeignKey.new(
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

    context 'with CreateEnum & DropEnum' do
      before(:each) do
        database.create_enum :status, %i(registered confirmed_email subscriber)
      end

      let(:changes) do
        [
          DbSchema::Operations::CreateEnum.new(
            DbSchema::Definitions::Enum.new(:happiness, %i(happy ok sad))
          ),
          DbSchema::Operations::DropEnum.new(:status)
        ]
      end

      it 'applies all the changes' do
        subject.run!

        expect(enums).to eq([
          DbSchema::Definitions::Enum.new(:happiness, %i(happy ok sad))
        ])
      end
    end

    context 'with AlterEnumValues' do
      before(:each) do
        database.create_enum :happiness, %i(good ok bad)
      end

      let(:changes) do
        [
          DbSchema::Operations::AlterEnumValues.new(
            :happiness,
            %i(happy ok sad),
            fields
          )
        ]
      end

      let(:fields) { [] }

      it 'replaces the enum with a new one' do
        subject.run!

        expect(enums.count).to eq(1)
        expect(enums.first.values).to eq(%i(happy ok sad))
      end

      context 'with existing fields of this enum type' do
        before(:each) do
          database.create_table :users do
            primary_key :id
            column :happiness, :happiness, default: 'ok'
          end
        end

        let(:fields) do
          [
            { table_name: :users, field_name: :happiness, new_default: 'ok', array: false }
          ]
        end

        it 'converts existing fields to the new type' do
          subject.run!

          field = DbSchema::Reader.read_table(:users, database).fields.last
          expect(field.type).to eq(:happiness)
          expect(field.default).to eq('ok')
        end
      end

      context 'with existing fields as arrays of this enum type' do
        let(:changes) do
          [
            DbSchema::Operations::AlterEnumValues.new(
              :user_role,
              [:user, :admin],
              [
                { table_name: :users, field_name: :roles, new_default: '{"user"}', array: true }
              ]
            )
          ]
        end

        before(:each) do
          database.create_enum(:user_role, [:guest, :user, :admin])

          database.create_table :users do
            primary_key :id
            column :roles, 'user_role[]'
          end
        end

        it 'converts existing fields to the new type' do
          subject.run!

          field = DbSchema::Reader.read_table(:users, database)[:roles]
          expect(field.type).to eq(:array)
          expect(field.attributes[:element_type]).to eq(:user_role)
          expect(field.default).to eq('{user}')
        end
      end
    end

    context 'with CreateExtension & DropExtension' do
      before(:each) do
        database.run('CREATE EXTENSION hstore')
      end

      let(:changes) do
        [
          DbSchema::Operations::CreateExtension.new(
            DbSchema::Definitions::Extension.new(:ltree)
          ),
          DbSchema::Operations::CreateExtension.new(
            DbSchema::Definitions::Extension.new(:'uuid-ossp')
          ),
          DbSchema::Operations::DropExtension.new(:hstore)
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

    context 'with ExecuteQuery' do
      let(:changes) do
        [
          DbSchema::Operations::ExecuteQuery.new('ALTER TABLE people RENAME TO users')
        ]
      end

      it 'runs the query' do
        subject.run!

        schema = DbSchema::Reader.read_schema(database)
        expect(schema).not_to have_table(:people)
        expect(schema).to have_table(:users)
      end
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
      database.drop_enum(enum.name, cascade: true)
    end

    database.tables.each do |table_name|
      database.drop_table(table_name)
    end
  end
end
