module DbSchema
  module Definitions
    module Field
      class Varchar < Base
        register :varchar, :'character varying'
        attributes :length
      end

      class Text < Base
        register :text
      end
    end
  end
end
