RSpec.describe DbSchema::Changes do
  describe '.between' do
    context 'with tables being added and removed' do
      let(:users_fields) do
        [
          DbSchema::Definitions::Field::Serial.new(:id),
          DbSchema::Definitions::Field::Varchar.new(:name, length: 20),
          DbSchema::Definitions::Field::Varchar.new(:email),
          DbSchema::Definitions::Field::Integer.new(:city_id)
        ]
      end

      let(:users_indexes) do
        [
          DbSchema::Definitions::Index.new(
            name: :users_pkey,
            columns: [
              DbSchema::Definitions::Index::TableField.new(:id)
            ],
            primary: true
          )
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
              indexes:      users_indexes,
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

        expect(changes).to eq(
          [
            DbSchema::Operations::DropForeignKey.new(:posts, posts_foreign_keys.first.name),
            DbSchema::Operations::CreateTable.new(
              DbSchema::Definitions::Table.new(
                :users,
                fields:       users_fields,
                indexes:      users_indexes,
                checks:       users_checks,
                foreign_keys: users_foreign_keys
              )
            ),
            DbSchema::Operations::DropTable.new(:posts),
            DbSchema::Operations::CreateForeignKey.new(:users, users_foreign_keys.first)
          ]
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
          DbSchema::Definitions::Field::Serial.new(:id),
          DbSchema::Definitions::Field::Varchar.new(:name, length: 60),
          DbSchema::Definitions::Field::Varchar.new(:email, null: false),
          DbSchema::Definitions::Field::Varchar.new(:type, null: false, default: 'guest'),
          DbSchema::Definitions::Field::Integer.new(:city_id),
          DbSchema::Definitions::Field::Integer.new(:country_id),
          DbSchema::Definitions::Field::Integer.new(:group_id),
          DbSchema::Definitions::Field::Custom.class_for(:user_status).new(:status)
        ]

        indexes = [
          DbSchema::Definitions::Index.new(
            name:    :users_pkey,
            columns: [DbSchema::Definitions::Index::TableField.new(:id)],
            primary: true
          ),
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
            name:      :min_name_length_check,
            condition: 'char_length(name) > 5'
          ),
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
              indexes:      indexes,
              checks:       checks,
              foreign_keys: foreign_keys
            )
          ]
        )
      end

      let(:actual_schema) do
        fields = [
          DbSchema::Definitions::Field::Serial.new(:id),
          DbSchema::Definitions::Field::Varchar.new(:name),
          DbSchema::Definitions::Field::Integer.new(:age),
          DbSchema::Definitions::Field::Integer.new(:type),
          DbSchema::Definitions::Field::Integer.new(:city_id),
          DbSchema::Definitions::Field::Integer.new(:country_id),
          DbSchema::Definitions::Field::Integer.new(:group_id),
          DbSchema::Definitions::Field::Integer.new(:status)
        ]

        indexes = [
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
            name:      :min_age_check,
            condition: 'age >= 18'
          ),
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
              indexes:      indexes,
              checks:       checks,
              foreign_keys: foreign_keys
            )
          ]
        )
      end

      it 'returns changes between two schemas' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        drop_group_id, drop_country_id, alter_table, create_city_id, create_group_id = changes
        expect(alter_table).to be_a(DbSchema::Operations::AlterTable)

        expect(alter_table.changes).to eq([
          DbSchema::Operations::DropCheckConstraint.new(:location_check),
          DbSchema::Operations::DropCheckConstraint.new(:min_age_check),
          DbSchema::Operations::DropIndex.new(:users_name_index, false),
          DbSchema::Operations::DropIndex.new(:users_type_index, false),
          DbSchema::Operations::DropColumn.new(:age),
          DbSchema::Operations::AlterColumnType.new(:name, old_type: :varchar, new_type: :varchar, length: 60),
          DbSchema::Operations::AlterColumnType.new(:type, old_type: :integer, new_type: :varchar),
          DbSchema::Operations::AlterColumnType.new(:status, old_type: :integer, new_type: :user_status),
          DbSchema::Operations::DisallowNull.new(:type),
          DbSchema::Operations::AlterColumnDefault.new(:type, new_default: 'guest'),
          DbSchema::Operations::CreateColumn.new(DbSchema::Definitions::Field::Varchar.new(:email, null: false)),
          DbSchema::Operations::CreateIndex.new(
            DbSchema::Definitions::Index.new(
              name:    :users_pkey,
              columns: [DbSchema::Definitions::Index::TableField.new(:id)],
              primary: true
            )
          ),
          DbSchema::Operations::CreateIndex.new(
            DbSchema::Definitions::Index.new(
              name:      :users_name_index,
              columns:   [DbSchema::Definitions::Index::Expression.new('lower(name)')],
              unique:    true,
              condition: 'email IS NOT NULL'
            )
          ),
          DbSchema::Operations::CreateIndex.new(
            DbSchema::Definitions::Index.new(
              name:    :users_email_index,
              columns: [DbSchema::Definitions::Index::TableField.new(:email, order: :desc)],
              type:    :hash,
              unique:  true
            )
          ),
          DbSchema::Operations::CreateCheckConstraint.new(
            DbSchema::Definitions::CheckConstraint.new(
              name:      :min_name_length_check,
              condition: 'char_length(name) > 5'
            )
          ),
          DbSchema::Operations::CreateCheckConstraint.new(
            DbSchema::Definitions::CheckConstraint.new(
              name:      :location_check,
              condition: 'city_id IS NOT NULL OR country_id IS NOT NULL'
            )
          )
        ])

        expect(drop_group_id).to eq(
          DbSchema::Operations::DropForeignKey.new(:users, :users_group_id_fkey)
        )
        expect(drop_country_id).to eq(
          DbSchema::Operations::DropForeignKey.new(:users, :users_country_id_fkey)
        )

        expect(create_city_id).to eq(
          DbSchema::Operations::CreateForeignKey.new(
            :users,
            DbSchema::Definitions::ForeignKey.new(
              name:   :users_city_id_fkey,
              fields: [:city_id],
              table:  :cities
            )
          )
        )
        expect(create_group_id).to eq(
          DbSchema::Operations::CreateForeignKey.new(
            :users,
            DbSchema::Definitions::ForeignKey.new(
              name:      :users_group_id_fkey,
              fields:    [:group_id],
              table:     :groups,
              on_delete: :cascade
            )
          ),
        )
      end

      context 'with primary key removed' do
        before(:each) do
          actual_schema.table(:users).indexes.unshift(desired_schema.table(:users).indexes.shift)
        end

        it 'returns changes between two schemas' do
          changes = DbSchema::Changes.between(desired_schema, actual_schema)
          expect(changes.count).to eq(5)

          alter_table = changes[2]
          expect(alter_table).to be_a(DbSchema::Operations::AlterTable)
          expect(alter_table.changes).to include(DbSchema::Operations::DropIndex.new(:users_pkey, true))
        end
      end

      context 'with just foreign keys changed' do
        let(:posts_fields) do
          [
            DbSchema::Definitions::Field::Serial.new(:id),
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
            DbSchema::Operations::DropForeignKey,
            DbSchema::Operations::CreateForeignKey
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
          DbSchema::Operations::CreateEnum.new(
            DbSchema::Definitions::Enum.new(:happiness, %i(good ok bad))
          )
        )
        expect(changes).to include(
          DbSchema::Operations::DropEnum.new(:skill)
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

      it 'returns a Operations::AlterEnumValues' do
        changes = DbSchema::Changes.between(desired_schema, actual_schema)

        expect(changes).to eq([
          DbSchema::Operations::AlterEnumValues.new(:happiness, desired_values, [])
        ])
      end

      context 'when the enum is used in a column' do
        let(:desired_schema) do
          DbSchema::Definitions::Schema.new(
            tables: [
              DbSchema::Definitions::Table.new(:people,
                fields: [
                  DbSchema::Definitions::Field::Custom.class_for(:happiness).new(:happiness, default: 'happy')
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
                  DbSchema::Definitions::Field::Custom.class_for(:happiness).new(:happiness, default: 'unhappy')
                ]
              )
            ],
            enums: [
              DbSchema::Definitions::Enum.new(:happiness, actual_values)
            ]
          )
        end

        it 'returns a Operations::AlterEnumValues with existing enum fields' do
          changes = DbSchema::Changes.between(desired_schema, actual_schema)

          expect(changes).to eq([
            DbSchema::Operations::AlterEnumValues.new(
              :happiness,
              desired_values,
              [
                {
                  table_name:  :people,
                  field_name:  :happiness,
                  new_default: 'happy',
                  array:       false
                }
              ]
            ),
            DbSchema::Operations::AlterTable.new(
              :people,
              [
                DbSchema::Operations::AlterColumnDefault.new(:happiness, new_default: 'happy')
              ]
            )
          ])
        end

        context 'in an enum array' do
          let(:desired_schema) do
            DbSchema::Definitions::Schema.new(
              tables: [
                DbSchema::Definitions::Table.new(:users,
                  fields: [
                    DbSchema::Definitions::Field::Array.new(:roles, element_type: :user_role, default: '{}')
                  ]
                )
              ],
              enums: [
                DbSchema::Definitions::Enum.new(:user_role, [:user, :admin])
              ]
            )
          end

          let(:actual_schema) do
            DbSchema::Definitions::Schema.new(
              tables: [
                DbSchema::Definitions::Table.new(:users,
                  fields: [
                    DbSchema::Definitions::Field::Array.new(:roles, element_type: :user_role, default: '{}')
                  ]
                )
              ],
              enums: [
                DbSchema::Definitions::Enum.new(:user_role, [:guest, :user, :admin])
              ]
            )
          end

          it 'returns a Operations::AlterEnumValues with existing enum array fields' do
            changes = DbSchema::Changes.between(desired_schema, actual_schema)

            expect(changes).to eq([
              DbSchema::Operations::AlterEnumValues.new(
                :user_role,
                [:user, :admin],
                [
                  {
                    table_name:  :users,
                    field_name:  :roles,
                    new_default: '{}',
                    array:       true
                  }
                ]
              )
            ])
          end
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
          DbSchema::Operations::CreateExtension.new(
            DbSchema::Definitions::Extension.new(:ltree)
          )
        )
        expect(changes).to include(
          DbSchema::Operations::DropExtension.new(:hstore)
        )
      end
    end
  end
end
