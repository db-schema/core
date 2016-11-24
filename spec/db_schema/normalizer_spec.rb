require 'spec_helper'

RSpec.describe DbSchema::Normalizer do
  let(:enums) do
    [
      DbSchema::Definitions::Enum.new(:happiness, %i(good ok bad)),
      DbSchema::Definitions::Enum.new(:user_status, %i(guest registered))
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
        DbSchema::Definitions::Field::Custom.class_for(:happiness).new(:happiness),
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
      add_hstore = DbSchema::Changes::CreateExtension.new(:hstore)
      add_happiness = DbSchema::Changes::CreateEnum.new(:happiness, %i(good bad))

      create_table = DbSchema::Changes::CreateTable.new(
        :users,
        fields:  raw_table.fields.take(6),
        indices: raw_table.indices,
        checks:  raw_table.checks
      )

      DbSchema::Runner.new([add_hstore, add_happiness, create_table]).run!
    end

    it 'normalizes all tables in the schema passed in' do
      DbSchema::Normalizer.normalize_tables(schema)

      expect(schema.tables.count).to eq(1)
      users = schema.tables.first
      expect(users.name).to eq(:users)
      expect(users.fields[3].default).to eq(:'(18 + 5)')
      expect(users.indices.first.name).to eq(:lower_name_index)
      expect(users.indices.first.columns.first.name).to eq('lower(name::text)')
      expect(users.indices.first.condition).to eq('age <> 18')
      expect(users.checks.first.condition).to eq('char_length(name::text) > 4')
      expect(users.foreign_keys).to eq(raw_table.foreign_keys)
    end

    it 'rolls back all temporary tables' do
      expect {
        DbSchema::Normalizer.normalize_tables(schema)
      }.not_to change { DbSchema::Reader.read_schema.tables.count }
    end

    after(:each) do
      drop_table     = DbSchema::Changes::DropTable.new(:users)
      drop_happiness = DbSchema::Changes::DropEnum.new(:happiness)
      drop_hstore    = DbSchema::Changes::DropExtension.new(:hstore)

      DbSchema::Runner.new([drop_table, drop_happiness, drop_hstore]).run!
    end
  end
end
