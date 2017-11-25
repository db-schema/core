module DbSchema
  module Definitions
    class CheckConstraint
      include Dry::Equalizer(:name, :condition)
      attr_reader :name, :condition

      def initialize(name:, condition:)
        @name      = name.to_sym
        @condition = condition
      end

      def with_condition(new_condition)
        CheckConstraint.new(name: name, condition: new_condition)
      end
    end

    class NullCheckConstraint < CheckConstraint
      def initialize; end
    end
  end
end
