module DbSchema
  module Definitions
    module Field
      class SmallInt < Base
        register :smallint
      end

      class Integer < Base
        register :integer
      end

      class BigInt < Base
        register :bigint
      end

      class Numeric < Base
        register :numeric, :decimal
        attributes :precision, :scale
      end

      class Real < Base
        register :real
      end

      class DoublePrecision < Base
        register :'double precision', :float
      end
    end
  end
end
