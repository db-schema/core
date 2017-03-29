module DbSchema
  module Definitions
    module Field
      class Custom < Base
        class << self
          def class_for(type_name)
            raise ArgumentError if type_name.nil?

            custom_types[type_name] ||= Class.new(self) do
              define_method :type do
                type_name
              end

              define_singleton_method :type do
                type_name
              end
            end
          end

        private
          def custom_types
            @custom_types ||= {}
          end
        end
      end
    end
  end
end
