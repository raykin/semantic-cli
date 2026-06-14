# frozen_string_literal: true

require "json"
require_relative "semantic_cli/version"
require_relative "semantic_cli/dsl"
require_relative "semantic_cli/option"
require_relative "semantic_cli/fragment"
require_relative "semantic_cli/parser"
require_relative "semantic_cli/runner"
require_relative "semantic_cli/config"
require_relative "semantic_cli/resource"
require_relative "semantic_cli/picker"

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

    def set(key, value)
      SemanticCli.dsl.set(key, value)
    end

    def resource(name, aliases: [], &block)
      SemanticCli.dsl.define_resource(name, aliases: aliases, &block)
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
