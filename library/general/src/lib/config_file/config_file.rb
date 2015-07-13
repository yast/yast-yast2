module ConfigFile
  class ConfigFile
    def initialize(parser, file_path, file_class: File)
      @file_class = file_class
      @parser = parser
      @file_path = file_path
    end

    def write(changes_only: false)
      merge_changes if changes_only
      @file_class.write(@file_path, @parser.serialize(data))
    end

    def read
      self.data = @parser.parse(@file_class.read(@file_path))
    end

  protected

    attr_accessor :data

    def merge_changes
      new_data = data.dup
      read
      # TODO recursive merge
      date.merge(new_data)
    end
  end
end
