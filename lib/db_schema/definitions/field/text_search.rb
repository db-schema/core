module DbSchema
  module Definitions
    module Field
      class TsVector < Base
        register :tsvector
      end

      class TsQuery < Base
        register :tsquery
      end
    end
  end
end
