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
  end
end
