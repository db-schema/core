module DbSchema
  class Migration
    include Dry::Equalizer(:conditions, :changes)
    attr_reader :conditions, :changes

    def initialize
      @conditions = { apply: [], skip: [] }
      @changes = []
    end
  end
end
