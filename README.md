# RuboCop::InstanceVariableAccess

A RuboCop extension that provides `Style/InstanceVariableAccess`, a cop that
enforces accessing instance variables (and class instance variables) through
reader methods, even from inside the class that defines them.

## Why?

Wrapping instance variables in reader methods, even inside the class that
defines them, follows the
[Barewords Pattern](https://www.alchemists.io/articles/barewords_pattern):

- A typo in a method name raises `NameError` immediately, while a typo in
  an instance variable name (`@nmae`) silently returns `nil`.
- A reader is easier to extend later (add memoization, a default value, or
  validation) without touching every call site.
- Ruby's own hash value omission syntax (`{x:}`) ended up supporting
  either a local variable or a method like `attr_reader`.

This does mean a reader becomes part of the class's public API unless it is
`private`; this cop doesn't care about visibility, so keep a reader private
when the attribute isn't meant to be exposed outside the class.

Further reading:

- [Barewords Pattern](https://www.alchemists.io/articles/barewords_pattern)
- [Feature #14579 - Hash value omission](https://bugs.ruby-lang.org/issues/14579)

## Installation

Install the gem:

```bash
bundle add rubocop-instance_variable_access --group development,test --require false
```

## Usage

Add the following to your `.rubocop.yml`:

```yaml
plugins:
  - rubocop-instance_variable_access
```

## The cop

`Style/InstanceVariableAccess` flags:

```ruby
# bad
class Person
  def full_name
    "#{@first_name} #{@last_name}"
  end
end
```

and suggests:

```ruby
# good
class Person
  attr_reader :first_name, :last_name

  def full_name
    "#{first_name} #{last_name}"
  end
end
```

Writing to an instance variable is always allowed, so a memoization idiom
such as `@memo ||= expensive_call` is unaffected. Reading that same
instance variable anywhere else while computing the value being assigned
to it is allowed too, whether the assignment is a plain `=`
(`@count = @count + 1`, `@count = compute(@count)`) or a compound
assignment that reads it again explicitly (`@count += compute(@count)`).

A method whose name matches the instance variable (`def first_name; ...;
@first_name; end`) is treated as that variable's own reader, so referencing
it there is not flagged either, no matter what else the method does first.
Class instance variables (e.g. `@total` inside `def self.total` or
`class << self`) are checked the same way as regular instance variables.

An instance variable read inside a block passed to `instance_eval`,
`instance_exec`, `class_eval`, or `module_eval` on anything other than
`self` isn't flagged, since `self` (and therefore whose instance variable
is actually being read) changes inside that block:

```ruby
# good: `@first_name` belongs to `other`, not to `Person`
class Person
  def borrow_name_from(other)
    other.instance_eval { @first_name }
  end
end
```

Autocorrection only rewrites `@foo` to `foo` when an `attr_reader`/
`attr_accessor` for `foo` already exists in the same class body; a
hand-written reader doesn't count, since there's no way to tell whether
it's safe to call in place of `@foo` (it could have side effects, or
require arguments). Otherwise, only the offense is reported, since
generating an `attr_reader` automatically could unintentionally widen the
method's visibility.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and
then run `bundle exec rake release`, which will create a git tag for the
version, push git commits and the created tag, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/tk0miya/rubocop-instance_variable_access. This project is
intended to be a safe, welcoming space for collaboration, and contributors
are expected to adhere to the
[code of conduct](https://github.com/tk0miya/rubocop-instance_variable_access/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the RuboCop::InstanceVariableAccess project's
codebases, issue trackers, chat rooms and mailing lists is expected to
follow the
[code of conduct](https://github.com/tk0miya/rubocop-instance_variable_access/blob/main/CODE_OF_CONDUCT.md).
