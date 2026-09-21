# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # Checks that instance variables (including class instance variables) are
      # accessed through reader methods rather than referenced directly, even
      # from within the class that defines them.
      #
      # Writing to an instance variable (via `=`, `+=`, `||=`, or multiple
      # assignment) is always allowed, so a memoization idiom such as
      # `@memo ||= expensive_call` is unaffected, since it writes to the
      # variable rather than reading it.
      #
      # A method whose name matches the instance variable (`def name; ...;
      # @name; end`, or its class-method equivalent `def self.name; ...;
      # @name; end`) is treated as that variable's own reader, so referencing
      # it there is not itself an offense, no matter what else the method's
      # body does.
      #
      # @safety
      #   Autocorrection only rewrites `@foo` to `foo` when an `attr_reader`/
      #   `attr_accessor` for the same instance/singleton context already
      #   exists in the same class body. A hand-written reader like the one
      #   above doesn't count, because there is no way to tell whether it is
      #   safe to call in place of `@foo` (it could have side effects, or
      #   require arguments). Otherwise, only the offense is reported; this
      #   cop never generates an `attr_reader`.
      #
      # @example
      #   # bad
      #   class Person
      #     def full_name
      #       "#{@first_name} #{@last_name}"
      #     end
      #   end
      #
      #   # good
      #   class Person
      #     attr_reader :first_name, :last_name
      #
      #     def full_name
      #       "#{first_name} #{last_name}"
      #     end
      #   end
      #
      #   # good (the reader definition itself is not an offense)
      #   class Person
      #     private
      #
      #     def first_name
      #       @first_name
      #     end
      #   end
      #
      #   # good (still just the reader, whatever else it does first)
      #   class Person
      #     def first_name
      #       logger.debug("first_name accessed")
      #       @first_name
      #     end
      #   end
      #
      #   # good (memoization writes to the instance variable rather than reading it)
      #   class Person
      #     def first_name
      #       @first_name ||= compute_first_name
      #     end
      #   end
      class InstanceVariableAccess < Base
        extend AutoCorrector

        MSG = "Use a reader method instead of directly accessing `%<ivar>s`."

        RESTRICT_ON_SEND = %i[attr_reader attr_accessor].freeze

        # @rbs!
        #   def attr_reader_or_accessor?: (RuboCop::AST::Node node) -> bool

        def_node_matcher :attr_reader_or_accessor?, <<~PATTERN
          (send nil? {:attr_reader :attr_accessor} ...)
        PATTERN

        # A candidate offense: an instance variable read that isn't inside the
        # body of a method of the same name. Resolved against the enclosing
        # scope's readers once the whole class/module body has been seen.
        Violation = Data.define(
          :node,      #: RuboCop::AST::Node -- the instance variable node that may be an offense
          :singleton  #: bool -- whether it's in a singleton (class-level) context
        )

        # The readers and pending violations for a single class/module body
        # (or the top level, for the root scope).
        Scope = Struct.new(
          :instance_readers,  #: Hash[Symbol, Symbol] -- known instance-level readers, by variable name
          :class_readers,     #: Hash[Symbol, Symbol] -- known class-level (singleton) readers, by variable name
          :violations,        #: Array[Violation] -- offense candidates collected so far in this scope
          :singleton_depth,   #: Integer -- nesting depth inside `class << self` blocks
          keyword_init: true
        )

        def on_new_investigation #: void
          @scope_stack = []
          push_scope
        end

        def on_investigation_end #: void
          report_violations
          pop_scope
        end

        def on_class(_node) #: void
          push_scope
        end
        alias on_module on_class

        # @rbs _node: RuboCop::AST::Node
        def after_class(_node) #: void
          report_violations
          pop_scope
        end
        alias after_module after_class

        # @rbs _node: RuboCop::AST::Node
        def on_sclass(_node) #: void
          current_scope.singleton_depth += 1
        end

        # @rbs _node: RuboCop::AST::Node
        def after_sclass(_node) #: void
          current_scope.singleton_depth -= 1
        end

        # @rbs node: RuboCop::AST::SendNode
        def on_send(node) #: void
          return if top_level?
          return unless attr_reader_or_accessor?(node)

          registry = singleton_context? ? current_scope.class_readers : current_scope.instance_readers
          node.arguments.each do |arg|
            case arg
            when RuboCop::AST::SymbolNode, RuboCop::AST::StrNode
              name = arg.value.to_sym # steep:ignore
              registry[name] = name
            end
          end
        end

        # @rbs node: RuboCop::AST::Node
        def on_ivar(node) #: void
          return if same_named_method_body?(node)

          current_scope.violations << Violation.new(node:, singleton: civar?(node))
        end

        private

        attr_reader :scope_stack #: Array[Scope] -- the scopes of the classes/modules currently being visited

        def push_scope #: void
          scope_stack.push(
            Scope.new(instance_readers: {}, class_readers: {}, violations: [], singleton_depth: 0)
          )
        end

        def pop_scope #: void
          scope_stack.pop
        end

        def current_scope #: Scope
          scope_stack.last or raise
        end

        def singleton_context? #: bool
          current_scope.singleton_depth.positive?
        end

        # Whether we are outside of any class/module, at the top level of the
        # file. Readers are never registered there, so that a reader defined
        # at the top level cannot unexpectedly match an unrelated top-level
        # instance variable.
        def top_level? #: bool
          scope_stack.size == 1
        end

        def report_violations #: void
          current_scope.violations.each { report_violation(_1) }
        end

        # @rbs violation: Violation
        def report_violation(violation) #: void
          node = violation.node
          registry = violation.singleton ? current_scope.class_readers : current_scope.instance_readers
          reader = registry[bare_ivar_name(node)]

          add_offense(node, message: format(MSG, ivar: node.source)) do |corrector|
            corrector.replace(node, reader.to_s) if reader
          end
        end

        # Whether the instance variable sits in a singleton (class-level)
        # context: inside `def self.x`, or inside `def x` that is itself
        # nested in `class << self`.
        #
        # @rbs node: RuboCop::AST::Node
        def civar?(node) #: bool
          method_node = enclosing_def(node)
          return true unless method_node
          return true if method_node.defs_type?

          boundary = method_node.each_ancestor(:sclass, :class, :module).first
          boundary&.sclass_type? || false
        end

        # Whether `node` is an instance variable read inside the body of a
        # method of the same name, regardless of what else that method's
        # body does.
        #
        # @rbs node: RuboCop::AST::Node
        def same_named_method_body?(node) #: bool
          method_node = enclosing_def(node)
          return false unless method_node

          bare_ivar_name(node) == bare_method_name(method_node)
        end

        # @rbs node: RuboCop::AST::Node
        def enclosing_def(node) #: RuboCop::AST::DefNode?
          node.each_ancestor(:any_def).first #: RuboCop::AST::DefNode?
        end

        # @rbs node: RuboCop::AST::DefNode
        def bare_method_name(node) #: Symbol
          node.method_name.to_s.sub(/[=?]$/, "").to_sym
        end

        # @rbs node: RuboCop::AST::Node
        def bare_ivar_name(node) #: Symbol
          node.children.first.to_s.delete_prefix("@").to_sym
        end
      end
    end
  end
end
