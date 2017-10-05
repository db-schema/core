require 'spec_helper'

RSpec.describe DbSchema::Configuration do
  subject { DbSchema::Configuration.new }

  describe '#initialize' do
    it 'creates a default configuration' do
      expect(subject.adapter).to  eq('postgres')
      expect(subject.host).to     eq('localhost')
      expect(subject.port).to     eq(5432)
      expect(subject.database).to be_nil
      expect(subject.user).to     be_nil
      expect(subject.password).to eq('')

      expect(subject.log_changes?).to        be_truthy
      expect(subject.dry_run?).to            be_falsy
      expect(subject.post_check_enabled?).to be_truthy
    end
  end

  describe '#merge' do
    it 'returns a new configuration filled with passed in values and defaults' do
      configuration = subject.merge(database: 'db_schema_test', user: '7even')

      expect(configuration.database).to eq('db_schema_test')
      expect(configuration.user).to     eq('7even')
      expect(configuration.password).to eq('')
    end

    context 'with a :url option' do
      let(:url) { 'postgresql://user:password@some_host/db_schema' }

      it "parses the URL and takes it's non-nil attributes" do
        configuration = subject.merge(url: url)

        expect(configuration.host).to eq('some_host')
        expect(configuration.port).to eq(5432)
        expect(configuration.database).to eq('db_schema')
        expect(configuration.user).to eq('user')
        expect(configuration.password).to eq('password')
      end
    end

    context 'when called several times' do
      it 'merges all params together' do
        configuration = subject.merge(database: 'db_schema_test').merge(user: '7even')

        expect(configuration.database).to eq('db_schema_test')
        expect(configuration.user).to     eq('7even')
      end
    end
  end
end
