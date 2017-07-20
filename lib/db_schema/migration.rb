module DbSchema
  class Migration
    include Dry::Equalizer(:name, :conditions, :body)
    attr_reader :name, :conditions
    attr_accessor :body

    def initialize(name)
      @name = name
      @conditions = { apply: [], skip: [] }
    end
  end
end
