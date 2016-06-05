module DbSchema
  module Definitions
    module Field
      class Cidr < Base
        register :cidr
      end

      class Inet < Base
        register :inet
      end

      class MacAddr < Base
        register :macaddr
      end
    end
  end
end
