module DbSchema
  module Definitions
    module Field
      class Array < Base
        register :array
        attr_reader :element_type

        def initialize(name, of:, **options)
          super(name, **options)
          @element_type = Field.type_class_for(of)
        end

        def attributes
          super.merge(element_type: element_type.type)
        end
      end
    end
  end
end
