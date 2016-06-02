module DbSchema
  module Definitions
    module Field
      class Timestamp < Base
        register :timestamp, :'timestamp without time zone'
        attributes precision: 6
      end

      class Timestamptz < Base
        register :timestamptz, :'timestamp with time zone'
        attributes precision: 6
      end

      class Date < Base
        register :date
      end

      class Time < Base
        register :time, :'time without time zone'
        attributes precision: 6
      end

      class Timetz < Base
        register :timetz, :'time with time zone'
        attributes precision: 6
      end
    end
  end
end
