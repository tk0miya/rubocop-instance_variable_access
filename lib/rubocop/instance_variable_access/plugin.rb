# frozen_string_literal: true

require "lint_roller"
require "pathname"

module RuboCop
  module InstanceVariableAccess
    # A plugin that integrates rubocop-instance_variable_access with RuboCop's plugin system.
    class Plugin < LintRoller::Plugin
      def about #: LintRoller::About
        LintRoller::About.new(
          name: "rubocop-instance_variable_access",
          version: VERSION,
          homepage: "https://github.com/tk0miya/rubocop-instance_variable_access",
          description: "A RuboCop extension that enforces accessing instance variables through reader methods."
        )
      end

      # @rbs context: untyped
      def supported?(context) #: bool
        context.engine == :rubocop
      end

      # @rbs _context: untyped
      def rules(_context) #: LintRoller::Rules
        project_root = Pathname.new(__dir__.to_s).join("../../..")

        LintRoller::Rules.new(
          type: :path,
          config_format: :rubocop,
          value: project_root.join("config", "default.yml")
        )
      end
    end
  end
end
