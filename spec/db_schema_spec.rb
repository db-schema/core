require 'spec_helper'

RSpec.describe DbSchema do
  it 'has a version number' do
    expect(DbSchema::VERSION).not_to be_nil
  end

  describe '.describe' do
    it 'applies the schema to the database' do
      pending 'Refactoring Runner & DbSchema.describe'

      subject.describe do |db|
        db.table :users do |t|
          t.integer :id, primary_key: true
          t.varchar :name
        end
      end

      expect(subject.connection.tables).to eq([:users])
      id, name = subject.connection.schema(:users)
      expect(id.first).to eq(:id)
      expect(id.last[:db_type]).to eq('integer')
      expect(id.last[:primary_key]).to eq(true)
      expect(name.first).to eq(:name)
      expect(name.last[:db_type]).to eq('character varying(255)')
    end

    after(:each) do
      DbSchema.connection.tables.each do |table_name|
        DbSchema.connection.drop_table(table_name)
      end
    end
  end

  describe '.configure' do
    it 'stores the connection parameters in configuration object' do
      subject.configure(
        host:     'localhost',
        database: 'db_schema_test',
        user:     '7even',
        password: 'secret'
      )

      expect(subject.configuration.host).to eq('localhost')
      expect(subject.configuration.database).to eq('db_schema_test')
      expect(subject.configuration.user).to eq('7even')
      expect(subject.configuration.password).to eq('secret')
    end

    after(:each) do
      subject.reset!
    end
  end

  describe '.configuration' do
    context 'without a prior call to .configure' do
      it 'raises a RuntimeError' do
        expect {
          subject.configuration
        }.to raise_error(RuntimeError, /DbSchema\.configure/)
      end
    end
  end
end
