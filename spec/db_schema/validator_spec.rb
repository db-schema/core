require 'spec_helper'

RSpec.describe DbSchema::Validator do
  describe '.validate' do
    let(:result) { DbSchema::Validator.validate(schema) }

    let(:schema) do
      [
        DbSchema::Definitions::Table.new(
          :users,
          fields:  users_fields,
          indices: users_indices
        ),
        DbSchema::Definitions::Table.new(
          :posts,
          fields:       posts_fields,
          foreign_keys: posts_fkeys
        ),
        DbSchema::Definitions::Table.new(
          :cities,
          fields: [DbSchema::Definitions::Field::Varchar.new(:name)]
        ),
        enum
      ]
    end

    let(:users_fields) do
      [
        DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
        DbSchema::Definitions::Field::Varchar.new(:first_name, null: false),
        DbSchema::Definitions::Field::Varchar.new(:last_name, null: false),
        DbSchema::Definitions::Field::Integer.new(:age)
      ]
    end

    let(:posts_fields) do
      [
        DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
        DbSchema::Definitions::Field::Varchar.new(:title, null: false),
        DbSchema::Definitions::Field::Integer.new(:user_id, null: false)
      ]
    end

    let(:users_indices) do
      [
        DbSchema::Definitions::Index.new(
          name: :users_name_index,
          fields: [
            DbSchema::Definitions::Index::Field.new(:first_name),
            DbSchema::Definitions::Index::Field.new(:last_name)
          ],
          unique: true
        )
      ]
    end

    let(:posts_fkeys) do
      [
        DbSchema::Definitions::ForeignKey.new(
          name:   :posts_user_id_fkey,
          fields: [:user_id],
          table:  :users
        )
      ]
    end

    let(:enum) do
      DbSchema::Definitions::Enum.new(:happiness, %i(happy ok sad))
    end

    context 'on a valid schema' do
      it 'returns a valid result' do
        expect(result).to be_valid
      end
    end

    context 'on a schema with multiple primary keys in one table' do
      let(:users_fields) do
        [
          DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
          DbSchema::Definitions::Field::Varchar.new(:email, primary_key: true),
          DbSchema::Definitions::Field::Varchar.new(:name, null: false)
        ]
      end

      let(:users_indices) { [] }

      it 'returns an invalid result with errors' do
        expect(result).not_to be_valid
        expect(result.errors).to eq([
          'Table "users" has 2 primary keys'
        ])
      end
    end

    context 'on a schema with index on unknown field' do
      let(:users_indices) do
        [
          DbSchema::Definitions::Index.new(
            name: :invalid_index,
            fields: [
              DbSchema::Definitions::Index::Field.new(:address)
            ]
          )
        ]
      end

      it 'returns an invalid result with errors' do
        expect(result).not_to be_valid
        expect(result.errors).to eq([
          'Index "invalid_index" refers to a missing field "users.address"'
        ])
      end
    end

    context 'on a schema with foreign key on unknown field' do
      let(:posts_fkeys) do
        [
          DbSchema::Definitions::ForeignKey.new(
            name:   :posts_author_id_fkey,
            fields: [:author_id],
            table:  :users
          )
        ]
      end

      it 'returns an invalid result with errors' do
        expect(result).not_to be_valid
        expect(result.errors).to eq([
          'Foreign key "posts_author_id_fkey" constrains a missing field "posts.author_id"'
        ])
      end
    end

    context 'on a schema with foreign key referencing unknown table' do
      let(:posts_fkeys) do
        [
          DbSchema::Definitions::ForeignKey.new(
            name:   :posts_user_id_fkey,
            fields: [:user_id],
            table:  :admins
          )
        ]
      end

      it 'returns an invalid result with errors' do
        expect(result).not_to be_valid
        expect(result.errors).to eq([
          'Foreign key "posts_user_id_fkey" refers to a missing table "admins"'
        ])
      end
    end

    context 'on a schema with foreign key referencing unknown primary key' do
      let(:posts_fields) do
        [
          DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
          DbSchema::Definitions::Field::Varchar.new(:title, null: false),
          DbSchema::Definitions::Field::Integer.new(:user_id, null: false),
          DbSchema::Definitions::Field::Integer.new(:city_id, null: false),
        ]
      end

      let(:posts_fkeys) do
        [
          DbSchema::Definitions::ForeignKey.new(
            name:   :posts_city_id_fkey,
            fields: [:city_id],
            table:  :cities
          )
        ]
      end

      it 'returns an invalid result with errors' do
        expect(result).not_to be_valid
        expect(result.errors).to eq([
          'Foreign key "posts_city_id_fkey" refers to primary key of table "cities" which does not have a primary key'
        ])
      end
    end

    context 'on a schema with foreign key referencing unknown field' do
      let(:posts_fields) do
        [
          DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
          DbSchema::Definitions::Field::Varchar.new(:title, null: false),
          DbSchema::Definitions::Field::Integer.new(:user_name, null: false)
        ]
      end

      let(:posts_fkeys) do
        [
          DbSchema::Definitions::ForeignKey.new(
            name:   :posts_user_name_fkey,
            fields: [:user_name],
            table:  :users,
            keys:   [:name]
          )
        ]
      end

      it 'returns an invalid result with errors' do
        expect(result).not_to be_valid
        expect(result.errors).to eq([
          'Foreign key "posts_user_name_fkey" refers to a missing field "users.name"'
        ])
      end
    end

    context 'on a schema with an empty enum' do
      let(:enum) { DbSchema::Definitions::Enum.new(:happiness, []) }

      it 'returns an invalid result with errors' do
        expect(result).not_to be_valid
        expect(result.errors).to eq([
          'Enum "happiness" contains no values'
        ])
      end
    end
  end
end
