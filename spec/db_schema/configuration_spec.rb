require 'spec_helper'

RSpec.describe DbSchema::Configuration do
  describe '#initialize' do
    subject { DbSchema::Configuration.new(user: '7even', database: 'db_schema_test') }

    it 'stores the passed in connection parameters' do
      expect(subject.user).to eq('7even')
      expect(subject.database).to eq('db_schema_test')
    end

    it 'offers sane defaults' do
      expect(subject.adapter).to  eq('postgres')
      expect(subject.host).to     eq('localhost')
      expect(subject.port).to     eq(5432)
      expect(subject.password).to eq('')
    end
  end
end
