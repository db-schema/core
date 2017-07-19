require 'spec_helper'

RSpec.describe DbSchema::Migrator do
  before(:each) do
    DbSchema::Runner.new([
      DbSchema::Operations::CreateTable.new(
        DbSchema::Definitions::Table.new(
          :people,
          fields: [
            DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
            DbSchema::Definitions::Field::Varchar.new(:name, null: false)
          ]
        )
      )
    ]).run!
  end

  let(:schema)    { DbSchema::Reader.read_schema }
  let(:migration) { DbSchema::Migration.new('Migration name') }

  subject { DbSchema::Migrator.new(migration) }

  describe '#applicable?' do
    context 'with a schema satisfying all conditions' do
      before(:each) do
        migration.conditions[:apply] << -> (schema) do
          schema.has_table?(:people)
        end

        migration.conditions[:skip] << -> (schema) do
          schema.has_table?(:users)
        end
      end

      it 'returns true' do
        expect(subject).to be_applicable(schema)
      end
    end

    context 'with a schema failing some conditions' do
      before(:each) do
        migration.conditions[:apply] << -> (schema) do
          schema.has_table?(:posts)
        end

        migration.conditions[:skip] << -> (schema) do
          !schema.table(:people).field(:name).null?
        end
      end

      it 'returns false' do
        expect(subject).not_to be_applicable(schema)
      end
    end
  end

  describe '#run!' do
    before(:each) do
      migration.changes << DbSchema::Operations::RenameTable.new(
        old_name: :people,
        new_name: :users
      )
    end

    it 'applies the migration changes' do
      subject.run!

      schema = DbSchema::Reader.read_schema
      expect(schema).not_to have_table(:people)
      expect(schema).to have_table(:users)
    end
  end

  after(:each) do
    DbSchema.connection.tables.each do |table_name|
      DbSchema.connection.drop_table(table_name)
    end
  end
end
