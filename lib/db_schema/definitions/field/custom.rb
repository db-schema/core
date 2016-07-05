module DbSchema
  module Definitions
    module Field
      class Custom < Base
        attr_reader :type_name

        def initialize(name, type_name:, **options)
          super(name, **options)
          @type_name = type_name
        end

        def custom_type?
          true
        end

        def type
          type_name
        end
      end
    end
  end
end
