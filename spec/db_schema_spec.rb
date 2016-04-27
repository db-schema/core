require 'spec_helper'

RSpec.describe DbSchema do
  it 'has a version number' do
    expect(DbSchema::VERSION).not_to be_nil
  end
end
