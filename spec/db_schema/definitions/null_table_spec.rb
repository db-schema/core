require 'spec_helper'

RSpec.describe DbSchema::Definitions::NullTable do
  describe '#name' do
    it 'returns nil' do
      expect(subject.name).to be_nil
    end
  end

  describe '#fields' do
    it 'returns an empty array' do
      expect(subject.fields).to eq([])
    end
  end

  describe '#indexes' do
    it 'returns an empty array' do
      expect(subject.indexes).to eq([])
    end
  end

  describe '#checks' do
    it 'returns an empty array' do
      expect(subject.checks).to eq([])
    end
  end

  describe '#foreign_keys' do
    it 'returns an empty array' do
      expect(subject.foreign_keys).to eq([])
    end
  end
end
