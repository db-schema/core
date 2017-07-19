module DbSchema
  class Migration
    include Dry::Equalizer(:name, :conditions, :changes)
    attr_reader :name, :conditions, :changes

    def initialize(name)
      @name = name
      @conditions = { apply: [], skip: [] }
      @changes = []
    end
  end
end
