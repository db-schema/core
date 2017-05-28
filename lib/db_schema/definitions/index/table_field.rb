module DbSchema
  module Definitions
    class Index
      class TableField < Column
        def expression?
          false
        end

        def index_name_segment
          name
        end

        def to_sequel
          name
        end
      end
    end
  end
end
