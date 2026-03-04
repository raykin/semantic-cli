# frozen_string_literal: true

require_relative "semantic_cli/version"
require_relative "semantic_cli/dsl"
require_relative "semantic_cli/option"
require_relative "semantic_cli/fragment"
require_relative "semantic_cli/parser"
require_relative "semantic_cli/runner"

module SemanticCli
  class Error < StandardError; end

  class << self
    def dsl
      @dsl ||= DSL.new
    end

    def runner
      @runner ||= Runner.new(dsl)
    end

    def reset!
      @dsl = nil
      @runner = nil
    end
  end

  module DSLHelpers
    def fn(name, &block)
      SemanticCli.dsl.define(name, &block)
    end

    def cmd(name, command)
      SemanticCli.dsl.define(name) { command }
    end

    def run
      SemanticCli.runner.execute(ARGV)
    end

    def macos?
      RUBY_PLATFORM.include?("darwin")
    end

    def linux?
      RUBY_PLATFORM.include?("linux")
    end
  end
end

# Auto-include DSL into top-level context
include SemanticCli::DSLHelpers
