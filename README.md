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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/7even/db_schema.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
