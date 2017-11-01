require 'spec_helper'

RSpec.describe DbSchema::Runner do
  let(:database) do
    Sequel.connect(adapter: 'postgres', database: 'db_schema_test').tap do |db|
      db.extension :pg_enum
      db.extension :pg_array
    end
  end

  describe '#run!' do
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

    let(:schema) { DbSchema::Reader.read_schema(database) }

    subject { DbSchema::Runner.new(changes, database) }

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

        expect(schema).not_to have_table(:people)
        expect(schema).to have_table(:users)

        expect(database.primary_key(:users)).to eq('id')
        expect(database.primary_key_sequence(:users)).to eq('"public"."users_id_seq"')

        users = schema.table(:users)

        expect(users.field(:id).type).to eq(:integer)
        expect(users.field(:id)).to be_primary_key
        expect(users.field(:name).type).to eq(:varchar)
        expect(users.field(:name).options[:length]).to eq(50)
        expect(users.field(:name)).not_to be_null
        expect(users.field(:email).type).to eq(:varchar)
        expect(users.field(:email).default).to eq('mail@example.com')
        expect(users.field(:created_at).type).to eq(:timestamp)
        expect(users.field(:created_at)).not_to be_null
        expect(users.field(:created_at).default).to eq(:'now()')
        expect(users.field(:period).type).to eq(:interval)
        expect(users.field(:period).options[:fields]).to eq(:second)
        expect(users.field(:some_bit).type).to eq(:bit)
        expect(users.field(:some_bit).options[:length]).to eq(1)
        expect(users.field(:some_bits).type).to eq(:bit)
        expect(users.field(:some_bits).options[:length]).to eq(7)
        expect(users.field(:some_varbit).type).to eq(:varbit)
        expect(users.field(:some_varbit).options[:length]).to eq(250)
        expect(users.field(:names)).to be_array
        expect(users.field(:names).options[:element_type]).to eq(:varchar)

        expect(users.index(:index_users_on_name).columns).to eq([DbSchema::Definitions::Index::Expression.new('lower(name::text)')])
        expect(users.index(:index_users_on_name)).not_to be_unique
        expect(users.index(:index_users_on_name).type).to eq(:btree)
        expect(users.index(:index_users_on_email).columns).to eq([DbSchema::Definitions::Index::TableField.new(:email, order: :desc, nulls: :last)])
        expect(users.index(:index_users_on_email)).to be_unique
        expect(users.index(:index_users_on_email).type).to eq(:btree)
        expect(users.index(:index_users_on_email).condition).to eq('email IS NOT NULL')
        expect(users.index(:users_names_index).columns).to eq([DbSchema::Definitions::Index::TableField.new(:names)])
        expect(users.index(:users_names_index).type).to eq(:gin)

        expect(users.checks.count).to eq(1)
        expect(users.check(:min_name_length).condition).to eq('character_length(name::text) > 4')
      end
    end

    context 'with RenameTable' do
      let(:changes) do
        [DbSchema::Operations::RenameTable.new(old_name: :people, new_name: :users)]
      end

      it 'applies all the changes' do
        subject.run!

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

          people = schema.table(:people)
          expect(people).to have_field(:address)
          expect(people.field(:created_at).type).to eq(:timestamptz)
          expect(people.field(:first_name).type).to eq(:varchar)
          expect(people.field(:last_name).type).to eq(:varchar)
          expect(people.field(:last_name).options[:length]).to eq(30)
          expect(people.field(:last_name)).not_to be_null
          expect(people.field(:age).type).to eq(:integer)
          expect(people.field(:age)).not_to be_null
          expect(people.field(:uid)).to be_primary_key
          expect(people.field(:updated_at).type).to eq(:timestamp)
          expect(people.field(:updated_at).default).to eq(:'now()')
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

          expect(schema.table(:people)).to have_field(:full_name)
          expect(schema.table(:people).field(:full_name).type).to eq(:varchar)
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

          expect(schema.table(:people).field(:name).type).to eq(:text)
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

            people = schema.table(:people)

            expect(people.field(:address).type).to eq(:varchar)
            expect(people.field(:address).options[:length]).to be_nil
            expect(people.field(:country_name).type).to eq(:varchar)
            expect(people.field(:country_name).options[:length]).to eq(40)
            expect(people.field(:created_at).type).to eq(:timestamp)
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

            expect(schema.table(:people).field(:name).type).to eq(:integer)
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

          expect(schema.table(:people).field(:name)).not_to be_null
          expect(schema.table(:people).field(:address)).to be_null
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

          expect(schema.table(:people).field(:name).default).to eq('John Smith')
        end

        context 'with an expression' do
          let(:table_changes) do
            [
              DbSchema::Operations::AlterColumnDefault.new(:created_at, new_default: :'now()')
            ]
          end

          it 'applies all the changes' do
            subject.run!

            expect(schema.table(:people).field(:created_at).default).to eq(:'now()')
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

          expect(schema.table(:people)).not_to have_index(:people_address_index)
          expect(schema.table(:people)).to have_index(:people_name_index)
          expect(schema.table(:people)).to have_index(:people_interests_index)

          name_index = schema.table(:people).index(:people_name_index)
          expect(name_index.columns).to eq([
            DbSchema::Definitions::Index::Expression.new('lower(name::text)', order: :desc)
          ])
          expect(name_index).not_to be_unique
          expect(name_index.type).to eq(:btree)
          expect(name_index.condition).to eq('name IS NOT NULL')

          interests_index = schema.table(:people).index(:people_interests_index)
          # non-BTree indexes don't support index ordering
          expect(interests_index.columns).to eq([
            DbSchema::Definitions::Index::TableField.new(:interests)
          ])
          expect(interests_index.type).to eq(:gin)
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

          expect(schema.table(:people)).not_to have_check(:address_length)
          expect(schema.table(:people)).to have_check(:min_address_length)
          expect(schema.table(:people).check(:min_address_length).condition).to eq('character_length(address::text) >= 10')
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

        people = schema.table(:people)
        expect(people).not_to have_foreign_key(:people_city_name_fkey)
        expect(people).to have_foreign_key(:people_city_id_fkey)
        expect(people).to have_foreign_key(:people_country_name_fkey)

        expect(people.foreign_key(:people_city_id_fkey).fields).to eq([:city_id])
        expect(people.foreign_key(:people_city_id_fkey).table).to eq(:cities)
        expect(people.foreign_key(:people_city_id_fkey).on_delete).to eq(:set_null)
        expect(people.foreign_key(:people_city_id_fkey).on_update).to eq(:no_action)

        expect(people.foreign_key(:people_country_name_fkey).fields).to eq([:country_name])
        expect(people.foreign_key(:people_country_name_fkey).table).to eq(:countries)
        expect(people.foreign_key(:people_country_name_fkey).keys).to eq([:name])
        expect(people.foreign_key(:people_country_name_fkey).on_delete).to eq(:no_action)
        expect(people.foreign_key(:people_country_name_fkey).on_update).to eq(:cascade)
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

        expect(schema).to have_enum(:happiness)
        expect(schema.enum(:happiness).values).to eq(%i(happy ok sad))
        expect(schema).not_to have_enum(:status)
      end
    end

    context 'with RenameEnum' do
      before(:each) do
        database.create_enum :status, %i(registered confirmed_email subscriber)
      end

      let(:changes) do
        [
          DbSchema::Operations::RenameEnum.new(old_name: :status, new_name: :'user status')
        ]
      end

      it 'applies all the changes' do
        subject.run!

        expect(schema).not_to have_enum(:status)
        expect(schema).to have_enum(:'user status')
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

        expect(schema).to have_enum(:happiness)
        expect(schema.enum(:happiness).values).to eq(%i(happy ok sad))
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

          field = schema.table(:users).field(:happiness)
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

          field = schema.table(:users).field(:roles)
          expect(field).to be_array
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

        expect(schema).to have_extension(:ltree)
        expect(schema).to have_extension(:'uuid-ossp')
        expect(schema).not_to have_extension(:hstore)
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

        expect(schema).not_to have_table(:people)
        expect(schema).to have_table(:users)
      end
    end

    after(:each) do
      clean!
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
end
