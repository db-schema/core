module DbSchema
  module Definitions
    module Field
      class << self
        def build(name, type, **options)
          type_class_for(type).new(name, **options)
        end

        def type_class_for(type)
          registry.fetch(type) do |type|
            raise ArgumentError, "#{type.inspect} type is not supported."
          end
        end

        def registry
          @registry ||= {}
        end
      end
    end
  end
end

require_relative 'field/base'
require_relative 'field/numeric'
require_relative 'field/monetary'
require_relative 'field/character'
require_relative 'field/binary'
require_relative 'field/datetime'
require_relative 'field/boolean'
require_relative 'field/geometric'
require_relative 'field/network'
require_relative 'field/bit_string'
require_relative 'field/text_search'
require_relative 'field/uuid'
require_relative 'field/json'
require_relative 'field/array'
require_relative 'field/range'
require_relative 'field/custom'
