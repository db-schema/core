module DbSchema
  module Definitions
    module Field
      class Char < Base
        register :char, :character
        attributes length: 1
      end

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
