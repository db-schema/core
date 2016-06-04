module DbSchema
  module Definitions
    module Field
      class Point < Base
        register :point
      end

      class Line < Base
        register :line
      end

      class Lseg < Base
        register :lseg
      end

      class Box < Base
        register :box
      end

      class Path < Base
        register :path
      end

      class Polygon < Base
        register :polygon
      end

      class Circle < Base
        register :circle
      end
    end
  end
end
