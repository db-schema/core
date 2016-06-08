begin
  require 'awesome_print'
rescue LoadError
end

if defined?(AwesomePrint)
  module AwesomePrint
    module DbSchema
      def self.included(base)
        base.send :alias_method, :cast_without_dbschema, :cast
        base.send :alias_method, :cast, :cast_with_dbschema
      end

      def cast_with_dbschema(object, type)
        case object
        when ::DbSchema::Definitions::Table
          :dbschema_table
        when ::DbSchema::Definitions::Field::Base
          :dbschema_field
        when ::DbSchema::Definitions::Index
          :dbschema_index
        when ::DbSchema::Definitions::ForeignKey
          :dbschema_foreign_key
        else
          cast_without_dbschema(object, type)
        end
      end

      private
      def awesome_dbschema_table(object)
        data = ["fields: #{object.fields.ai(indent: 8)}"]
        data << "indices: #{object.indices.ai(indent: 8)}" if object.indices.any?
        data << "foreign_keys: #{object.foreign_keys.ai(indent: 8)}" if object.foreign_keys.any?

        "#<DbSchema::Definitions::Table #{object.name.ai} #{data.join(', ')}>"
      end

      def awesome_dbschema_field(object)
        options = object.options.map do |k, v|
          key = colorize("#{k}:", :symbol)
          "#{key} #{v.ai}"
        end.unshift(nil).join(', ')

        primary_key = if object.primary_key?
          ', ' + colorize('primary key', :nilclass)
        else
          ''
        end

        "#<#{object.class} #{object.name.ai}#{options}#{primary_key}>"
      end

      def awesome_dbschema_index(object)
        fields = format_dbschema_fields(object.fields)
        using = ' using ' + colorize(object.type.to_s, :symbol) unless object.btree?

        data = [nil]
        data << colorize('unique', :nilclass) if object.unique?
        data << colorize('condition: ', :symbol) + object.condition.ai unless object.condition.nil?

        "#<#{object.class} #{object.name.ai} on #{fields}#{using}#{data.join(', ')}>"
      end

      def awesome_dbschema_foreign_key(object)
        fields = format_dbschema_fields(object.fields)
        references = "#{colorize('references', :class)} #{object.table.ai}"
        references << ' ' + format_dbschema_fields(object.keys) unless object.references_primary_key?

        data = [nil]
        data << colorize("on_update:", :symbol) + " #{object.on_update.ai}" unless object.on_update == :no_action
        data << colorize("on_delete:", :symbol) + " #{object.on_delete.ai}" unless object.on_delete == :no_action
        data << colorize('deferrable', :nilclass) if object.deferrable?

        "#<#{object.class} #{object.name.ai} on #{fields} #{references}#{data.join(', ')}>"
      end

      def format_dbschema_fields(fields)
        if fields.one?
          fields.first.ai
        else
          '[' + fields.map(&:ai).join(', ') + ']'
        end
      end
    end
  end

  AwesomePrint::Formatter.send(:include, AwesomePrint::DbSchema)
end
