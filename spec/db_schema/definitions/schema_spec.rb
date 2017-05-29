require 'spec_helper'

RSpec.describe DbSchema::Definitions::Schema do
  let(:users) do
    DbSchema::Definitions::Table.new(
      :users,
      fields: [DbSchema::Definitions::Field::Integer.new(:id, primary_key: true)]
    )
  end

  let(:user_role) do
    DbSchema::Definitions::Enum.new(:user_role, %i(guest user))
  end

  let(:hstore) do
    DbSchema::Definitions::Extension.new(:hstore)
  end

  subject do
    DbSchema::Definitions::Schema.new(
      tables:     [users],
      enums:      [user_role],
      extensions: [hstore]
    )
  end

  describe '#[]' do
    context 'with a name of an existing table' do
      it 'returns the table definition' do
        expect(subject[:users]).to eq(users)
      end
    end

    context 'with an unknown table name' do
      it 'returns a NullTable' do
        expect(subject[:posts]).to be_a(DbSchema::Definitions::NullTable)
      end
    end
  end

  describe '#has_table?' do
    context 'with a name of an existing table' do
      it 'returns true' do
        expect(subject).to have_table(:users)
      end
    end

    context 'with an unknown table name' do
      it 'returns false' do
        expect(subject).not_to have_table(:posts)
      end
    end
  end

  describe '#has_enum?' do
    context 'with a name of an existing enum' do
      it 'returns true' do
        expect(subject).to have_enum(:user_role)
      end
    end

    context 'with an unknown enum name' do
      it 'returns false' do
        expect(subject).not_to have_enum(:user_mood)
      end
    end
  end

  describe '#has_extension?' do
    context 'with a name of an enabled extension' do
      it 'returns true' do
        expect(subject).to have_extension(:hstore)
      end
    end

    context 'with an unknown extension name' do
      it 'returns false' do
        expect(subject).not_to have_extension(:ltree)
      end
    end
  end
end
