require 'spec_helper'

RSpec.describe DbSchema do
  it 'has a version number' do
    expect(DbSchema::VERSION).not_to be_nil
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
