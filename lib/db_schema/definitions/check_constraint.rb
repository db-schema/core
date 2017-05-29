module DbSchema
  module Definitions
    class CheckConstraint
      include Dry::Equalizer(:name, :condition)
      attr_reader :name, :condition

      def initialize(name:, condition:)
        @name      = name.to_sym
        @condition = condition
      end
    end

    class NullCheckConstraint < CheckConstraint
      def initialize; end
    end
  end
end
