module DbSchema
  module Definitions
    module Field
      class Timestamp < Base
        register :timestamp, :'timestamp without time zone'
      end

      class Timestamptz < Base
        register :timestamptz, :'timestamp with time zone'
      end

      class Date < Base
        register :date
      end

      class Time < Base
        register :time, :'time without time zone'
      end

      class Timetz < Base
        register :timetz, :'time with time zone'
      end

      class Interval < Base
        register :interval
        attributes :fields, :precision
      end
    end
  end
end
