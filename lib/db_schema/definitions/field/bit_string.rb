module DbSchema
  module Definitions
    module Field
      class Bit < Base
        register :bit
        attributes length: 1
      end

      class Varbit < Base
        register :varbit, :'bit varying'
        attributes :length
      end
    end
  end
end
