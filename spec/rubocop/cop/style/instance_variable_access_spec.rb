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
end
