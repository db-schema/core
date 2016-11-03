require 'spec_helper'

RSpec.describe DbSchema::Normalizer do
  let(:raw_table) do
    DbSchema::Definitions::Table.new(
      :users,
      fields: [
        DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
        DbSchema::Definitions::Field::Varchar.new(:name, null: false),
        DbSchema::Definitions::Field::Integer.new(:group_id),
        DbSchema::Definitions::Field::Integer.new(:age, default: :'18 + 5')
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
    let(:schema) { DbSchema::Definitions::Schema.new(tables: [raw_table]) }

    before(:each) do
      operation = DbSchema::Changes::CreateTable.new(
        :users,
        fields:  raw_table.fields,
        indices: raw_table.indices,
        checks:  raw_table.checks
      )

      DbSchema::Runner.new([operation]).run!
    end

    it 'normalizes all tables in the schema passed in' do
      DbSchema::Normalizer.normalize_tables(schema)

      expect(schema.tables.count).to eq(1)
      users = schema.tables.first
      expect(users.name).to eq(:users)
      expect(users.fields.last.default).to eq(:'(18 + 5)')
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
      operation = DbSchema::Changes::DropTable.new(:users)
      DbSchema::Runner.new([operation]).run!
    end
  end
end
