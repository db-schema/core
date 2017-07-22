require 'spec_helper'

RSpec.describe DbSchema::Migrator do
  before(:each) do
    DbSchema::Runner.new([
      DbSchema::Operations::CreateTable.new(
        DbSchema::Definitions::Table.new(
          :people,
          fields: [
            DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
            DbSchema::Definitions::Field::Varchar.new(:name, null: false),
            DbSchema::Definitions::Field::Varchar.new(:phone),
            DbSchema::Definitions::Field::Timestamptz.new(:created_at)
          ],
          indices: [
            DbSchema::Definitions::Index.new(
              name: :people_phone_index,
              columns: [DbSchema::Definitions::Index::TableField.new(:phone)],
              unique: true,
              condition: 'phone IS NOT NULL'
            )
          ],
          checks: [
            DbSchema::Definitions::CheckConstraint.new(
              name: :phone_format,
              condition: %q(phone ~ '\A\+\d{11}\Z')
            )
          ]
        )
      )
    ]).run!
  end

  let(:schema)    { DbSchema::Reader.read_schema }
  let(:migration) { DbSchema::Migration.new('Migration name') }

  subject { DbSchema::Migrator.new(migration) }

  describe '#applicable?' do
    context 'with a schema satisfying all conditions' do
      before(:each) do
        migration.conditions[:apply] << -> (schema) do
          schema.has_table?(:people)
        end

        migration.conditions[:skip] << -> (schema) do
          schema.has_table?(:users)
        end
      end

      it 'returns true' do
        expect(subject).to be_applicable(schema)
      end
    end

    context 'with a schema failing some conditions' do
      before(:each) do
        migration.conditions[:apply] << -> (schema) do
          schema.has_table?(:posts)
        end

        migration.conditions[:skip] << -> (schema) do
          !schema.table(:people).field(:name).null?
        end
      end

      it 'returns false' do
        expect(subject).not_to be_applicable(schema)
      end
    end
  end

  describe '#run!' do
    before(:each) do
      migration.body = body
    end

    context 'with a create_table' do
      let(:body) do
        -> (migrator) do
          migrator.create_table :posts do |t|
            t.primary_key :id
            t.varchar :title, null: false
            t.text :body
          end
        end
      end

      it 'creates the table' do
        subject.run!

        expect(schema).to have_table(:posts)
      end
    end

    context 'with a drop_table' do
      let(:body) do
        -> (migrator) do
          migrator.drop_table :people
        end
      end

      it 'drops the table' do
        subject.run!

        expect(schema).not_to have_table(:people)
      end
    end

    context 'with a rename_table' do
      let(:body) do
        -> (migrator) do
          migrator.rename_table :people, to: :users
        end
      end

      it 'renames the table' do
        subject.run!

        expect(schema).not_to have_table(:people)
        expect(schema).to have_table(:users)
      end
    end

    context 'with an alter_table' do
      context 'and an add_column' do
        let(:body) do
          -> (migrator) do
            migrator.alter_table :people do |t|
              t.add_column :email, :varchar, null: false
            end
          end
        end

        it 'adds the column' do
          subject.run!

          expect(schema.table(:people)).to have_field(:email)
          email = schema.table(:people).field(:email)

          expect(email.name).to eq(:email)
          expect(email).to be_a(DbSchema::Definitions::Field::Varchar)
          expect(email).not_to be_null
        end
      end

      context 'and a drop_column' do
        let(:body) do
          -> (migrator) do
            migrator.alter_table :people do |t|
              t.drop_column :name
            end
          end
        end

        it 'drops the column' do
          subject.run!

          expect(schema.table(:people)).not_to have_field(:name)
        end
      end

      context 'and a rename_column' do
        let(:body) do
          -> (migrator) do
            migrator.alter_table :people do |t|
              t.rename_column :name, to: :first_name
            end
          end
        end

        it 'renames the column' do
          subject.run!

          expect(schema.table(:people)).not_to have_field(:name)
          expect(schema.table(:people)).to have_field(:first_name)
        end
      end

      context 'and an alter_column_type' do
        let(:body) do
          -> (migrator) do
            migrator.alter_table :people do |t|
              t.alter_column_type :name, :text
            end
          end
        end

        it 'changes the column type' do
          subject.run!

          expect(schema.table(:people).field(:name)).to be_a(DbSchema::Definitions::Field::Text)
        end
      end

      context 'and an allow_null' do
        let(:body) do
          -> (migrator) do
            migrator.alter_table :people do |t|
              t.allow_null :name
            end
          end
        end

        it 'removes the NOT NULL constraint from the column' do
          subject.run!

          expect(schema.table(:people).field(:name)).to be_null
        end
      end

      context 'and a disallow_null' do
        let(:body) do
          -> (migrator) do
            migrator.alter_table :people do |t|
              t.disallow_null :created_at
            end
          end
        end

        it 'adds the NOT NULL constraint to the column' do
          subject.run!

          expect(schema.table(:people).field(:created_at)).not_to be_null
        end
      end

      context 'and an alter_column_default' do
        let(:body) do
          -> (migrator) do
            migrator.alter_table :people do |t|
              t.alter_column_default :created_at, :'now()'
            end
          end
        end

        it 'changes the default value of the column' do
          subject.run!

          expect(schema.table(:people).field(:created_at).default).to eq(:'now()')
        end
      end

      context 'and an add_index' do
        let(:body) do
          -> (migrator) do
            migrator.alter_table :people do |t|
              t.add_index :name
            end
          end
        end

        it 'adds the index' do
          subject.run!

          expect(schema.table(:people)).to have_index_on(:name)
        end
      end

      context 'and a drop_index' do
        let(:body) do
          -> (migrator) do
            migrator.alter_table :people do |t|
              t.drop_index :people_phone_index
            end
          end
        end

        it 'drops the index' do
          subject.run!

          expect(schema.table(:people)).not_to have_index_on(:phone)
        end
      end

      context 'and an add_check' do
        let(:body) do
          -> (migrator) do
            migrator.alter_table :people do |t|
              t.add_check :name_length, 'character_length(name::text) > 4'
            end
          end
        end

        it 'adds the check constraint' do
          subject.run!

          expect(schema.table(:people)).to have_check(:name_length)
          expect(schema.table(:people).check(:name_length).condition).to eq('character_length(name::text) > 4')
        end
      end

      context 'and a drop_check' do
        let(:body) do
          -> (migrator) do
            migrator.alter_table :people do |t|
              t.drop_check :phone_format
            end
          end
        end

        it 'drops the check constraint' do
          subject.run!

          expect(schema.table(:people)).not_to have_check(:phone_format)
        end
      end

      context 'and an add_foreign_key' do
        before(:each) do
          DbSchema::Runner.new([
            DbSchema::Operations::CreateTable.new(
              DbSchema::Definitions::Table.new(
                :posts,
                fields: [
                  DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
                  DbSchema::Definitions::Field::Varchar.new(:title, null: false),
                  DbSchema::Definitions::Field::Integer.new(:person_id, null: false)
                ]
              )
            )
          ]).run!
        end

        let(:body) do
          -> (migrator) do
            migrator.alter_table :posts do |t|
              t.add_foreign_key :person_id, references: :people
            end
          end
        end

        it 'adds the foreign key' do
          subject.run!

          expect(schema.table(:posts)).to have_foreign_key_to(:people)
        end
      end

      context 'and a drop_foreign_key' do
        before(:each) do
          DbSchema::Runner.new([
            DbSchema::Operations::CreateTable.new(
              DbSchema::Definitions::Table.new(
                :posts,
                fields: [
                  DbSchema::Definitions::Field::Integer.new(:id, primary_key: true),
                  DbSchema::Definitions::Field::Varchar.new(:title, null: false),
                  DbSchema::Definitions::Field::Integer.new(:person_id, null: false)
                ]
              )
            ),
            DbSchema::Operations::CreateForeignKey.new(
              :posts,
              DbSchema::Definitions::ForeignKey.new(
                name: :posts_person_id_fkey,
                fields: [:person_id],
                table: :people
              )
            )
          ]).run!
        end

        let(:body) do
          -> (migrator) do
            migrator.alter_table :posts do |t|
              t.drop_foreign_key :posts_person_id_fkey
            end
          end
        end

        it 'drops the foreign key' do
          subject.run!

          expect(schema.table(:posts)).not_to have_foreign_key_to(:people)
        end
      end
    end

    context 'with a create_enum' do
      let(:body) do
        -> (migrator) do
          migrator.create_enum :user_role, %i(guest user admin)
        end
      end

      it 'adds the enum' do
        subject.run!

        expect(schema).to have_enum(:user_role)
        expect(schema.enum(:user_role).values).to eq(%i(guest user admin))
      end
    end

    context 'with a drop_enum' do
      before(:each) do
        DbSchema::Runner.new([
          DbSchema::Operations::CreateEnum.new(
            DbSchema::Definitions::Enum.new(:user_role, %i(guest user admin))
          )
        ]).run!
      end

      let(:body) do
        -> (migrator) do
          migrator.drop_enum :user_role
        end
      end

      it 'drops the enum' do
        subject.run!

        expect(schema).not_to have_enum(:user_role)
      end
    end

    context 'with a create_extension' do
      let(:body) do
        -> (migrator) do
          migrator.create_extension :hstore
        end
      end

      it 'enables the extension' do
        subject.run!

        expect(schema).to have_extension(:hstore)
      end
    end

    context 'with a drop_extension' do
      before(:each) do
        DbSchema::Runner.new([
          DbSchema::Operations::CreateExtension.new(
            DbSchema::Definitions::Extension.new(:hstore)
          )
        ]).run!
      end

      let(:body) do
        -> (migrator) do
          migrator.drop_extension :hstore
        end
      end

      it 'drops the extension' do
        subject.run!

        expect(schema).not_to have_extension(:hstore)
      end
    end

    context 'with an execute' do
      before(:each) do
        DbSchema.connection[:people].insert(name: 'John Smith')
      end

      let(:body) do
        -> (migrator) do
          migrator.execute "UPDATE people SET phone = '+79012345678'"
        end
      end

      it 'executes the query' do
        subject.run!

        person = DbSchema.connection['SELECT * FROM people'].first
        expect(person[:phone]).to eq('+79012345678')
      end
    end

    context 'without a body' do
      let(:body) { nil }

      it "doesn't change the schema" do
        expect {
          subject.run!
        }.not_to change { DbSchema::Reader.read_schema }
      end
    end
  end

  after(:each) do
    DbSchema.connection.tables.each do |table_name|
      DbSchema.connection.foreign_key_list(table_name).each do |foreign_key|
        DbSchema.connection.alter_table(table_name) do
          drop_foreign_key([], name: foreign_key[:name])
        end
      end
    end

    DbSchema::Reader.read_enums.each do |enum|
      DbSchema.connection.drop_enum(enum.name, cascade: true)
    end

    DbSchema.connection.tables.each do |table_name|
      DbSchema.connection.drop_table(table_name)
    end

    DbSchema::Reader.read_extensions.each do |extension|
      DbSchema.connection.run("DROP EXTENSION #{extension.name}")
    end
  end
end
