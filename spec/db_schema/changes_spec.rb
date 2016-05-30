require 'spec_helper'

RSpec.describe DbSchema::Changes do
  describe '.between' do
    context 'with tables being added and removed' do
      let(:users_fields) do
        [
          DbSchema::Definitions::Field::Integer.new(:id),
          DbSchema::Definitions::Field::Varchar.new(:name),
          DbSchema::Definitions::Field::Integer.new(:city_id)
        ]
      end

      let(:users_foreign_keys) do
        [DbSchema::Definitions::ForeignKey.new(name: :users_city_id_fkey, fields: [:city_id], table: :cities)]
      end

      let(:posts_fields) do
        [
          DbSchema::Definitions::Field::Integer.new(:id),
          DbSchema::Definitions::Field::Varchar.new(:title)
        ]
      end

      let(:cities_fields) do
        [
          DbSchema::Definitions::Field::Integer.new(:id),
          DbSchema::Definitions::Field::Varchar.new(:name, null: false),
          DbSchema::Definitions::Field::Integer.new(:country_id, null: false)
        ]
      end

      let(:desired_schema) do
        [
          DbSchema::Definitions::Table.new(:users, fields: users_fields, foreign_keys: users_foreign_keys),
          DbSchema::Definitions::Table.new(:cities, fields: cities_fields)
        ]
      end

      let(:actual_schema) do
        [
          DbSchema::Definitions::Table.new(:posts, fields: posts_fields),
          DbSchema::Definitions::Table.new(:cities, fields: cities_fields)
        ]
      end

      it 'returns changes between two schemas' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes).to include(
          DbSchema::Changes::CreateTable.new(:users, fields: users_fields, foreign_keys: users_foreign_keys)
        )
        expect(changes).to include(DbSchema::Changes::DropTable.new(:posts))
      end

      it 'ignores matching tables' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes.count).to eq(2)
      end
    end

    context 'with table changed' do
      let(:desired_schema) do
        fields = [
          DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
          DbSchema::Definitions::Field::Varchar.new(:name),
          DbSchema::Definitions::Field::Varchar.new(:email, null: false),
          DbSchema::Definitions::Field::Varchar.new(:type, null: false, default: 'guest'),
          DbSchema::Definitions::Field::Integer.new(:city_id),
          DbSchema::Definitions::Field::Integer.new(:country_id),
          DbSchema::Definitions::Field::Integer.new(:group_id)
        ]

        indices = [
          DbSchema::Definitions::Index.new(
            name:      :users_name_index,
            fields:    [:name],
            unique:    true,
            condition: 'email IS NOT NULL'
          ),
          DbSchema::Definitions::Index.new(name: :users_email_index, fields: [:email], unique: true)
        ]

        foreign_keys = [
          DbSchema::Definitions::ForeignKey.new(
            name:   :users_city_id_fkey,
            fields: [:city_id],
            table:  :cities
          ),
          DbSchema::Definitions::ForeignKey.new(
            name:      :users_group_id_fkey,
            fields:    [:group_id],
            table:     :groups,
            on_delete: :cascade
          )
        ]

        [
          DbSchema::Definitions::Table.new(
            :users,
            fields:       fields,
            indices:      indices,
            foreign_keys: foreign_keys
          )
        ]
      end

      let(:actual_schema) do
        fields = [
          DbSchema::Definitions::Field::Integer.new(:id, null: false),
          DbSchema::Definitions::Field::Varchar.new(:name),
          DbSchema::Definitions::Field::Integer.new(:age),
          DbSchema::Definitions::Field::Integer.new(:type),
          DbSchema::Definitions::Field::Integer.new(:city_id),
          DbSchema::Definitions::Field::Integer.new(:country_id),
          DbSchema::Definitions::Field::Integer.new(:group_id)
        ]

        indices = [
          DbSchema::Definitions::Index.new(name: :users_name_index, fields: [:name]),
          DbSchema::Definitions::Index.new(name: :users_type_index, fields: [:type])
        ]

        foreign_keys = [
          DbSchema::Definitions::ForeignKey.new(
            name: :users_country_id_fkey,
            fields: [:country_id],
            table: :countries
          ),
          DbSchema::Definitions::ForeignKey.new(
            name:      :users_group_id_fkey,
            fields:    [:group_id],
            table:     :groups,
            on_delete: :set_null
          )
        ]

        [
          DbSchema::Definitions::Table.new(
            :users,
            fields:       fields,
            indices:      indices,
            foreign_keys: foreign_keys
          )
        ]
      end

      it 'returns changes between two schemas' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes.count).to eq(1)
        alter_table = changes.first
        expect(alter_table).to be_a(DbSchema::Changes::AlterTable)

        expect(alter_table.fields).to eq([
          DbSchema::Changes::CreatePrimaryKey.new(:id),
          DbSchema::Changes::CreateColumn.new(DbSchema::Definitions::Field::Varchar.new(:email, null: false)),
          DbSchema::Changes::AlterColumnType.new(:type, new_type: :varchar),
          DbSchema::Changes::DisallowNull.new(:type),
          DbSchema::Changes::AlterColumnDefault.new(:type, new_default: 'guest'),
          DbSchema::Changes::DropColumn.new(:age)
        ])

        expect(alter_table.indices).to eq([
          DbSchema::Changes::DropIndex.new(name: :users_name_index),
          DbSchema::Changes::CreateIndex.new(name: :users_name_index, fields: [:name], unique: true, condition: 'email IS NOT NULL'),
          DbSchema::Changes::CreateIndex.new(name: :users_email_index, fields: [:email], unique: true),
          DbSchema::Changes::DropIndex.new(name: :users_type_index)
        ])

        expect(alter_table.foreign_keys).to eq([
          DbSchema::Changes::CreateForeignKey.new(name: :users_city_id_fkey, fields: [:city_id], table: :cities),
          DbSchema::Changes::DropForeignKey.new(name: :users_group_id_fkey),
          DbSchema::Changes::CreateForeignKey.new(name: :users_group_id_fkey, fields: [:group_id], table: :groups, on_delete: :cascade),
          DbSchema::Changes::DropForeignKey.new(name: :users_country_id_fkey)
        ])
      end
    end
  end
end
