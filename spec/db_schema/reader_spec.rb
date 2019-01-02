RSpec.describe DbSchema::Reader do
  before(:each) do
    skip 'Rewriting serial and primary keys'
  end

  let(:database) do
    Sequel.connect(adapter: 'postgres', database: 'db_schema_test').tap do |db|
      db.extension :pg_enum
      db.extension :pg_array
    end
  end

  describe '.reader_for' do
    it 'returns a reader for a given connection' do
      reader = subject.reader_for(database)
      expect(reader.read_schema).to eq(DbSchema::Definitions::Schema.new)
    end
  end
end
