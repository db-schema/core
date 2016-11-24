require 'spec_helper'

RSpec.describe DbSchema::Reader do
  describe '.read_schema' do
    context 'on an empty database' do
      it 'returns an empty array' do
        expect(subject.read_schema).to eq(DbSchema::Definitions::Schema.new)
      end
    end

    context 'on a non-empty database' do
      before(:each) do
        DbSchema.connection.create_enum :rainbow, %w(red orange yellow green blue purple)

        DbSchema.connection.run('CREATE EXTENSION hstore')

        DbSchema.connection.create_table :users do
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

          index [
            :email,
            Sequel.desc(:name),
            Sequel.asc(:lat, nulls: :first),
            Sequel.desc(:lng, nulls: :last)
          ], unique: true, where: 'email IS NOT NULL'
          index [:name], type: :spgist
          index [
            Sequel.asc(Sequel.lit('lower(email)')),
            Sequel.asc(:age),
            Sequel.desc(Sequel.lit('lower(name)'))
          ], name: :users_expression_index

          constraint :is_adult, 'age > 18'
        end

        DbSchema.connection.create_table :posts do
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

      it 'returns the database schema' do
        schema = subject.read_schema

        users   = schema.tables.find { |table| table.name == :users }
        posts   = schema.tables.find { |table| table.name == :posts }
        rainbow = schema.enums.first
        hstore  = schema.extensions.first

        expect(rainbow.name).to eq(:rainbow)
        expect(rainbow.values).to eq(%i(red orange yellow green blue purple))

        expect(hstore.name).to eq(:hstore)

        id, name, email, admin, age, lat, lng, created_at, updated_at,
        period, other_period, some_bit, several_bits, variable_bits,
        limited_variable_bits, numbers, color = users.fields

        expect(id).to be_a(DbSchema::Definitions::Field::Integer)
        expect(id.name).to eq(:id)
        expect(id).to be_primary_key
        expect(name).to be_a(DbSchema::Definitions::Field::Varchar)
        expect(name.name).to eq(:name)
        expect(name).not_to be_null
        expect(name.default).to be_nil
        expect(email).to be_a(DbSchema::Definitions::Field::Varchar)
        expect(email.name).to eq(:email)
        expect(email).to be_null
        expect(email.default).to eq('mail@example.com')
        expect(email.options[:length]).to eq(250)
        expect(admin).to be_a(DbSchema::Definitions::Field::Boolean)
        expect(admin.name).to eq(:admin)
        expect(admin).not_to be_null
        expect(admin.default).to eq(false)
        expect(age).to be_a(DbSchema::Definitions::Field::Integer)
        expect(age.name).to eq(:age)
        expect(age.default).to eq(20)
        expect(lat).to be_a(DbSchema::Definitions::Field::Numeric)
        expect(lat.name).to eq(:lat)
        expect(lat.options[:precision]).to eq(6)
        expect(lat.options[:scale]).to eq(3)
        expect(lng).to be_a(DbSchema::Definitions::Field::Numeric)
        expect(lng.name).to eq(:lng)
        expect(lng.default).to eq(3.45)
        expect(lng.options[:precision]).to eq(7)
        expect(lng.options[:scale]).to eq(4)
        expect(created_at).to be_a(DbSchema::Definitions::Field::Timestamptz)
        expect(created_at.name).to eq(:created_at)
        expect(created_at.default).to eq(Time.new(2016, 4, 28, 1, 25, 0, '+03:00').getlocal)
        expect(updated_at).to be_a(DbSchema::Definitions::Field::Timestamp)
        expect(updated_at.name).to eq(:updated_at)
        expect(updated_at.default).to eq(:'now()')
        expect(period).to be_a(DbSchema::Definitions::Field::Interval)
        expect(period.name).to eq(:period)
        expect(period.options[:fields]).to eq(:hour)
        expect(other_period).to be_a(DbSchema::Definitions::Field::Interval)
        expect(other_period.name).to eq(:other_period)
        expect(other_period.options[:fields]).to be_nil
        expect(some_bit).to be_a(DbSchema::Definitions::Field::Bit)
        expect(some_bit.name).to eq(:some_bit)
        expect(some_bit.options[:length]).to eq(1)
        expect(several_bits).to be_a(DbSchema::Definitions::Field::Bit)
        expect(several_bits.name).to eq(:several_bits)
        expect(several_bits.options[:length]).to eq(5)
        expect(variable_bits).to be_a(DbSchema::Definitions::Field::Varbit)
        expect(variable_bits.name).to eq(:variable_bits)
        expect(variable_bits.options[:length]).to be_nil
        expect(limited_variable_bits).to be_a(DbSchema::Definitions::Field::Varbit)
        expect(limited_variable_bits.name).to eq(:limited_variable_bits)
        expect(limited_variable_bits.options[:length]).to eq(150)
        expect(numbers).to be_a(DbSchema::Definitions::Field::Array)
        expect(numbers.name).to eq(:numbers)
        expect(numbers.options[:element_type]).to eq(:integer)
        expect(color).to be_a(DbSchema::Definitions::Field::Custom)
        expect(color.name).to eq(:color)
        expect(color.type).to eq(:rainbow)
        expect(color.default).to eq('red')

        id, title, user_id, user_name, created_on, created_at = posts.fields
        expect(id).to be_a(DbSchema::Definitions::Field::Integer)
        expect(id.name).to eq(:id)
        expect(id).to be_primary_key
        expect(title).to be_a(DbSchema::Definitions::Field::Varchar)
        expect(title.name).to eq(:title)
        expect(title).to be_null
        expect(user_id).to be_a(DbSchema::Definitions::Field::Integer)
        expect(user_id.name).to eq(:user_id)
        expect(user_id).not_to be_null
        expect(created_on).to be_a(DbSchema::Definitions::Field::Date)
        expect(created_on.name).to eq(:created_on)
        expect(created_on.default).to eq(Date.new(2016, 4, 28))
        expect(created_at).to be_a(DbSchema::Definitions::Field::Timetz)
        expect(created_at.name).to eq(:created_at)

        expect(users.indices.count).to eq(4)
        email_index, expression_index, name_index, * = users.indices

        expect(email_index.columns).to eq([
          DbSchema::Definitions::Index::TableField.new(:email),
          DbSchema::Definitions::Index::TableField.new(:name, order: :desc),
          DbSchema::Definitions::Index::TableField.new(:lat, nulls: :first),
          DbSchema::Definitions::Index::TableField.new(:lng, order: :desc, nulls: :last)
        ])
        expect(email_index).to be_unique
        expect(email_index.type).to eq(:btree)
        expect(email_index.condition).to eq('email IS NOT NULL')

        expect(expression_index.columns).to eq([
          DbSchema::Definitions::Index::Expression.new('lower(email::text)'),
          DbSchema::Definitions::Index::TableField.new(:age),
          DbSchema::Definitions::Index::Expression.new('lower(name::text)', order: :desc)
        ])

        expect(name_index.columns).to eq([
          DbSchema::Definitions::Index::TableField.new(:name)
        ])
        expect(name_index.type).to eq(:spgist)

        expect(users.checks.count).to eq(1)
        age_check = users.checks.first
        expect(age_check.name).to eq(:is_adult)
        expect(age_check.condition).to eq('age > 18')

        expect(posts.indices.count).to eq(1)
        user_id_index = posts.indices.first
        expect(user_id_index.columns).to eq([
          DbSchema::Definitions::Index::TableField.new(:user_id)
        ])
        expect(user_id_index).not_to be_unique

        expect(posts.foreign_keys.count).to eq(2)
        user_id_fkey, user_name_fkey = posts.foreign_keys
        expect(user_id_fkey.name).to eq(:posts_user_id_fkey)
        expect(user_id_fkey.fields).to eq([:user_id])
        expect(user_id_fkey.table).to eq(:users)
        expect(user_id_fkey.references_primary_key?).to eq(true)
        expect(user_id_fkey.on_delete).to eq(:set_null)
        expect(user_id_fkey.on_update).to eq(:no_action)
        expect(user_id_fkey).to be_deferrable
        expect(user_name_fkey.name).to eq(:user_name_fkey)
        expect(user_name_fkey.fields).to eq([:user_name])
        expect(user_name_fkey.table).to eq(:users)
        expect(user_name_fkey.keys).to eq([:name])
        expect(user_name_fkey.on_delete).to eq(:no_action)
        expect(user_name_fkey.on_update).to eq(:cascade)
        expect(user_name_fkey).not_to be_deferrable
      end

      after(:each) do
        DbSchema.connection.drop_table(:posts)
        DbSchema.connection.drop_table(:users)
        DbSchema.connection.drop_enum(:rainbow)
        DbSchema.connection.run('DROP EXTENSION hstore')
      end
    end
  end
end
