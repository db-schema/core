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

      let(:desired_schema) do
        [DbSchema::Definitions::Table.new(name: :users, fields: users_fields)]
      end

      let(:actual_schema) do
        fields = [
          DbSchema::Definitions::Field.new(name: :id, type: :integer),
          DbSchema::Definitions::Field.new(name: :title, type: :varchar)
        ]

        [DbSchema::Definitions::Table.new(name: :posts, fields: fields)]
      end

      it 'returns changes between two schemas' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes).to include(DbSchema::Changes::CreateTable.new(name: :users, fields: users_fields))
        expect(changes).to include(DbSchema::Changes::DropTable.new(name: :posts))
      end
    end

    context 'with table changed' do
      let(:remaining_fields) do
        [
          DbSchema::Definitions::Field.new(name: :id, type: :integer),
          DbSchema::Definitions::Field.new(name: :name, type: :varchar)
        ]
      end

      let(:desired_schema) do
        fields = remaining_fields + [DbSchema::Definitions::Field.new(name: :email, type: :varchar, null: false)]

        [DbSchema::Definitions::Table.new(name: :users, fields: fields)]
      end

      let(:actual_schema) do
        fields = remaining_fields + [DbSchema::Definitions::Field.new(name: :age, type: :integer)]

        [DbSchema::Definitions::Table.new(name: :users, fields: fields)]
      end

      it 'returns changes between two schemas' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes.count).to eq(1)
        alter_table = changes.first
        expect(alter_table).to be_a(DbSchema::Changes::AlterTable)

        add_email, drop_age = alter_table.fields
        expect(add_email).to eq(DbSchema::Changes::CreateColumn.new(name: :email, type: :varchar, null: false))
        expect(drop_age).to eq(DbSchema::Changes::DropColumn.new(name: :age))
      end
    end
  end
end
