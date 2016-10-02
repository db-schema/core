require 'dry/equalizer'

module DbSchema
  module Definitions
    class Index
      include Dry::Equalizer(:name, :columns, :unique?, :type, :condition)
      attr_reader :name, :columns, :type, :condition

      def initialize(name:, columns:, unique: false, type: :btree, condition: nil)
        @name      = name.to_sym
        @columns   = columns
        @unique    = unique
        @type      = type
        @condition = condition
      end

      def unique?
        @unique
      end

      def btree?
        type == :btree
      end

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

        def to_sequel
          if asc?
            Sequel.asc(name, nulls: nulls)
          else
            Sequel.desc(name, nulls: nulls)
          end
        end
      end

      class TableField < Column
        def expression?
          false
        end
      end

      class Expression < Column
        def expression?
          true
        end
      end
    end

    class ForeignKey
      include Dry::Equalizer(:name, :fields, :table, :keys, :on_update, :on_delete, :deferrable?)
      attr_reader :name, :fields, :table, :keys, :on_update, :on_delete

      def initialize(name:, fields:, table:, keys: [], on_update: :no_action, on_delete: :no_action, deferrable: false)
        @name       = name
        @fields     = fields
        @table      = table
        @keys       = keys
        @on_update  = on_update
        @on_delete  = on_delete
        @deferrable = deferrable
      end

      def references_primary_key?
        keys.empty?
      end

      def deferrable?
        @deferrable
      end

      def options
        {
          deferrable: deferrable?,
          name:       name,
          on_delete:  on_delete,
          on_update:  on_update
        }.tap do |options|
          options[:key] = keys unless references_primary_key?
        end
      end
    end

    class CheckConstraint
      include Dry::Equalizer(:name, :condition)
      attr_reader :name, :condition

      def initialize(name:, condition:)
        @name      = name
        @condition = condition
      end
    end

    class Table
      include Dry::Equalizer(:name, :fields, :indices, :checks, :foreign_keys)
      attr_reader :name, :fields, :indices, :checks, :foreign_keys

      def initialize(name, fields: [], indices: [], checks: [], foreign_keys: [])
        @name         = name.to_sym
        @fields       = fields
        @indices      = indices
        @checks       = checks
        @foreign_keys = foreign_keys
      end
    end

    class Enum
      include Dry::Equalizer(:name, :values)
      attr_reader :name, :values

      def initialize(name, values)
        @name   = name
        @values = values
      end
    end

    class Extension
      include Dry::Equalizer(:name)
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end
  end
end

require_relative 'definitions/field'
