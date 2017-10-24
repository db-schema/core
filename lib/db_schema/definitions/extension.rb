module DbSchema
  module Definitions
    class Extension
      include Dry::Equalizer(:name)
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end
  end
end
