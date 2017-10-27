require 'spec_helper'

RSpec.describe DbSchema::Reader do
  let(:database) do
    Sequel.connect(adapter: 'postgres', database: 'db_schema_test').tap do |db|
      db.extension :pg_enum
      db.extension :pg_array
    end
  end

  describe '.read_schema' do
    context 'on an empty database' do
      it 'returns an empty schema' do
        expect(subject.read_schema(database)).to eq(DbSchema::Definitions::Schema.new)
      end
    end

    context 'on a non-empty database' do
      before(:each) do
        database.create_enum :rainbow, %w(red orange yellow green blue purple)

        database.run('CREATE EXTENSION hstore')

        database.create_table :users do
          column :id, :serial, primary_key: true
          column :name, :varchar, null: false, unique: true
          column :email, :varchar, default: 'mail@example.com', size: 250
          column :admin, :boolean, null: false, default: false
          column :age, :integer, default: 20
          column :lat, :numeric, size: [6, 3]
          column :lng, :decimal, size: [7, 4], default: 3.45
          column :created_at, :timestamptz, default: Time.new(2016, 4, 28, 1, 25, 0, '+03:00')
          column :updated_at, :timestamp,   default: Sequel.function(:now)
          column :period, 'interval HOUR'
          column :other_period, :interval
          column :some_bit, :bit
          column :several_bits, :bit, size: 5
          column :variable_bits, :varbit
          column :limited_variable_bits, :varbit, size: 150
          column :numbers, 'integer[]'
          column :color, :rainbow, default: 'red'
          column :previous_colors, 'rainbow[]', default: []

          index [
            :email,
            Sequel.desc(:name),
            Sequel.asc(:lat, nulls: :first),
            Sequel.desc(:lng, nulls: :last)
          ], name: :users_index, unique: true, where: 'email IS NOT NULL'
          index [:name], type: :spgist
          index [
            Sequel.asc(Sequel.lit('lower(email)')),
            Sequel.asc(:age),
            Sequel.desc(Sequel.lit('lower(name)'))
          ], name: :users_expression_index

          constraint :is_adult, 'age > 18'
        end

        database.create_table :posts do
          column :id, :integer, primary_key: true
          column :title, :varchar
          column :user_id, :integer, null: false
          column :user_name, :varchar
          column :created_on, :date, default: Date.new(2016, 4, 28)
          column :created_at, :timetz

          index :user_id

          foreign_key [:user_id], :users, on_delete: :set_null, deferrable: true
          foreign_key [:user_name], :users, key: [:name], name: :user_name_fkey, on_update: :cascade
        end
      end

      let(:schema) { subject.read_schema(database) }

      it 'reads field information' do
        users = schema.table(:users)
        posts = schema.table(:posts)

        expect(users.field(:id).type).to eq(:integer)
        expect(users.field(:id)).to be_primary_key

        expect(users.field(:name).type).to eq(:varchar)
        expect(users.field(:name)).not_to be_null
        expect(users.field(:name).default).to be_nil

        expect(users.field(:email).type).to eq(:varchar)
        expect(users.field(:email)).to be_null
        expect(users.field(:email).default).to eq('mail@example.com')
        expect(users.field(:email).options[:length]).to eq(250)

        expect(users.field(:admin).type).to eq(:boolean)
        expect(users.field(:admin)).not_to be_null
        expect(users.field(:admin).default).to eq(false)

        expect(users.field(:age).type).to eq(:integer)
        expect(users.field(:age).default).to eq(20)

        expect(users.field(:lat).type).to eq(:numeric)
        expect(users.field(:lat).options[:precision]).to eq(6)
        expect(users.field(:lat).options[:scale]).to eq(3)

        expect(users.field(:lng).type).to eq(:numeric)
        expect(users.field(:lng).default).to eq(3.45)
        expect(users.field(:lng).options[:precision]).to eq(7)
        expect(users.field(:lng).options[:scale]).to eq(4)

        expect(users.field(:created_at).type).to eq(:timestamptz)
        expect(users.field(:created_at).default).to eq(Time.new(2016, 4, 28, 1, 25, 0, '+03:00').getlocal)

        expect(users.field(:updated_at).type).to eq(:timestamp)
        expect(users.field(:updated_at).default).to eq(:'now()')

        expect(users.field(:period).type).to eq(:interval)
        expect(users.field(:period).options[:fields]).to eq(:hour)

        expect(users.field(:other_period).type).to eq(:interval)
        expect(users.field(:other_period).options[:fields]).to be_nil

        expect(users.field(:some_bit).type).to eq(:bit)
        expect(users.field(:some_bit).options[:length]).to eq(1)

        expect(users.field(:several_bits).type).to eq(:bit)
        expect(users.field(:several_bits).options[:length]).to eq(5)

        expect(users.field(:variable_bits).type).to eq(:varbit)
        expect(users.field(:variable_bits).options[:length]).to be_nil

        expect(users.field(:limited_variable_bits).type).to eq(:varbit)
        expect(users.field(:limited_variable_bits).options[:length]).to eq(150)

        expect(users.field(:numbers).type).to eq(:array)
        expect(users.field(:numbers).options[:element_type]).to eq(:integer)

        expect(users.field(:color)).to be_custom
        expect(users.field(:color).type).to eq(:rainbow)
        expect(users.field(:color).default).to eq('red')

        expect(users.field(:previous_colors)).to be_array
        expect(users.field(:previous_colors).options[:element_type]).to eq(:rainbow)
        expect(users.field(:previous_colors).default).to eq(:'ARRAY[]::rainbow[]')

        expect(posts.field(:id).type).to eq(:integer)
        expect(posts.field(:id)).to be_primary_key

        expect(posts.field(:title).type).to eq(:varchar)
        expect(posts.field(:title)).to be_null

        expect(posts.field(:user_id).type).to eq(:integer)
        expect(posts.field(:user_id)).not_to be_null

        expect(posts.field(:created_on).type).to eq(:date)
        expect(posts.field(:created_on).default).to eq(Date.new(2016, 4, 28))

        expect(posts.field(:created_at).type).to eq(:timetz)
      end

      it 'reads indexes' do
        users = schema.table(:users)
        posts = schema.table(:posts)

        expect(users.indices.count).to eq(4)

        expect(users.index(:users_index).columns).to eq([
          DbSchema::Definitions::Index::TableField.new(:email),
          DbSchema::Definitions::Index::TableField.new(:name, order: :desc),
          DbSchema::Definitions::Index::TableField.new(:lat, nulls: :first),
          DbSchema::Definitions::Index::TableField.new(:lng, order: :desc, nulls: :last)
        ])
        expect(users.index(:users_index)).to be_unique
        expect(users.index(:users_index).type).to eq(:btree)
        expect(users.index(:users_index).condition).to eq('email IS NOT NULL')

        expect(users.index(:users_expression_index).columns).to eq([
          DbSchema::Definitions::Index::Expression.new('lower(email::text)'),
          DbSchema::Definitions::Index::TableField.new(:age),
          DbSchema::Definitions::Index::Expression.new('lower(name::text)', order: :desc)
        ])

        expect(users.index(:users_name_index).columns).to eq([
          DbSchema::Definitions::Index::TableField.new(:name)
        ])
        expect(users.index(:users_name_index).type).to eq(:spgist)

        expect(posts.indices.count).to eq(1)
        expect(posts.index(:posts_user_id_index).columns).to eq([
          DbSchema::Definitions::Index::TableField.new(:user_id)
        ])
        expect(posts.index(:posts_user_id_index)).not_to be_unique
      end

      it 'reads check constraints' do
        users = schema.table(:users)

        expect(users.checks.count).to eq(1)
        expect(users.check(:is_adult).condition).to eq('age > 18')
      end

      it 'reads foreign keys' do
        posts = schema.table(:posts)

        expect(posts.foreign_keys.count).to eq(2)

        expect(posts.foreign_key(:posts_user_id_fkey).fields).to eq([:user_id])
        expect(posts.foreign_key(:posts_user_id_fkey).table).to eq(:users)
        expect(posts.foreign_key(:posts_user_id_fkey).references_primary_key?).to eq(true)
        expect(posts.foreign_key(:posts_user_id_fkey).on_delete).to eq(:set_null)
        expect(posts.foreign_key(:posts_user_id_fkey).on_update).to eq(:no_action)
        expect(posts.foreign_key(:posts_user_id_fkey)).to be_deferrable

        expect(posts.foreign_key(:user_name_fkey).fields).to eq([:user_name])
        expect(posts.foreign_key(:user_name_fkey).table).to eq(:users)
        expect(posts.foreign_key(:user_name_fkey).keys).to eq([:name])
        expect(posts.foreign_key(:user_name_fkey).on_delete).to eq(:no_action)
        expect(posts.foreign_key(:user_name_fkey).on_update).to eq(:cascade)
        expect(posts.foreign_key(:user_name_fkey)).not_to be_deferrable
      end

      it 'reads enum types' do
        expect(schema.enums.count).to eq(1)
        expect(schema.enum(:rainbow).values).to eq(%i(red orange yellow green blue purple))
      end

      it 'reads extensions' do
        expect(schema.extensions.count).to eq(1)
        expect(schema.extensions.first.name).to eq(:hstore)
      end

      after(:each) do
        database.drop_table(:posts)
        database.drop_table(:users)
        database.drop_enum(:rainbow)
        database.run('DROP EXTENSION hstore')
      end
    end
  end
end
