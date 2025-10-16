module SemanticCli
  class Fragment
    attr_reader :name, :arg, :shell

    def initialize(name, arg, shell)
      @name = name
      @arg = arg
      @shell = shell
    end
  end
end
