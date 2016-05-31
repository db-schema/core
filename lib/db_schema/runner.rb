module DbSchema
  class Runner
    attr_reader :changes

    def initialize(changes)
      @changes = changes
    end

    def run!
      changes.each do |change|
        case change
        when Changes::CreateTable
          self.class.create_table(change)
        when Changes::DropTable
          self.class.drop_table(change)
        when Changes::AlterTable
          self.class.alter_table(change)
        end
      end
    end

    class << self
      def create_table(change)
        DbSchema.connection.create_table(change.name) do
          change.fields.each do |field|
            if field.primary_key?
              primary_key(field.name)
            else
              column(field.name, field.class.type, field.options)
            end
          end

          change.indices.each do |index|
            index(index.fields, name: index.name, unique: index.unique?, where: index.condition)
          end

          change.foreign_keys.each do |foreign_key|
            foreign_key(foreign_key.fields, foreign_key.table, foreign_key.options)
          end
        end
      end

      def drop_table(change)
        DbSchema.connection.drop_table(change.name)
      end

      def alter_table(change)
        DbSchema.connection.alter_table(change.name) do
          change.fields.each do |field|
            case field
            when Changes::CreateColumn
              if field.primary_key?
                add_primary_key(field.name)
              else
                options = Runner.map_options(field.type, field.options)
                add_column(field.name, field.type.capitalize, options)
              end
            when Changes::DropColumn
              drop_column(field.name)
            when Changes::RenameColumn
              rename_column(field.old_name, field.new_name)
            when Changes::AlterColumnType
              attributes = Runner.map_options(field.new_type, field.new_attributes)
              set_column_type(field.name, field.new_type.capitalize, attributes)
            when Changes::CreatePrimaryKey
              raise NotImplementedError, 'Converting an existing column to primary key is currently unsupported'
            when Changes::DropPrimaryKey
              raise NotImplementedError, 'Removing a primary key while leaving the column is currently unsupported'
            when Changes::AllowNull
              set_column_allow_null(field.name)
            when Changes::DisallowNull
              set_column_not_null(field.name)
            when Changes::AlterColumnDefault
              set_column_default(field.name, field.new_default)
            end
          end

          change.indices.each do |index|
            case index
            when Changes::CreateIndex
              add_index(index.fields, name: index.name, unique: index.unique?, where: index.condition)
            when Changes::DropIndex
              drop_index([], name: index.name)
            end
          end

          change.foreign_keys.each do |foreign_key|
            case foreign_key
            when Changes::CreateForeignKey
              add_foreign_key(foreign_key.fields, foreign_key.table, foreign_key.options)
            when Changes::DropForeignKey
              drop_foreign_key([], name: foreign_key.name)
            end
          end
        end
      end

      def map_options(type, options)
        mapping = case type
        when :varchar
          { length: :size }
        else
          {}
        end

        Utils.rename_keys(options, mapping)
      end
    end
  end
end
