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
        DbSchema::Definitions::Schema.new(
          tables: [
            DbSchema::Definitions::Table.new(
              :users,
              fields:       users_fields,
              checks:       users_checks,
              foreign_keys: users_foreign_keys
            ),
            DbSchema::Definitions::Table.new(:cities, fields: cities_fields)
          ]
        )
      end

      let(:actual_schema) do
        DbSchema::Definitions::Schema.new(
          tables: [
            DbSchema::Definitions::Table.new(
              :posts,
              fields:       posts_fields,
              foreign_keys: posts_foreign_keys
            ),
            DbSchema::Definitions::Table.new(:cities, fields: cities_fields)
          ]
        )
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
          DbSchema::Definitions::Field::Custom.class_for(:user_status).new(:status)
        ]

        indices = [
          DbSchema::Definitions::Index.new(
            name:      :users_name_index,
            columns:   [DbSchema::Definitions::Index::Expression.new('lower(name)')],
            unique:    true,
            condition: 'email IS NOT NULL'
          ),
          DbSchema::Definitions::Index.new(
            name:    :users_email_index,
            columns: [DbSchema::Definitions::Index::TableField.new(:email, order: :desc)],
            type:    :hash,
            unique:  true
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

        DbSchema::Definitions::Schema.new(
          tables: [
            DbSchema::Definitions::Table.new(
              :users,
              fields:       fields,
              indices:      indices,
              checks:       checks,
              foreign_keys: foreign_keys
            )
          ]
        )
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
            name:    :users_name_index,
            columns: [DbSchema::Definitions::Index::TableField.new(:name)]
          ),
          DbSchema::Definitions::Index.new(
            name:    :users_type_index,
            columns: [DbSchema::Definitions::Index::TableField.new(:type)]
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

        DbSchema::Definitions::Schema.new(
          tables: [
            DbSchema::Definitions::Table.new(
              :users,
              fields:       fields,
              indices:      indices,
              checks:       checks,
              foreign_keys: foreign_keys
            )
          ]
        )
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
            columns:   [DbSchema::Definitions::Index::Expression.new('lower(name)')],
            unique:    true,
            condition: 'email IS NOT NULL'
          ),
          DbSchema::Changes::CreateIndex.new(
            name:    :users_email_index,
            columns: [DbSchema::Definitions::Index::TableField.new(:email, order: :desc)],
            type:    :hash,
            unique:  true
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
          DbSchema::Definitions::Schema.new(
            tables: [
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
          )
        end

        let(:actual_schema) do
          DbSchema::Definitions::Schema.new(
            tables: [
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
          )
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
        DbSchema::Definitions::Schema.new(
          enums: [
            DbSchema::Definitions::Enum.new(:happiness, %i(good ok bad))
          ]
        )
      end

      let(:actual_schema) do
        DbSchema::Definitions::Schema.new(
          enums: [
            DbSchema::Definitions::Enum.new(:skill, %i(beginner advanced expert))
          ]
        )
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
      let(:desired_values) { %i(happy good ok moderate bad) }
      let(:actual_values)  { %i(good moderate ok bad unhappy) }

      let(:desired_schema) do
        DbSchema::Definitions::Schema.new(
          enums: [
            DbSchema::Definitions::Enum.new(:happiness, desired_values)
          ]
        )
      end

      let(:actual_schema) do
        DbSchema::Definitions::Schema.new(
          enums: [
            DbSchema::Definitions::Enum.new(:happiness, actual_values)
          ]
        )
      end

      it 'returns a Changes::AlterEnumValues' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes).to eq([
          DbSchema::Changes::AlterEnumValues.new(:happiness, desired_values, [])
        ])
      end

      context 'when the enum is used in a column' do
        let(:desired_schema) do
          DbSchema::Definitions::Schema.new(
            tables: [
              DbSchema::Definitions::Table.new(:people,
                fields: [
                  DbSchema::Definitions::Field::Custom.class_for(:happiness).new(:happiness, default: 'good')
                ]
              )
            ],
            enums: [
              DbSchema::Definitions::Enum.new(:happiness, desired_values)
            ]
          )
        end

        let(:actual_schema) do
          DbSchema::Definitions::Schema.new(
            tables: [
              DbSchema::Definitions::Table.new(:people,
                fields: [
                  DbSchema::Definitions::Field::Custom.class_for(:happiness).new(:happiness, default: 'happy')
                ]
              )
            ],
            enums: [
              DbSchema::Definitions::Enum.new(:happiness, actual_values)
            ]
          )
        end

        it 'returns a Changes::AlterEnumValues with existing enum fields' do
          changes = DbSchema::Changes.between(desired_schema, actual_schema)

          expect(changes).to eq([
            DbSchema::Changes::AlterTable.new(
              :people,
              fields: [
                DbSchema::Changes::AlterColumnDefault.new(:happiness, new_default: 'good')
              ]
            ),
            DbSchema::Changes::AlterEnumValues.new(
              :happiness,
              desired_values,
              [[:people, :happiness, 'good']]
            )
          ])
        end
      end
    end

    context 'with extensions added and removed' do
      let(:desired_schema) do
        DbSchema::Definitions::Schema.new(
          extensions: [
            DbSchema::Definitions::Extension.new(:ltree)
          ]
        )
      end

      let(:actual_schema) do
        DbSchema::Definitions::Schema.new(
          extensions: [
            DbSchema::Definitions::Extension.new(:hstore)
          ]
        )
      end

      it 'returns changes between schemas' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes.count).to eq(2)
        expect(changes).to include(
          DbSchema::Changes::CreateExtension.new(:ltree)
        )
        expect(changes).to include(
          DbSchema::Changes::DropExtension.new(:hstore)
        )
      end
    end
  end
end
