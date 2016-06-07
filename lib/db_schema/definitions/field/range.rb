module DbSchema
  module Definitions
    module Field
      class Int4Range < Base
        register :int4range
      end

      class Int8Range < Base
        register :int8range
      end

      class NumRange < Base
        register :numrange
      end

      class TsRange < Base
        register :tsrange
      end

      class TsTzRange < Base
        register :tstzrange
      end

      class DateRange < Base
        register :daterange
      end
    end
  end
end
