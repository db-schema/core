module DbSchema
  module Definitions
    class Index
      class Column
        include Dry::Equalizer(:name, :order, :nulls)
        attr_reader :name, :order, :nulls

        def initialize(name, order: :asc, nulls: order == :asc ? :last : :first)
          @name  = name
          @order = order
          @nulls = nulls
        end

        def asc?
          @order == :asc
        end

        def desc?
          @order == :desc
        end

        def ordered_expression
          if asc?
            Sequel.asc(to_sequel, nulls: nulls)
          else
            Sequel.desc(to_sequel, nulls: nulls)
          end
        end
      end
    end
  end
end
