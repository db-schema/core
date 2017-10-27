require 'spec_helper'

RSpec.describe DbSchema::Normalizer do
  let(:database) do
    Sequel.connect(adapter: 'postgres', database: 'db_schema_test').tap do |db|
      db.extension :pg_enum
      db.extension :pg_array
    end
  end

  let(:enums) do
    [
      DbSchema::Definitions::Enum.new(:happiness, %i(good ok bad)),
      DbSchema::Definitions::Enum.new(:user_status, %i(guest registered)),
      DbSchema::Definitions::Enum.new(:user_role, %i(user))
    ]
  end

  let(:extensions) do
    [
      DbSchema::Definitions::Extension.new(:ltree),
      DbSchema::Definitions::Extension.new(:hstore)
    ]
  end

  let(:raw_table) do
    DbSchema::Definitions::Table.new(
      :users,
      fields: [
        DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
        DbSchema::Definitions::Field::Varchar.new(:name, null: false),
        DbSchema::Definitions::Field::Integer.new(:group_id),
        DbSchema::Definitions::Field::Integer.new(:age, default: :'18 + 5'),
        DbSchema::Definitions::Field::Hstore.new(:data),
        DbSchema::Definitions::Field::Custom.class_for(:happiness).new(:happiness, default: 'ok'),
        DbSchema::Definitions::Field::Array.new(:roles, element_type: :user_role, default: '{user}'),
        DbSchema::Definitions::Field::Ltree.new(:path),
        DbSchema::Definitions::Field::Custom.class_for(:user_status).new(:user_status)
      ],
      indices: [
        DbSchema::Definitions::Index.new(
          name: :lower_name_index,
          columns: [
            DbSchema::Definitions::Index::Expression.new('lower(name)')
          ],
          condition: 'age != 18'
        )
      ],
      checks: [
        DbSchema::Definitions::CheckConstraint.new(name: :name_length, condition: 'char_length(name) > 4')
      ],
      foreign_keys: [
        DbSchema::Definitions::ForeignKey.new(name: :users_group_id_fkey, fields: [:group_id], table: :groups)
      ]
    )
  end

  describe '.normalized_tables' do
    let(:schema) do
      DbSchema::Definitions::Schema.new(
        tables:     [raw_table],
        enums:      enums,
        extensions: extensions
      )
    end

    before(:each) do
      add_hstore = DbSchema::Operations::CreateExtension.new(
        DbSchema::Definitions::Extension.new(:hstore)
      )
      add_happiness = DbSchema::Operations::CreateEnum.new(
        DbSchema::Definitions::Enum.new(:happiness, %i(good bad))
      )
      add_role = DbSchema::Operations::CreateEnum.new(
        DbSchema::Definitions::Enum.new(:user_role, %i(admin))
      )

      fields = raw_table.fields.take(5)
      fields << DbSchema::Definitions::Field::Custom.class_for(:happiness).new(:happiness)
      fields << DbSchema::Definitions::Field::Array.new(:roles, element_type: :user_role, default: '{admin}')

      create_table = DbSchema::Operations::CreateTable.new(
        DbSchema::Definitions::Table.new(
          :users,
          fields:  fields,
          indices: raw_table.indices,
          checks:  raw_table.checks
        )
      )

      DbSchema::Runner.new([add_hstore, add_happiness, add_role, create_table], database).run!
    end

    it 'normalizes all tables in the schema passed in' do
      DbSchema::Normalizer.new(schema, database).normalize_tables

      expect(schema.tables.count).to eq(1)
      users = schema.table(:users)

      expect(users.field(:id)).to be_primary_key
      expect(users.field(:age).default).to eq(:'(18 + 5)')
      expect(users.field(:happiness).type).to eq(:happiness)
      expect(users.field(:roles)).to be_array
      expect(users.field(:roles).attributes[:element_type]).to eq(:user_role)
      expect(users.field(:roles).default).to eq('{user}')
      expect(users.index(:lower_name_index).columns.first.name).to eq('lower(name::text)')
      expect(users.index(:lower_name_index).condition).to eq('age <> 18')
      expect(users.check(:name_length).condition).to eq('char_length(name::text) > 4')
      expect(users.foreign_key(:users_group_id_fkey).fields).to eq([:group_id])
      expect(users.foreign_key(:users_group_id_fkey).table).to eq(:groups)
    end

    it 'rolls back all temporary tables' do
      expect {
        DbSchema::Normalizer.new(schema, database).normalize_tables
      }.not_to change { DbSchema::Reader.read_schema(database).tables.count }
    end

    after(:each) do
      drop_table     = DbSchema::Operations::DropTable.new(:users)
      drop_happiness = DbSchema::Operations::DropEnum.new(:happiness)
      drop_role      = DbSchema::Operations::DropEnum.new(:user_role)
      drop_hstore    = DbSchema::Operations::DropExtension.new(:hstore)

      DbSchema::Runner.new([drop_table, drop_happiness, drop_role, drop_hstore], database).run!
    end
  end
end
