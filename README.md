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

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/7even/db_schema.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
