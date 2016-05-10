require 'spec_helper'

RSpec.describe DbSchema::Changes do
  describe '.between' do
    context 'with tables being added and removed' do
      let(:users_fields) do
        [
          DbSchema::Definitions::Field.new(name: :id, type: :integer),
          DbSchema::Definitions::Field.new(name: :name, type: :varchar)
        ]
      end

      let(:cities_fields) do
        [
          DbSchema::Definitions::Field.new(name: :id, type: :integer),
          DbSchema::Definitions::Field.new(name: :name, type: :varchar, null: false),
          DbSchema::Definitions::Field.new(name: :country_id, type: :integer, null: false)
        ]
      end

      let(:desired_schema) do
        [
          DbSchema::Definitions::Table.new(name: :users, fields: users_fields),
          DbSchema::Definitions::Table.new(name: :cities, fields: cities_fields)
        ]
      end

      let(:actual_schema) do
        fields = [
          DbSchema::Definitions::Field.new(name: :id, type: :integer),
          DbSchema::Definitions::Field.new(name: :title, type: :varchar)
        ]

        [
          DbSchema::Definitions::Table.new(name: :posts, fields: fields),
          DbSchema::Definitions::Table.new(name: :cities, fields: cities_fields)
        ]
      end

      it 'returns changes between two schemas' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes).to include(DbSchema::Changes::CreateTable.new(name: :users, fields: users_fields))
        expect(changes).to include(DbSchema::Changes::DropTable.new(name: :posts))
      end

      it 'ignores matching tables' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes.count).to eq(2)
      end
    end

    context 'with table changed' do
      let(:desired_schema) do
        fields = [
          DbSchema::Definitions::Field.new(name: :id, type: :integer, primary_key: true),
          DbSchema::Definitions::Field.new(name: :name, type: :varchar),
          DbSchema::Definitions::Field.new(name: :email, type: :varchar, null: false),
          DbSchema::Definitions::Field.new(name: :type, type: :varchar, null: false, default: 'guest')
        ]

        [DbSchema::Definitions::Table.new(name: :users, fields: fields)]
      end

      let(:actual_schema) do
        fields = [
          DbSchema::Definitions::Field.new(name: :id, type: :integer),
          DbSchema::Definitions::Field.new(name: :name, type: :varchar),
          DbSchema::Definitions::Field.new(name: :age, type: :integer),
          DbSchema::Definitions::Field.new(name: :type, type: :integer)
        ]

        [DbSchema::Definitions::Table.new(name: :users, fields: fields)]
      end

      it 'returns changes between two schemas' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes.count).to eq(1)
        alter_table = changes.first
        expect(alter_table).to be_a(DbSchema::Changes::AlterTable)

        expect(alter_table.fields).to eq([
          DbSchema::Changes::CreatePrimaryKey.new(name: :id),
          DbSchema::Changes::CreateColumn.new(name: :email, type: :varchar, null: false),
          DbSchema::Changes::AlterColumnType.new(name: :type, new_type: :varchar),
          DbSchema::Changes::DisallowNull.new(name: :type),
          DbSchema::Changes::AlterColumnDefault.new(name: :type, new_default: 'guest'),
          DbSchema::Changes::DropColumn.new(name: :age)
        ])
      end
    end
  end
end
