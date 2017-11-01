module DbCleaner
  def clean!
    schema.tables.each do |table|
      table.foreign_keys.each do |foreign_key|
        database.alter_table(table.name) do
          drop_foreign_key([], name: foreign_key.name)
        end
      end
    end

    schema.enums.each do |enum|
      database.drop_enum(enum.name, cascade: true)
    end

    schema.tables.each do |table|
      database.drop_table(table.name)
    end

    schema.extensions.each do |extension|
      database.run(%(DROP EXTENSION "#{extension.name}"))
    end
  end
end
