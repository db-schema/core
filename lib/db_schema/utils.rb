module DbSchema
  module Utils
    class << self
      def rename_keys(hash, mapping = {})
        hash.reduce({}) do |final_hash, (key, value)|
          new_key = mapping.fetch(key, key)
          final_hash.merge(new_key => value)
        end.tap do |final_hash|
          yield(hash, final_hash) if block_given?
        end
      end
    end
  end
end
