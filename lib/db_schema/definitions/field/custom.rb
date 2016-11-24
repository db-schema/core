module DbSchema
  module Definitions
    module Field
      class Custom < Base
        class << self
          def class_for(type_name)
            raise ArgumentError if type_name.nil?

            Class.new(self) do
              define_method :type do
                type_name
              end

              define_singleton_method :type do
                type_name
              end
            end
          end
        end
      end
    end
  end
end
