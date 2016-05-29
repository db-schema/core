module DbSchema
  module Definitions
    module Field
      class Varchar < Base
        register :varchar
        attributes :length
      end

      class Text < Base
        register :text
      end
    end
  end
end
