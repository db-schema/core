require 'spec_helper'

describe DbSchema do
  it 'has a version number' do
    expect(DbSchema::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(false).to eq(true)
  end
end
