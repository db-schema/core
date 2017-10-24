module DbSchema
  module Definitions
    class Index
      class Expression < Column
        def expression?
          true
        end

        def index_name_segment
          name.scan(/\b[A-Za-z0-9_]+\b/).join('_')
        end

        def to_sequel
          Sequel.lit("(#{name})")
        end
      end
    end
  end
end
