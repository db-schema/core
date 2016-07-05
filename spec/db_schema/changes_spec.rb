require 'spec_helper'

RSpec.describe DbSchema::Changes do
  describe '.between' do
    context 'with tables being added and removed' do
      let(:users_fields) do
        [
          DbSchema::Definitions::Field::Integer.new(:id),
          DbSchema::Definitions::Field::Varchar.new(:name, length: 20),
          DbSchema::Definitions::Field::Varchar.new(:email),
          DbSchema::Definitions::Field::Integer.new(:city_id)
        ]
      end

      let(:users_checks) do
        [
          DbSchema::Definitions::CheckConstraint.new(
            name:      :name_or_email,
            condition: 'name IS NOT NULL OR email IS NOT NULL'
          )
        ]
      end

      let(:users_foreign_keys) do
        [
          DbSchema::Definitions::ForeignKey.new(
            name:   :users_city_id_fkey,
            fields: [:city_id],
            table:  :cities
          )
        ]
      end

      let(:posts_fields) do
        [
          DbSchema::Definitions::Field::Integer.new(:id),
          DbSchema::Definitions::Field::Varchar.new(:title)
        ]
      end

      let(:posts_foreign_keys) do
        [
          DbSchema::Definitions::ForeignKey.new(
            name:   :posts_city_id_fkey,
            fields: [:city_id],
            table:  :cities
          )
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
          DbSchema::Definitions::Table.new(
            :users,
            fields:       users_fields,
            checks:       users_checks,
            foreign_keys: users_foreign_keys
          ),
          DbSchema::Definitions::Table.new(:cities, fields: cities_fields)
        ]
      end

      let(:actual_schema) do
        [
          DbSchema::Definitions::Table.new(
            :posts,
            fields:       posts_fields,
            foreign_keys: posts_foreign_keys
          ),
          DbSchema::Definitions::Table.new(:cities, fields: cities_fields)
        ]
      end

      it 'returns changes between two schemas' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes).to include(
          DbSchema::Changes::CreateTable.new(
            :users,
            fields: users_fields,
            checks: users_checks
          )
        )
        expect(changes).to include(DbSchema::Changes::DropTable.new(:posts))
        expect(changes).to include(
          DbSchema::Changes::CreateForeignKey.new(:users, users_foreign_keys.first)
        )
        expect(changes).to include(
          DbSchema::Changes::DropForeignKey.new(:posts, posts_foreign_keys.first.name)
        )
      end

      it 'ignores matching tables' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes.count).to eq(4)
      end
    end

    context 'with table changed' do
      let(:desired_schema) do
        fields = [
          DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
          DbSchema::Definitions::Field::Varchar.new(:name, length: 60),
          DbSchema::Definitions::Field::Varchar.new(:email, null: false),
          DbSchema::Definitions::Field::Varchar.new(:type, null: false, default: 'guest'),
          DbSchema::Definitions::Field::Integer.new(:city_id),
          DbSchema::Definitions::Field::Integer.new(:country_id),
          DbSchema::Definitions::Field::Integer.new(:group_id),
          DbSchema::Definitions::Field::Custom.new(:status, type_name: :user_status)
        ]

        indices = [
          DbSchema::Definitions::Index.new(
            name:      :users_name_index,
            fields:    [DbSchema::Definitions::Index::Field.new(:name)],
            unique:    true,
            condition: 'email IS NOT NULL'
          ),
          DbSchema::Definitions::Index.new(
            name:   :users_email_index,
            fields: [DbSchema::Definitions::Index::Field.new(:email, order: :desc)],
            type:   :hash,
            unique: true
          )
        ]

        checks = [
          DbSchema::Definitions::CheckConstraint.new(
            name:      :location_check,
            condition: 'city_id IS NOT NULL OR country_id IS NOT NULL'
          )
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
            checks:       checks,
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
          DbSchema::Definitions::Field::Integer.new(:group_id),
          DbSchema::Definitions::Field::Integer.new(:status)
        ]

        indices = [
          DbSchema::Definitions::Index.new(
            name: :users_name_index,
            fields: [DbSchema::Definitions::Index::Field.new(:name)]
          ),
          DbSchema::Definitions::Index.new(
            name: :users_type_index,
            fields: [DbSchema::Definitions::Index::Field.new(:type)]
          )
        ]

        checks = [
          DbSchema::Definitions::CheckConstraint.new(
            name:      :location_check,
            condition: 'city_id IS NOT NULL AND country_id IS NOT NULL'
          )
        ]

        foreign_keys = [
          DbSchema::Definitions::ForeignKey.new(
            name:   :users_country_id_fkey,
            fields: [:country_id],
            table:  :countries
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
            checks:       checks,
            foreign_keys: foreign_keys
          )
        ]
      end

      it 'returns changes between two schemas' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        alter_table = changes.first
        expect(alter_table).to be_a(DbSchema::Changes::AlterTable)

        expect(alter_table.fields).to eq([
          DbSchema::Changes::CreatePrimaryKey.new(:id),
          DbSchema::Changes::AlterColumnType.new(:name, new_type: :varchar, length: 60),
          DbSchema::Changes::CreateColumn.new(DbSchema::Definitions::Field::Varchar.new(:email, null: false)),
          DbSchema::Changes::AlterColumnType.new(:type, new_type: :varchar),
          DbSchema::Changes::DisallowNull.new(:type),
          DbSchema::Changes::AlterColumnDefault.new(:type, new_default: 'guest'),
          DbSchema::Changes::AlterColumnType.new(:status, new_type: :user_status),
          DbSchema::Changes::DropColumn.new(:age)
        ])

        expect(alter_table.indices).to eq([
          DbSchema::Changes::DropIndex.new(:users_name_index),
          DbSchema::Changes::CreateIndex.new(
            name:      :users_name_index,
            fields:    [DbSchema::Definitions::Index::Field.new(:name)],
            unique:    true,
            condition: 'email IS NOT NULL'
          ),
          DbSchema::Changes::CreateIndex.new(
            name:   :users_email_index,
            fields: [DbSchema::Definitions::Index::Field.new(:email, order: :desc)],
            type:   :hash,
            unique: true
          ),
          DbSchema::Changes::DropIndex.new(:users_type_index)
        ])

        expect(alter_table.checks).to eq([
          DbSchema::Changes::DropCheckConstraint.new(:location_check),
          DbSchema::Changes::CreateCheckConstraint.new(
            name:      :location_check,
            condition: 'city_id IS NOT NULL OR country_id IS NOT NULL'
          )
        ])

        expect(changes.drop(1)).to eq([
          DbSchema::Changes::CreateForeignKey.new(
            :users,
            DbSchema::Definitions::ForeignKey.new(
              name:   :users_city_id_fkey,
              fields: [:city_id],
              table:  :cities
            )
          ),
          DbSchema::Changes::DropForeignKey.new(:users, :users_group_id_fkey),
          DbSchema::Changes::CreateForeignKey.new(
            :users,
            DbSchema::Definitions::ForeignKey.new(
              name:      :users_group_id_fkey,
              fields:    [:group_id],
              table:     :groups,
              on_delete: :cascade
            )
          ),
          DbSchema::Changes::DropForeignKey.new(:users, :users_country_id_fkey)
        ])
      end

      context 'with just foreign keys changed' do
        let(:posts_fields) do
          [
            DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
            DbSchema::Definitions::Field::Varchar.new(:title),
            DbSchema::Definitions::Field::Integer.new(:user_id, null: false),
            DbSchema::Definitions::Field::Integer.new(:category_id, null: false)
          ]
        end

        let(:desired_schema) do
          [
            DbSchema::Definitions::Table.new(
              :posts,
              fields: posts_fields,
              foreign_keys: [
                DbSchema::Definitions::ForeignKey.new(
                  name:   :posts_user_id_fkey,
                  fields: [:user_id],
                  table:  :users
                )
              ]
            )
          ]
        end

        let(:actual_schema) do
          [
            DbSchema::Definitions::Table.new(
              :posts,
              fields: posts_fields,
              foreign_keys: [
                DbSchema::Definitions::ForeignKey.new(
                  name:   :posts_category_id_fkey,
                  fields: [:category_id],
                  table:  :categories
                )
              ]
            )
          ]
        end

        it 'returns only foreign key operations' do
          changes = DbSchema::Changes.between(desired_schema, actual_schema)

          expect(changes.count).to eq(2)
          expect(changes.map(&:class)).to eq([
            DbSchema::Changes::CreateForeignKey,
            DbSchema::Changes::DropForeignKey
          ])
        end
      end
    end

    context 'with enums added and removed' do
      let(:desired_schema) do
        [
          DbSchema::Definitions::Enum.new(:happiness, %i(good ok bad))
        ]
      end

      let(:actual_schema) do
        [
          DbSchema::Definitions::Enum.new(:skill, %i(beginner advanced expert))
        ]
      end

      it 'returns changes between schemas' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes.count).to eq(2)
        expect(changes).to include(
          DbSchema::Changes::CreateEnum.new(:happiness, %i(good ok bad))
        )
        expect(changes).to include(
          DbSchema::Changes::DropEnum.new(:skill)
        )
      end
    end

    context 'with enums changed' do
      let(:desired_schema) do
        [
          DbSchema::Definitions::Enum.new(:happiness, desired_values)
        ]
      end

      let(:actual_schema) do
        [
          DbSchema::Definitions::Enum.new(:happiness, actual_values)
        ]
      end

      context 'by adding new values' do
        context 'to the end' do
          let(:desired_values) { %i(good ok bad unhappy) }
          let(:actual_values)  { %i(good ok bad) }

          it 'returns a Changes::AddValueToEnum' do
            changes = DbSchema::Changes.between(desired_schema, actual_schema)

            expect(changes.count).to eq(1)
            expect(changes).to eq([
              DbSchema::Changes::AddValueToEnum.new(:happiness, :unhappy)
            ])
          end
        end

        context 'to the beginning' do
          let(:desired_values) { %i(happy good ok bad) }
          let(:actual_values)  { %i(good ok bad) }

          it 'returns a Changes::AddValueToEnum with before: :good' do
            changes = DbSchema::Changes.between(desired_schema, actual_schema)

            expect(changes).to eq([
              DbSchema::Changes::AddValueToEnum.new(:happiness, :happy, before: :good)
            ])
          end
        end

        context 'into the middle' do
          let(:desired_values) { %i(good ok worried bad) }
          let(:actual_values)  { %i(good ok bad) }

          it 'returns a Changes::AddValueToEnum with before: :bad' do
            changes = DbSchema::Changes.between(desired_schema, actual_schema)

            expect(changes).to eq([
              DbSchema::Changes::AddValueToEnum.new(:happiness, :worried, before: :bad)
            ])
          end
        end

        context 'with multiple values' do
          let(:desired_values) { %i(happy good ok worried bad unhappy) }
          let(:actual_values)  { %i(good ok bad) }

          it 'returns appropriate AddValueToEnum objects in reverse order' do
            changes = DbSchema::Changes.between(desired_schema, actual_schema)

            expect(changes).to eq([
              DbSchema::Changes::AddValueToEnum.new(:happiness, :unhappy),
              DbSchema::Changes::AddValueToEnum.new(:happiness, :worried, before: :bad),
              DbSchema::Changes::AddValueToEnum.new(:happiness, :happy, before: :good)
            ])
          end
        end
      end

      context 'by removing values' do
        let(:desired_values) { %i(happy ok unhappy) }
        let(:actual_values)  { %i(happy good ok bad unhappy) }

        it 'raises a DbSchema::UnsupportedOperation' do
          expect {
            DbSchema::Changes.between(desired_schema, actual_schema)
          }.to raise_error(DbSchema::UnsupportedOperation)
        end
      end

      context 'by reordering values' do
        let(:desired_values) { %i(happy ok moderate sad) }
        let(:actual_values)  { %i(moderate ok sad) }

        it 'raises a DbSchema::UnsupportedOperation' do
          expect {
            DbSchema::Changes.between(desired_schema, actual_schema)
          }.to raise_error(DbSchema::UnsupportedOperation)
        end
      end
    end
  end
end
