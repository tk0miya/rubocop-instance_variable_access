# frozen_string_literal: true

require_relative "lib/rubocop/instance_variable_access/version"

Gem::Specification.new do |spec|
  spec.name = "rubocop-instance_variable_access"
  spec.version = RuboCop::InstanceVariableAccess::VERSION
  spec.authors = ["Takeshi KOMIYA"]
  spec.email = ["i.tkomiya@gmail.com"]

  spec.summary = "A RuboCop extension that enforces accessing instance variables through reader methods."
  spec.description = "rubocop-instance_variable_access provides the Style/InstanceVariableAccess cop, which " \
                     "flags direct reads of instance variables (including class instance variables) outside " \
                     "of their reader method, encouraging access via attr_reader/attr_accessor or a " \
                     "hand-written reader even from within the defining class."
  spec.homepage = "https://github.com/tk0miya/rubocop-instance_variable_access"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}.git"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["default_lint_roller_plugin"] = "RuboCop::InstanceVariableAccess::Plugin"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/
                          .claude/ .vscode/ .rubocop.yml Rakefile Steepfile
                          rbs_collection])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { File.basename(_1) }
  spec.require_paths = ["lib"]

  spec.add_dependency "lint_roller", "~> 1.1"
  spec.add_dependency "rubocop", ">= 1.72", "< 2.0"
end
