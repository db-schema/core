require 'spec_helper'

RSpec.describe DbSchema::Normalizer do
  let(:raw_table) do
    DbSchema::Definitions::Table.new(
      :users,
      fields: [
        DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
        DbSchema::Definitions::Field::Varchar.new(:name, null: false),
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
      ]
    )
  end

  subject { DbSchema::Normalizer.new(raw_table) }

  describe '#normalized_table' do
    before(:each) do
      operation = DbSchema::Changes::CreateTable.new(
        :users,
        fields:  raw_table.fields,
        indices: raw_table.indices,
        checks:  raw_table.checks
      )

      DbSchema::Runner.new([operation]).run!
    end

    let(:table) { subject.normalized_table }

    it 'normalizes default values' do
      expect(table.fields.last.default).to eq(:'(18 + 5)')
    end

    it 'normalizes index conditions' do
      expect(table.indices.first.columns.first.name).to eq('lower(name::text)')
    end

    it 'normalizes index expressions' do
      expect(table.indices.first.condition).to eq('age <> 18')
    end

    it 'normalizes check constraint conditions' do
      expect(table.checks.first.condition).to eq('char_length(name::text) > 4')
    end

    it 'returns the table definitions with original names' do
      expect(table.name).to eq(:users)
      expect(table.indices.first.name).to eq(:lower_name_index)
    end

    it 'drops the temporary table' do
      expect(DbSchema::Reader.read_schema.tables.map(&:name)).to eq([:users])
    end

    context 'with postgres complaining about bad schema' do
      let(:bad_index) do
        DbSchema::Definitions::Index.new(
          name: :lower_name_index,
          columns: [
            DbSchema::Definitions::Index::Expression.new('lower(name)')
          ],
          condition: 'unknown_field = 1'
        )
      end

      before(:each) do
        raw_table.indices.pop
        raw_table.indices << bad_index
      end

      it "doesn't intercept postgres exception" do
        expect {
          table
        }.to raise_error(Sequel::DatabaseError, /column "unknown_field" does not exist/)
      end
    end

    after(:each) do
      operation = DbSchema::Changes::DropTable.new(:users)
      DbSchema::Runner.new([operation]).run!
    end
  end
end
