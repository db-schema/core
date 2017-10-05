require 'spec_helper'

RSpec.describe DbSchema::Utils do
  describe '.rename_keys' do
    let(:hash) do
      { a: 1, b: 2 }
    end

    it 'returns a new hash with renamed keys' do
      expect(subject.rename_keys(hash, a: :c)).to eq(c: 1, b: 2)
    end

    context 'when called with a block' do
      let(:hash) do
        { precision: 10, scale: 2, null: false }
      end

      it 'yields new hash to the block' do
        new_hash = subject.rename_keys(hash) do |new_hash|
          new_hash[:size] = [new_hash.delete(:precision), new_hash.delete(:scale)]
        end

        expect(new_hash).to eq(null: false, size: [10, 2])
      end
    end
  end

  describe '.filter_by_keys' do
    let(:hash) do
      { a: 1, b: 2, c: 3, d: 4 }
    end

    it 'returns a new hash containing just the given keys' do
      expect(subject.filter_by_keys(hash, :b, :c)).to eq(b: 2, c: 3)
    end
  end

  describe '.delete_at' do
    let(:hash) do
      { a: 1, b: 2, c: 3, d: 4 }
    end

    it 'deletes the given keys from the hash' do
      subject.delete_at(hash, :b, :d)

      expect(hash.keys).to eq([:a, :c])
    end

    it 'returns the deleted values' do
      expect(subject.delete_at(hash, :b, :d)).to eq([2, 4])
    end
  end

  describe '.symbolize_keys' do
    let(:hash) do
      { 'a' => 1, b: 2, 'c' => 3 }
    end

    it 'returns a new hash with symbol keys' do
      expect(subject.symbolize_keys(hash)).to eq(a: 1, b: 2, c: 3)
    end

    context 'with a nested hash' do
      before(:each) do
        hash['d'] = { e: 4, 'f' => 5 }
      end

      it 'returns a new nested hash with symbol keys at all levels' do
        expect(subject.symbolize_keys(hash)).to eq(a: 1, b: 2, c: 3, d: { e: 4, f: 5 })
      end
    end
  end

  describe '.remove_nil_values' do
    let(:hash) do
      { a: 1, b: nil, c: 3 }
    end

    it 'returns a new hash containing only key-value pairs with non-nil values' do
      expect(subject.remove_nil_values(hash)).to eq(a: 1, c: 3)
    end
  end

  describe '.sort_by_class' do
    let(:class_a) { Class.new }
    let(:class_b) { Class.new }
    let(:class_c) { Class.new }

    let(:objects) { [class_b.new, class_c.new, class_a.new, class_c.new, class_b.new] }

    it 'sorts the objects in correct order' do
      sorted_objects = subject.sort_by_class(objects, [class_a, class_b, class_c])

      expect(sorted_objects.map(&:class)).to eq([class_a, class_b, class_b, class_c, class_c])
    end
  end

  describe '.filter_by_class' do
    let(:array) do
      [
        [1, 2],
        { a: 1 },
        [3, 4],
        123,
        'abc'
      ]
    end

    it 'returns an array limited to instances of a given class' do
      expect(subject.filter_by_class(array, ::Array)).to eq([[1, 2], [3, 4]])
    end
  end
end
