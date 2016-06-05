module DbSchema
  module Definitions
    module Field
      class JSON < Base
        register :json
      end

      class JSONB < Base
        register :jsonb
      end
    end
  end
end
