# frozen_string_literal: true

require_relative "semantic_cli/version"
require_relative "semantic_cli/dsl"
require_relative "semantic_cli/option"
require_relative "semantic_cli/fragment"
require_relative "semantic_cli/parser"
require_relative "semantic_cli/runner"

module SemanticCli
  class Error < StandardError; end
  # Your code goes here...

  # Global DSL instance
  DSL_INSTANCE = SemanticCli::DSL.new
  RUNNER_INSTANCE = SemanticCli::Runner.new(DSL_INSTANCE)

  # Auto-included DSL methods
  module DSLHelpers
    def fn(name, &block)
      DSL_INSTANCE.define(name, &block)
    end

    def run
      RUNNER_INSTANCE.execute(ARGV)
    end
  end
end

# Auto-include DSL into top-level context
include SemanticCli::DSLHelpers
