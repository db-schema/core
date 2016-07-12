# DbSchema

DbSchema is an opinionated database schema management tool that lets you maintain your DB schema with a single ruby file.

It goes like this:

* you create a `schema.rb` file where you describe the schema you want in a special DSL
* you make your application load this file as early as possible during the application bootup in development and test environments
* each time you need to change the schema you just change the `schema.rb` file and commit it to your VCS

As a result you always have an up-to-date database schema. No need to run and rollback migrations, no need to even think about the extra step - DbSchema compares the schema you want with the schema your database has and applies all necessary changes to the latter.

## Installation

Add this line to your application's Gemfile:

``` ruby
gem 'db_schema'
```

And then execute:

``` sh
$ bundle
```

Or install it yourself as:

``` sh
$ gem install db_schema
```

## Usage

You define your schema with a special DSL; you can put it in `db/schema.rb` file or anywhere you want. Be sure to keep this file under version control.

DbSchema DSL looks like this:

``` ruby
DbSchema.describe do |db|
  db.table :users do |t|
    t.primary_key :id
    t.varchar :email, null: false
    t.varchar :password_digest, length: 40
    t.timestamptz :created_at
    t.timestamptz :updated_at

    t.index :email, unique: true
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

Fields of any types are defined by calling methods

You can define a field of any type by calling the appropriate method inside the table block passing it the field name and it's attributes. Most of the attributes are optional.

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

Passing `null: false` to the field definition makes it `NOT NULL`; passing some value under the `:default` key makes it the default value. Passing a symbol as a default is interpreted as a function call so `t.timestamp :created_at, default: :now` defines a field with a default value of `NOW()`; strings, numbers, timestamps etc are evaluated "as is".

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

Passing several field names makes a multiple index:

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

By default B-tree indexes are created; if you need to create an index of a different type you can pass it in the `:using` option:

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

Be warned though that you have to specify the condition exactly as PostgreSQL outputs it in `psql` with `\d table_name` command; otherwise your index will be recreated on each DbSchema run. This will be fixed in a later DbSchema version.

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/7even/db_schema.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
