RSpec.describe DbSchema::Reader do
  let(:database) do
    Sequel.connect(adapter: 'postgres', database: 'db_schema_test').tap do |db|
      db.extension :pg_enum
      db.extension :pg_array
    end
  end

  describe '.read_schema' do
    let(:reader) { double('Some reader module') }
    let(:schema) { double('Some database schema') }

    before(:each) do
      allow(subject).to receive(:reader_for).and_return(reader)
    end

    it 'delegates to the reader' do
      expect(reader).to receive(:read_schema).and_return(schema)

      expect(subject.read_schema(database)).to eq(schema)
    end
  end
end
