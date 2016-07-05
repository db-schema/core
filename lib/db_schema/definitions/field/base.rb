module DbSchema
  module Definitions
    module Field
      class Base
        include Dry::Equalizer(:name, :class, :primary_key?, :options)
        attr_reader :name, :default

        def initialize(name, primary_key: false, null: true, default: nil, **attributes)
          @name        = name
          @primary_key = primary_key
          @null        = null
          @default     = default
          @attributes  = attributes
        end

        def primary_key?
          @primary_key
        end

        def null?
          !primary_key? && @null
        end

        def options
          attributes.tap do |options|
            options[:null] = false unless null?
            options[:default] = default unless default.nil?
          end
        end

        def attributes
          self.class.valid_attributes.reduce({}) do |hash, attr_name|
            if attr_value = @attributes[attr_name]
              hash.merge(attr_name => attr_value)
            elsif default_value = self.class.default_attribute_values[attr_name]
              hash.merge(attr_name => default_value)
            else
              hash
            end
          end
        end

        def custom_type?
          false
        end

        class << self
          def register(*types)
            types.each do |type|
              Field.registry[type] = self
            end
          end

          def attributes(*attr_names, **attributes_with_defaults)
            valid_attributes.push(*attr_names)

            attributes_with_defaults.each do |attr_name, default_value|
              valid_attributes.push(attr_name)
              default_attribute_values[attr_name] = default_value
            end
          end

          def valid_attributes
            @valid_attributes ||= []
          end

          def default_attribute_values
            @default_attribute_values ||= {}
          end

          def type
            Field.registry.key(self)
          end
        end
      end
    end
  end
end
