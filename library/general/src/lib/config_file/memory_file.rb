module ConfigFile
  class MemoryFile
    attr_accessor :content

    def initialize(content = "")
      @content = content
    end

    def read(path)
      @content.dup
    end

    def write(path, content)
      @content = content
    end
  end
end
