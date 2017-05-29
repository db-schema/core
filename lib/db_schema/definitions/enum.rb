module DbSchema
  module Definitions
    class Enum
      include Dry::Equalizer(:name, :values)
      attr_reader :name, :values

      def initialize(name, values)
        @name   = name
        @values = values
      end

      def with_name(new_name)
        Enum.new(new_name, values)
      end
    end

    class NullEnum < Enum
      def initialize; end
    end
  end
end
