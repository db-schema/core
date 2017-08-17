# DbSchema [![Build Status](https://travis-ci.org/7even/db_schema.svg?branch=master)](https://travis-ci.org/7even/db_schema) [![Gem Version](https://badge.fury.io/rb/db_schema.svg)](https://badge.fury.io/rb/db_schema) [![Join the chat at https://gitter.im/7even/db_schema](https://badges.gitter.im/7even/db_schema.svg)](https://gitter.im/7even/db_schema?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

DbSchema is an opinionated database schema management tool that lets you maintain your DB schema with a single ruby file.

It works like this:

* you create a `schema.rb` file where you describe the schema you want in a special DSL
* you make your application load this file as early as possible during the application bootup in development and test environments
* you create a rake task that loads your `schema.rb` and tell your favorite deployment tool to run it on each deploy
* each time you need to change the schema you just change the `schema.rb` file and commit it to your VCS

As a result you always have an up-to-date database schema. No need to run and rollback migrations, no need to even think about the extra step - DbSchema compares the schema you want with the schema your database has and applies all necessary changes to the latter. This operation is [idempotent](https://en.wikipedia.org/wiki/Idempotence) - if DbSchema sees that the database already has the requested schema it does nothing.

*Currently DbSchema only supports PostgreSQL.*

## Reasons to use

With DbSchema you almost never need to write migrations by hand and manage a collection of migration files.
This gives you a list of important benefits:

* no more `YouHaveABunchOfPendingMigrations` errors - all needed operations are computed from the differences between the schema definition and the actual database schema
* no need to write separate :up and :down migrations - this is all handled automatically
* there is no `structure.sql` with a database dump that constantly changes without reason

But the main reason of DbSchema existence is the pain of switching
between long-running VCS branches with different migrations
without resetting the database. Have you ever switched
to a different branch only to see something like this?

![](https://cloud.githubusercontent.com/assets/351591/17085038/7da81118-51d6-11e6-91d9-99885235d037.png)

Yeah, you must remember the oldest `NO FILE` migration,
switch back to the previous branch,
roll back every migration up to that `NO FILE`,
discard all changes in `schema.rb`/`structure.sql` (and model annotations if you have any),
then switch the branch again and migrate these `down` migrations.
If you already wrote some code to be committed to the new branch
you need to make sure it won't get discarded so a simple `git reset --hard` won't do.
Every migration or rollback loads the whole app, resulting in 10+ seconds wasted.
And at the end of it all you are trying to recall why did you ever
want to switch to that branch.

DbSchema does not rely on migration files and/or `schema_migrations` table in the database
so it seamlessly changes the schema to the one defined in the branch you switched to.
There is no step 2.

Of course if you are switching from a branch that defines table A to a branch
that doesn't define table A then you lose that table with all the data in it.
But you would lose it even with manual migrations.

## Installation

Add this line to your application's Gemfile:

``` ruby
gem 'db_schema', '~> 0.3.rc1'
```

And then execute:

``` sh
$ bundle
```

Or install it yourself as:

``` sh
$ gem install db_schema --prerelease
```

## Usage

You define your schema with a special DSL; you can put it in `db/schema.rb` file or anywhere you want. Be sure to keep this file under version control.

DbSchema DSL looks like this:

``` ruby
DbSchema.describe do |db|
  db.table :users do |t|
    t.primary_key :id
    t.varchar     :email,           null: false, unique: true
    t.varchar     :password_digest, length: 40
    t.timestamptz :created_at
    t.timestamptz :updated_at
  end
end
```

Before DbSchema connects to the database you need to configure it:

``` ruby
DbSchema.configure(
  adapter:  'postgresql',
  database: 'my_database',
  user:     'bob',
  password: 'secret'
)

# or in Rails
DbSchema.configure_from_yaml(
  Rails.root.join('config', 'database.yml'),
  Rails.env
)
```

Then you can load your schema definition (it is executable - it instantly applies itself to your database):

``` ruby
load 'path/to/schema.rb'
```

In order to get an always-up-to-date database schema in development and test environments you need to load the schema definition when your application is starting up. For instance, in Rails an initializer would be a good place to do that.

On the other hand, in production environment this can cause race condition problems as your schema can be applied concurrently by different worker processes (this also applies to staging and any other environments where the application is being run by multi-worker servers); therefore it is wiser to disable schema auto loading in such environments and run it from a rake task on each deploy.

Here's an initializer example for a Rails app:

``` ruby
# config/initializers/db_schema.rb
DbSchema.configure_from_yaml(
  Rails.root.join('config', 'database.yml'),
  Rails.env
)

if Rails.env.development? || Rails.env.test?
  load Rails.root.join('db', 'schema.rb')
end
```

And the rake task:

``` ruby
# lib/tasks/db_schema.rake
namespace :db do
  namespace :schema do
    desc 'Apply database schema'
    task apply: :environment do
      load Rails.root.join('db', 'schema.rb')
    end
  end
end
```

Then you just call `rake db:schema:apply` from your deploy script before restarting the app.

If your production setup doesn't include multiple workers starting simultaneously (for example if you run one Puma worker per docker container and restart containers one by one on deploy) you can go the simple way and just `load Rails.root.join('db', 'schema.rb')` in any environment without a separate rake task. The first DbSchema run will apply the schema while the subsequent ones will see there's nothing left to do.

## DSL

Database schema is defined with a block passed to `DbSchema.describe` method.
This block receives a `db` object on which you can call `#table` to define a table,
`#enum` to define a custom enum type and `#extension` to plug a Postgres extension into your database.
Everything that belongs to a specific table is described in a block passed to `#table`.

``` ruby
DbSchema.describe do |db|
  db.extension :hstore

  db.table :users do |t|
    t.primary_key :id
    t.varchar     :email,    null: false, unique: true
    t.varchar     :password, null: false
    t.varchar     :name,     null: false
    t.integer     :age
    t.user_status :status,   null: false, default: 'registered'
    t.hstore      :tracking, null: false, default: ''
  end

  db.enum :user_status, [:registered, :confirmed_email, :subscriber]

  db.table :posts do |t|
    t.primary_key :id
    t.integer     :user_id, null: false, index: true, references: :users
    t.varchar     :title,   null: false, length: 50
    t.text        :content
    t.array       :tags,    of: :varchar
  end
end
```

### Tables

Tables are described with the `#table` method; you pass it the name of the table and describe the table structure in the block:

``` ruby
db.table :users do |t|
  t.varchar :email
  t.varchar :password
end
```

#### Fields

You can define a field of any type by calling the corresponding method inside the table block passing it the field name and it's attributes. Most of the attributes are optional.

Here's an example table with various kinds of data:

``` ruby
db.table :people do |t|
  t.varchar     :first_name, length: 50, null: false
  t.varchar     :last_name,  length: 60, null: false
  t.integer     :age
  t.numeric     :salary, precision: 10, scale: 2
  t.text        :about
  t.date        :birthday
  t.boolean     :developer
  t.inet        :ip_address
  t.jsonb       :preferences, default: '{}'
  t.array       :interests, of: :varchar
  t.numrange    :salary_expectations

  t.timestamptz :created_at
  t.timestamptz :updated_at
end
```

Passing `null: false` to the field definition makes it `NOT NULL`; passing some value under the `:default` key makes it the default value. You can use `String`s as SQL strings, `Fixnum`s as integers, `Float`s as floating point numbers, `true` & `false` as their SQL counterparts, `Date`s as SQL dates and `Time`s as timestamps. A symbol passed as a default is a special case: it is interpreted as an SQL expression so `t.timestamp :created_at, default: :'now()'` defines a field with a default value of `NOW()`.

Other attributes are type specific, like `:length` for varchars; the following table lists them all (values in parentheses are default attribute values).

| Type          | Attributes       |
| ------------- | ---------------- |
| `smallint`    |                  |
| `integer`     |                  |
| `bigint`      |                  |
| `numeric`     | precision, scale |
| `real`        |                  |
| `float`       |                  |
| `money`       |                  |
| `char`        | length(1)        |
| `varchar`     | length           |
| `text`        |                  |
| `bytea`       |                  |
| `timestamp`   |                  |
| `timestamptz` |                  |
| `date`        |                  |
| `time`        |                  |
| `timetz`      |                  |
| `interval`    | fields           |
| `boolean`     |                  |
| `point`       |                  |
| `line`        |                  |
| `lseg`        |                  |
| `box`         |                  |
| `path`        |                  |
| `polygon`     |                  |
| `circle`      |                  |
| `cidr`        |                  |
| `inet`        |                  |
| `macaddr`     |                  |
| `bit`         | length(1)        |
| `varbit`      | length           |
| `tsvector`    |                  |
| `tsquery`     |                  |
| `uuid`        |                  |
| `json`        |                  |
| `jsonb`       |                  |
| `array`       | of               |
| `int4range`   |                  |
| `int8range`   |                  |
| `numrange`    |                  |
| `tsrange`     |                  |
| `tstzrange`   |                  |
| `daterange`   |                  |
| `chkpass`     |                  |
| `citext`      |                  |
| `cube`        |                  |
| `hstore`      |                  |
| `ean13`       |                  |
| `isbn13`      |                  |
| `ismn13`      |                  |
| `issn13`      |                  |
| `isbn`        |                  |
| `ismn`        |                  |
| `issn`        |                  |
| `upc`         |                  |
| `ltree`       |                  |
| `seg`         |                  |

The `of` attribute of the array type is the only required attribute (you need to specify the array element type here); other attributes either have default values or can be omitted at all.

You can also use your custom types in the same way: `t.user_status :status` creates a field called `status` with `user_status` type. Custom types are explained in a later section of this document.

Primary key is a special case; currently when you create a primary key with DbSchema you get a NOT NULL autoincrementing (by a sequence) integer field with a primary key constraint. There is no way to change the primary key field type or make a complex primary key at the moment; this is planned for future versions of DbSchema.

Primary keys are created with the `#primary_key` method:

``` ruby
db.table :posts do |t|
  t.primary_key :id
  t.varchar :title
end
```

**Important: you can't rename a table or a column just by changing it's name in the schema definition - this will result in a column with the old name being deleted and a column with the new name being added; all data in that table or column will be lost.**

#### Indexes

Indexes are created using the `#index` method: you pass it the field name you want to index:

``` ruby
db.table :users do |t|
  t.varchar :email
  t.index :email
end
```

Unique indexes are created with `unique: true`:

``` ruby
t.index :email, unique: true
```

Simple one-field indexes can be created with `index: true` and `unique: true` options passed to the field definition method so

``` ruby
db.table :users do |t|
  t.varchar :name,  index: true
  t.varchar :email, unique: true
end
```

is essentially the same as

``` ruby
db.table :users do |t|
  t.varchar :name
  t.varchar :email

  t.index :name
  t.index :email, unique: true
end
```

Passing several field names to `#index` makes a multiple index:

``` ruby
db.table :users do |t|
  t.varchar :first_name
  t.varchar :last_name

  t.index :first_name, :last_name
end
```

If you want to specify a custom name for your index, you can pass it in the `:name` option:

``` ruby
t.index :first_name, :last_name, name: :username_index
```

Otherwise the index name will be generated as `"#{table_name}_#{field_names.join('_')}_index"` so the index above will be called `users_first_name_last_name_index`.

You can specify the order of each field in your index - it's either `ASC` (`:asc`, the default), `DESC` (`:desc`), `ASC NULLS FIRST` (`:asc_nulls_first`), or `DESC NULLS LAST` (`:desc_nulls_last`). It looks like this:

``` ruby
db.table :some_table do |t|
  t.integer :col1
  t.integer :col2
  t.integer :col3
  t.integer :col4

  t.index col1: :asc, col2: :desc, col3: :asc_nulls_first, col4: :desc_nulls_last
end
```

By default B-tree indexes are created; if you need an index of a different type you can pass it in the `:using` option:

``` ruby
db.table :users do |t|
  t.array :interests, of: :varchar
  t.index :interests, using: :gin
end
```

You can also create a partial index if you pass some condition as SQL string in the `:where` option:

``` ruby
db.table :users do |t|
  t.varchar :email
  t.index :email, unique: true, where: 'email IS NOT NULL'
end
```

If you need an index on expression you can use the same syntax replacing column names with SQL strings containing the expressions:

``` ruby
db.table :users do |t|
  t.timestamp :created_at
  t.index 'date(created_at)'
end
```

Expression indexes syntax allows specifying an order exactly like in a common index on table fields - just use a hash form like `t.index 'date(created_at)' => :desc`. You can also use an expression in a multiple index.

#### Foreign keys

The `#foreign_key` method defines a foreign key. In it's minimal form it takes a referencing field name and referenced table name:

``` ruby
db.table :users do |t|
  t.primary_key :id
  t.varchar :name
end

db.table :posts do |t|
  t.integer :user_id
  t.varchar :title

  t.foreign_key :user_id, references: :users
end
```

The syntax above assumes that this foreign key references the primary key. If you need to reference another field you can pass a 2-element array in `:references` option, the first element being table name and the second being field name:

``` ruby
db.table :users do |t|
  t.varchar :name
  t.index :name, unique: true # you can only reference either primary keys or unique columns
end

db.table :posts do |t|
  t.varchar :username
  t.foreign_key :username, references: [:users, :name]
end
```

DbSchema also provides a short syntax for simple one-column foreign keys - just pass the `:references` option to the field definition:

``` ruby
db.table :posts do |t|
  t.integer :user_id,  references: :users
  t.varchar :username, references: [:users, :name]
end
```

As with indexes, you can pass your custom name in the `:name` option; default foreign key name looks like `"#{table_name}_#{fkey_fields.first}_fkey"`.

You can also define a composite foreign key consisting of (and referencing) multiple columns; just list them all:

``` ruby
db.table :table_a do |t|
  t.integer :col1
  t.integer :col2
  t.index :col1, :col2, unique: true
end

db.table :table_b do |t|
  t.integer :a_col1
  t.integer :a_col2
  t.foreign_key :a_col1, :a_col2, references: [:table_a, :col1, :col2]
end
```

There are 3 more options to the `#foreign_key` method: `:on_update`, `:on_delete` and `:deferrable`. First two define an action that will be taken when a referenced column is changed or the whole referenced row is deleted, respectively; you can set these to one of `:no_action` (the default), `:restrict`, `:cascade`, `:set_null` or `:set_default`. See [PostgreSQL documentation](https://www.postgresql.org/docs/current/static/ddl-constraints.html#DDL-CONSTRAINTS-FK) for more information.

Passing `deferrable: true` defines a foreign key that is checked at the end of transaction.

#### Check constraints

A check constraint is like a validation on the database side: it checks if the inserted/updated row has valid values.

To define a check constraint you can use the `#check` method passing it the constraint name (no auto-generated names here, sorry) and the condition that must be satisfied, in a form of SQL string.

``` ruby
db.table :users do |t|
  t.primary_key :id
  t.varchar :name
  t.integer :age, null: false

  t.check :valid_age, 'age >= 18'
end
```

As with indexes and foreign keys, DbSchema has a short syntax for simple check constraints - a `:check` option in the method definition:

``` ruby
db.table :products do |t|
  t.primary_key :id
  t.text :name,     null: false
  t.numeric :price, check: 'price > 0'
end
```

### Enum types

PostgreSQL allows developers to create custom enum types; value of enum type is one of a fixed set of values stored in the type definition.

Enum types are declared with the `#enum` method (note that you must call it from the top level of your schema and not from within some table definition):

``` ruby
db.enum :user_status, [:registered, :confirmed_email]
```

Then you can create fields of that type exactly as you would create a field of any built-in type - just call the method with the same name as the type you defined:

``` ruby
db.table :users do |t|
  t.user_status :status, default: 'registered'
end
```

Arrays of enums are also supported - they are described just like arrays of any other element type:

``` ruby
db.enum :user_role, [:user, :manager, :admin]

db.table :users do |t|
  t.array :roles, of: :user_role, default: '{user}'
end
```

### Extensions

PostgreSQL has a [wide variety](https://www.postgresql.org/docs/9.5/static/contrib.html) of extensions providing additional data types, functions and operators. You can use DbSchema to add and remove extensions in your database:

``` ruby
db.extension :hstore
```

*Note that adding and removing extensions in Postgres requires superuser privileges.*

## Configuration

DbSchema must be configured prior to applying the schema. There are 2 methods you can use for that: `configure` and `configure_from_yaml`.

### DbSchema.configure

`configure` is a generic method that receives a hash with all configuration options:

``` ruby
DbSchema.configure(
  adapter:  'postgresql',
  host:     ENV['db_host'],
  port:     ENV['db_port'],
  database: ENV['db_name'],
  user:     ENV['db_user'],
  password: ENV['db_password']
)
```

### DbSchema.configure_from_yaml

`configure_from_yaml` is designed to use with Rails so you don't have to duplicate database connection settings from your `database.yml` in DbSchema configuration. Pass it the full path to your `database.yml` file and your current application environment (`development`, `production` etc), and it will read the db connection settings from that file.

``` ruby
DbSchema.configure_from_yaml(Rails.root.join('config', 'database.yml'), Rails.env)
```

If you need to specify other options you can simply pass them as keyword arguments after the environment:

``` ruby
DbSchema.configure_from_yaml(
  Rails.root.join('config', 'database.yml'),
  Rails.env,
  dry_run: true
)
```

### Configuration options

All configuration options are described in the following table:

| Option      | Default value | Description                                      |
| ----------- | ------------- | ------------------------------------------------ |
| adapter     | `'postgres'`  | Database adapter                                 |
| host        | `'localhost'` | Database host                                    |
| port        | `5432`        | Database port                                    |
| database    | (no default)  | Database name                                    |
| user        | `nil`         | Database user                                    |
| password    | `''`          | Database password                                |
| log_changes | `true`        | When true, schema changes are logged             |
| post_check  | `true`        | When true, database schema is checked afterwards |
| dry_run     | `false`       | When true, no operations are actually made       |

By default DbSchema logs the changes it applies to your database; you can disable that by setting `log_changes` to false.

DbSchema provides an opt-out post-run schema check; it ensures that the schema was applied correctly and there are no remaining differences between your `schema.rb` and the actual database schema. The corresponding `post_check` option is likely to become off by default when DbSchema becomes more stable and battle-tested.

There is also a dry run mode which does not apply the changes to your database - it just logs the necessary changes (if you leave `log_changes` set to `true`). Post check is also skipped in that case.

Dry run may be useful while you are building your schema definition for an existing app; adjust your `schema.rb` and apply it in dry run mode until it fits your database and next dry run doesn't report any changes. Don't forget to turn `dry_run` off afterwards!

## Known problems and limitations

* primary keys are hardcoded to a single NOT NULL integer field with a postgres sequence attached
* array element type attributes are not supported
* precision in all date/time types isn't supported
* no support for databases other than PostgreSQL
* no support for renaming tables & columns

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at [7even/db_schema](https://github.com/7even/db_schema).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
