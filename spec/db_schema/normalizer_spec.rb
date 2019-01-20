RSpec.describe DbSchema::Normalizer do
  let(:database) do
    Sequel.connect(adapter: 'postgres', database: 'db_schema_test').tap do |db|
      db.extension :pg_enum
      db.extension :pg_array
    end
  end

  let(:enums) do
    [
      DbSchema::Definitions::Enum.new(:happiness, %i(good ok bad)),
      DbSchema::Definitions::Enum.new(:user_status, %i(guest registered)),
      DbSchema::Definitions::Enum.new(:user_role, %i(user))
    ]
  end

  let(:extensions) do
    [
      DbSchema::Definitions::Extension.new(:ltree),
      DbSchema::Definitions::Extension.new(:hstore)
    ]
  end

  let(:raw_table) do
    DbSchema::Definitions::Table.new(
      :users,
      fields: [
        DbSchema::Definitions::Field::Serial.new(:id),
        DbSchema::Definitions::Field::Varchar.new(:name, null: false),
        DbSchema::Definitions::Field::Integer.new(:group_id),
        DbSchema::Definitions::Field::Integer.new(:age, default: :'18 + 5'),
        DbSchema::Definitions::Field::Hstore.new(:data),
        DbSchema::Definitions::Field::Custom.class_for(:happiness).new(:happiness, default: field_default),
        DbSchema::Definitions::Field::Array.new(:roles, element_type: :user_role, default: '{user}'),
        DbSchema::Definitions::Field::Ltree.new(:path),
        DbSchema::Definitions::Field::Custom.class_for(:user_status).new(:user_status)
      ],
      indexes: [
        DbSchema::Definitions::Index.new(
          name: :users_pkey,
          columns: [
            DbSchema::Definitions::Index::TableField.new(:id)
          ],
          primary: true
        ),
        DbSchema::Definitions::Index.new(
          name: :lower_name_index,
          columns: [
            DbSchema::Definitions::Index::Expression.new('lower(name)')
          ],
          condition: index_condition
        )
      ],
      checks: [
        DbSchema::Definitions::CheckConstraint.new(name: :name_length, condition: check_condition)
      ],
      foreign_keys: [
        DbSchema::Definitions::ForeignKey.new(name: :users_group_id_fkey, fields: [:group_id], table: :groups)
      ]
    )
  end

  describe '.normalize_tables' do
    let(:field_default)   { 'ok' }
    let(:index_condition) { 'age != 18' }
    let(:check_condition) { 'char_length(name) > 4' }

    let(:schema) do
      DbSchema::Definitions::Schema.new(
        tables:     [raw_table],
        enums:      enums,
        extensions: extensions
      )
    end

    before(:each) do
      add_hstore = DbSchema::Operations::CreateExtension.new(
        DbSchema::Definitions::Extension.new(:hstore)
      )
      add_happiness = DbSchema::Operations::CreateEnum.new(
        DbSchema::Definitions::Enum.new(:happiness, %i(good bad))
      )
      add_role = DbSchema::Operations::CreateEnum.new(
        DbSchema::Definitions::Enum.new(:user_role, %i(admin))
      )

      fields = raw_table.fields.take(5)
      fields << DbSchema::Definitions::Field::Custom.class_for(:happiness).new(:happiness)
      fields << DbSchema::Definitions::Field::Array.new(:roles, element_type: :user_role, default: '{admin}')

      create_table = DbSchema::Operations::CreateTable.new(
        DbSchema::Definitions::Table.new(
          :users,
          fields:  fields,
          indexes: raw_table.indexes,
          checks:  raw_table.checks
        )
      )

      DbSchema::Runner.new([add_hstore, add_happiness, add_role, create_table], database).run!
    end

    it 'normalizes all tables in the schema passed in' do
      DbSchema::Normalizer.new(schema, database).normalize_tables

      expect(schema.tables.count).to eq(1)
      users = schema.table(:users)

      expect(users.field(:id).type).to eq(:serial)
      expect(users.field(:age).default).to eq(:'(18 + 5)')
      expect(users.field(:happiness).type).to eq(:happiness)
      expect(users.field(:roles)).to be_array
      expect(users.field(:roles).attributes[:element_type]).to eq(:user_role)
      expect(users.field(:roles).default).to eq('{user}')
      expect(users.primary_key.name).to eq(:users_pkey)
      expect(users.primary_key.columns).to eq([DbSchema::Definitions::Index::TableField.new(:id)])
      expect(users.index(:lower_name_index).columns.first.name).to eq('lower(name::text)')
      expect(users.index(:lower_name_index).condition).to eq('age <> 18')
      expect(users.check(:name_length).condition).to eq('char_length(name::text) > 4')
      expect(users.foreign_key(:users_group_id_fkey).fields).to eq([:group_id])
      expect(users.foreign_key(:users_group_id_fkey).table).to eq(:groups)
    end

    it 'rolls back all temporary tables' do
      expect {
        DbSchema::Normalizer.new(schema, database).normalize_tables
      }.not_to change { DbSchema::Reader.reader_for(database).read_tables.count }
    end

    context 'with enums used inside expressions' do
      let(:field_default)   { :"('ok'::text)::happiness" }
      let(:index_condition) { "happiness = 'good'::happiness" }
      let(:check_condition) { "char_length(name::text) > 4 OR happiness = 'good'::happiness" }

      it 'keeps the original type names inside expressions' do
        DbSchema::Normalizer.new(schema, database).normalize_tables

        users = schema.table(:users)
        expect(users.field(:happiness).default).to eq(field_default)
        expect(users.index(:lower_name_index).condition).to eq(index_condition)
        expect(users.check(:name_length).condition).to eq(check_condition)
      end
    end

    after(:each) do
      drop_table     = DbSchema::Operations::DropTable.new(:users)
      drop_happiness = DbSchema::Operations::DropEnum.new(:happiness)
      drop_role      = DbSchema::Operations::DropEnum.new(:user_role)
      drop_hstore    = DbSchema::Operations::DropExtension.new(:hstore)

      DbSchema::Runner.new([drop_table, drop_happiness, drop_role, drop_hstore], database).run!
    end
  end
end
