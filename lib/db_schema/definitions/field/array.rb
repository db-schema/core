module DbSchema
  module Definitions
    module Field
      class Array < Base
        register :array
        attr_reader :element_type

        def initialize(name, element_type:, **options)
          super(name, **options)
          @element_type = Field.type_class_for(element_type)
        end

        def attributes
          super.merge(element_type: element_type.type)
        end
      end
    end
  end
end
