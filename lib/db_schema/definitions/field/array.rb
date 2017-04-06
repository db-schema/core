module DbSchema
  module Definitions
    module Field
      class Array < Base
        register :array

        def initialize(name, **options)
          type_class = Field.type_class_for(options[:element_type])
          super(name, **options.merge(element_type: type_class))
        end

        def attributes
          super.merge(element_type: @attributes[:element_type].type)
        end
      end
    end
  end
end
