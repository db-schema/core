module DbSchema
  module Definitions
    module Field
      class EAN13 < Base
        register :ean13
      end

      class ISBN13 < Base
        register :isbn13
      end

      class ISMN13 < Base
        register :ismn13
      end

      class ISSN13 < Base
        register :issn13
      end

      class ISBN < Base
        register :isbn
      end

      class ISMN < Base
        register :ismn
      end

      class ISSN < Base
        register :issn
      end

      class UPC < Base
        register :upc
      end
    end
  end
end
