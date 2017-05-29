require 'spec_helper'

RSpec.describe DbSchema::Definitions::Table do
  subject do
    DbSchema::Definitions::Table.new(
      :users,
      fields: [
        DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
        DbSchema::Definitions::Field::Varchar.new(:first_name),
        DbSchema::Definitions::Field::Varchar.new(:last_name),
        DbSchema::Definitions::Field::Integer.new(:city_id, null: false)
      ],
      indices: [
        DbSchema::Definitions::Index.new(
          name: :users_name_index,
          columns: [
            DbSchema::Definitions::Index::Expression.new('first_name || last_name')
          ]
        )
      ],
      checks: [
        DbSchema::Definitions::CheckConstraint.new(
          name: :name_present,
          condition: 'first_name IS NOT NULL OR last_name IS NOT NULL'
        )
      ],
      foreign_keys: [
        DbSchema::Definitions::ForeignKey.new(name: :user_city_id_fkey, fields: [:city_id], table: :cities)
      ]
    )
  end

  describe '#[]' do
    context 'with a name of an existing field' do
      it 'returns the field definition' do
        expect(subject[:first_name]).to be_a(DbSchema::Definitions::Field::Varchar)
      end
    end

    context 'with an unknown field name' do
      it 'returns a NullField' do
        expect(subject[:email]).to be_a(DbSchema::Definitions::NullField)
      end
    end
  end

  describe '#has_field?'

  describe '#has_index?'

  describe '#has_check?'

  describe '#has_foreign_key?'
end
