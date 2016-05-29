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
require_relative 'field/character'
