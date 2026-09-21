# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::InstanceVariableAccess, :config do
  context "when the method name does not match the ivar name" do
    it "registers an offense" do
      expect_offense(<<~RUBY)
        class Foo
          def full_name
            @first
            ^^^^^^ Use a reader method instead of directly accessing `@first`.
          end
        end
      RUBY
    end
  end

  context "with an ivar used inside string interpolation" do
    it "registers an offense" do
      expect_offense(<<~RUBY)
        class Person
          def greeting
            "hello \#{@name}"
                     ^^^^^ Use a reader method instead of directly accessing `@name`.
          end
        end
      RUBY
    end
  end

  context "with multiple ivars used in the same expression" do
    it "registers an offense for each ivar" do
      expect_offense(<<~RUBY)
        class Person
          def full_name
            @first + @last
            ^^^^^^ Use a reader method instead of directly accessing `@first`.
                     ^^^^^ Use a reader method instead of directly accessing `@last`.
          end
        end
      RUBY
    end
  end

  context "with an ivar written via ivasgn/op_asgn/or_asgn/masgn" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class Foo
          def set
            @a = 1
            @b += 1
            @c ||= 1
            @d, @e = 1, 2
          end
        end
      RUBY
    end
  end

  context "with the memoization idiom" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class Foo
          def memo
            @memo ||= expensive_call
          end
        end
      RUBY
    end
  end

  context "with a hand-written same-named reader" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class Foo
          private

          def name
            @name
          end
        end
      RUBY
    end
  end

  context "with a hand-written reader that does other things before returning the ivar" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class Foo
          def name
            logger.debug("name accessed")
            @name
          end
        end
      RUBY
    end
  end

  context "with a hand-written reader that takes arguments" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class Foo
          def name(default = nil)
            @name || default
          end
        end
      RUBY
    end
  end

  context "with sibling classes" do
    it "does not let a reader in one class match an ivar in another" do
      expect_offense(<<~RUBY)
        class A
          attr_reader :foo
        end

        class B
          def show
            @foo
            ^^^^ Use a reader method instead of directly accessing `@foo`.
          end
        end
      RUBY

      expect_no_corrections
    end
  end

  context "with a nested class" do
    context "when the reader is declared on the outer class" do
      it "does not let it match an ivar in the inner class" do
        expect_offense(<<~RUBY)
          class Outer
            attr_reader :foo

            class Inner
              def show
                @foo
                ^^^^ Use a reader method instead of directly accessing `@foo`.
              end
            end
          end
        RUBY

        expect_no_corrections
      end
    end

    context "when the reader is declared on the inner class" do
      it "does not let it match an ivar in the outer class" do
        expect_offense(<<~RUBY)
          class Outer
            class Inner
              attr_reader :foo
            end

            def show
              @foo
              ^^^^ Use a reader method instead of directly accessing `@foo`.
            end
          end
        RUBY

        expect_no_corrections
      end
    end
  end

  context "with a class instance variable" do
    context "when referenced in `def self.x`" do
      it "registers an offense" do
        expect_offense(<<~RUBY)
          class Foo
            def self.show_total
              count_all
              @total
              ^^^^^^ Use a reader method instead of directly accessing `@total`.
            end
          end
        RUBY
      end
    end

    context "when referenced inside `class << self`" do
      it "registers an offense" do
        expect_offense(<<~RUBY)
          class Foo
            class << self
              def show_total
                count_all
                @total
                ^^^^^^ Use a reader method instead of directly accessing `@total`.
              end
            end
          end
        RUBY
      end
    end

    context "when referenced directly in the class body, outside any method" do
      it "registers an offense" do
        expect_offense(<<~RUBY)
          class Foo
            do_something
            @total
            ^^^^^^ Use a reader method instead of directly accessing `@total`.
          end
        RUBY
      end
    end

    context "with a hand-written same-named reader defined with `def self.x`" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          class Foo
            def self.total
              @total
            end
          end
        RUBY
      end
    end

    context "with a hand-written same-named reader defined inside `class << self`" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          class Foo
            class << self
              def total
                @total
              end
            end
          end
        RUBY
      end
    end
  end

  context "when only an instance-level reader exists" do
    it "autocorrects the ivar reference but leaves the civar reference alone" do
      expect_offense(<<~RUBY)
        class Foo
          attr_reader :name

          def full_name
            "\#{@name} something"
               ^^^^^ Use a reader method instead of directly accessing `@name`.
          end

          def self.describe_name
            @name
            ^^^^^ Use a reader method instead of directly accessing `@name`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class Foo
          attr_reader :name

          def full_name
            "\#{name} something"
          end

          def self.describe_name
            @name
          end
        end
      RUBY
    end
  end

  context "when only a hand-written same-named reader exists (no attr_reader/attr_accessor)" do
    it "reports an offense without autocorrecting" do
      expect_offense(<<~RUBY)
        class Foo
          def name
            @name
          end

          def full_name
            "\#{@name} something"
               ^^^^^ Use a reader method instead of directly accessing `@name`.
          end
        end
      RUBY

      expect_no_corrections
    end
  end

  context "when only a class-level (singleton) reader exists" do
    it "autocorrects the civar reference but leaves the ivar reference alone" do
      expect_offense(<<~RUBY)
        class Foo
          class << self
            attr_reader :name
          end

          def full_name
            "\#{@name} something"
               ^^^^^ Use a reader method instead of directly accessing `@name`.
          end

          def self.full_name
            @name
            ^^^^^ Use a reader method instead of directly accessing `@name`.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        class Foo
          class << self
            attr_reader :name
          end

          def full_name
            "\#{@name} something"
          end

          def self.full_name
            name
          end
        end
      RUBY
    end
  end

  context "when a reader is declared after its usage in the same class" do
    it "still finds it and autocorrects" do
      expect_offense(<<~RUBY)
        class Foo
          def full_name
            "\#{@name} something"
               ^^^^^ Use a reader method instead of directly accessing `@name`.
          end

          attr_reader :name
        end
      RUBY

      expect_correction(<<~RUBY)
        class Foo
          def full_name
            "\#{name} something"
          end

          attr_reader :name
        end
      RUBY
    end
  end

  context "when no reader exists" do
    it "reports an offense without autocorrecting" do
      expect_offense(<<~RUBY)
        class Foo
          def full_name
            @name
            ^^^^^ Use a reader method instead of directly accessing `@name`.
          end
        end
      RUBY

      expect_no_corrections
    end
  end

  context "when outside of any class or module, at the top level" do
    context "with a same-named def" do
      it "does not autocorrect" do
        expect_offense(<<~RUBY)
          def name
            @name
          end

          def full_name
            @name
            ^^^^^ Use a reader method instead of directly accessing `@name`.
          end
        RUBY

        expect_no_corrections
      end
    end

    context "with a same-named attr_reader" do
      it "does not autocorrect" do
        expect_offense(<<~RUBY)
          attr_reader :name

          def full_name
            @name
            ^^^^^ Use a reader method instead of directly accessing `@name`.
          end
        RUBY

        expect_no_corrections
      end
    end

    context "with a same-named `def self.x`" do
      it "does not autocorrect" do
        expect_offense(<<~RUBY)
          def self.name
            @name
          end

          def self.full_name
            @name
            ^^^^^ Use a reader method instead of directly accessing `@name`.
          end
        RUBY

        expect_no_corrections
      end
    end
  end

  context "with a self-referential ivar assignment (`@x = @x + 1`)" do
    it "does not register an offense, just like the equivalent `@x += 1`" do
      expect_no_offenses(<<~RUBY)
        class Foo
          def increment
            @count = (@count + 1) % 10
          end
        end
      RUBY
    end
  end

  context "with an ivar used as an argument while computing its own new value" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class Foo
          def set
            @x = process(@x)
          end
        end
      RUBY
    end
  end

  context "with a self-referential compound assignment (`@x += @x + 1`)" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class Foo
          def increment
            @x += @x + 1
          end
        end
      RUBY
    end
  end

  context "with a self-referential `||=`/`&&=`" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class Foo
          def memoize
            @x ||= @x || fallback
            @y &&= @y && extra
          end
        end
      RUBY
    end
  end

  context "with a compound assignment whose value reads a different ivar" do
    it "still registers an offense for the other ivar" do
      expect_offense(<<~RUBY)
        class Foo
          def set
            @a += @b + 1
                  ^^ Use a reader method instead of directly accessing `@b`.
          end
        end
      RUBY
    end
  end

  context "with a compound assignment whose target isn't an ivar" do
    it "still registers an offense for an ivar read in its value" do
      expect_offense(<<~RUBY)
        class Foo
          def set(array, obj)
            array[0] += @x
                        ^^ Use a reader method instead of directly accessing `@x`.
            obj.attr += @x
                        ^^ Use a reader method instead of directly accessing `@x`.
          end
        end
      RUBY
    end
  end

  context "with a self-referential read on the right-hand side of a multiple assignment" do
    it "still registers an offense, since multiple assignment isn't exempted" do
      expect_offense(<<~RUBY)
        class Foo
          def set
            @x, @y = @x, 2
                     ^^ Use a reader method instead of directly accessing `@x`.
          end
        end
      RUBY
    end
  end

  context "with an ivar assignment whose value reads a different ivar" do
    it "still registers an offense for the other ivar" do
      expect_offense(<<~RUBY)
        class Foo
          def set
            @a = @b + 1
                 ^^ Use a reader method instead of directly accessing `@b`.
          end
        end
      RUBY
    end
  end

  context "with a same-named ivar assigned in a different method" do
    it "still registers an offense for the unrelated read" do
      expect_offense(<<~RUBY)
        class Foo
          def read
            @x
            ^^ Use a reader method instead of directly accessing `@x`.
          end

          def write
            @x = 1
          end
        end
      RUBY
    end
  end

  context "with a `def` nested inside an assignment to the same-named ivar" do
    it "still registers an offense for the read inside the nested method body" do
      expect_offense(<<~RUBY)
        class Foo
          def outer
            @x = def foo
              @x
              ^^ Use a reader method instead of directly accessing `@x`.
            end
          end
        end
      RUBY
    end
  end

  context "with an ivar read inside `instance_eval`/`instance_exec`/`class_eval`/`module_eval` on another object" do
    it "does not register an offense, since `self` no longer refers to the enclosing class" do
      expect_no_offenses(<<~RUBY)
        class Foo
          def a(klass)
            klass.instance_eval { @enum_accessors }
          end

          def b(obj)
            obj.instance_exec { @x }
          end

          def c(klass)
            klass.class_eval { @y }
          end

          def d(mod)
            mod.module_eval { @z }
          end
        end
      RUBY
    end
  end

  context "with an ivar read inside `instance_eval` called on `self`" do
    it "still registers an offense, since `self` does not actually change" do
      expect_offense(<<~RUBY)
        class Foo
          def show
            self.instance_eval { @x }
                                 ^^ Use a reader method instead of directly accessing `@x`.
          end
        end
      RUBY
    end
  end

  context "with an ivar read inside `instance_eval` called with an implicit receiver" do
    it "still registers an offense, since an implicit receiver is also `self`" do
      expect_offense(<<~RUBY)
        class Foo
          def show
            instance_eval { @x }
                            ^^ Use a reader method instead of directly accessing `@x`.
          end
        end
      RUBY
    end
  end

  context "with an ivar read inside a numbered-parameter block passed to `instance_eval`" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class Foo
          def build(klass)
            klass.instance_eval { @x + _1 }
          end
        end
      RUBY
    end
  end

  context "with an ivar read inside a plain block that isn't `instance_eval`" do
    it "still registers an offense" do
      expect_offense(<<~RUBY)
        class Foo
          def show(items)
            items.each { @x }
                         ^^ Use a reader method instead of directly accessing `@x`.
          end
        end
      RUBY
    end
  end

  context "with an ivar read inside a block nested inside `instance_eval`" do
    it "does not register an offense, since the changed `self` carries into the nested block" do
      expect_no_offenses(<<~RUBY)
        class Foo
          def build(klass)
            klass.instance_eval { [1, 2].each { @x } }
          end
        end
      RUBY
    end
  end

  context "with a `def` nested inside an `instance_eval` block" do
    it "still registers an offense for the ivar read in the method body" do
      expect_offense(<<~RUBY)
        class Foo
          def build(klass)
            klass.instance_eval do
              def bar
                @x
                ^^ Use a reader method instead of directly accessing `@x`.
              end
            end
          end
        end
      RUBY
    end
  end
end
