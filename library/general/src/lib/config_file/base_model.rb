module ConfigFile
  # A base class for models. Represents a configuration file as an object
  # with domain-specific attributes/methods. For persistent storage, use load and save,
  # Non-responsibilities: actual storage and parsing (both delegated). There is no caching involved.
  class BaseModel
    def initialize(parser, file_path, file_class: File)
      @file_class = file_class
      @parser = parser
      @file_path = file_path
    end

    def save(changes_only: false)
      merge_changes if changes_only
      @file_class.write(@file_path, @parser.serialize(data))
    end

    def load
      self.data = @parser.parse(@file_class.read(@file_path))
    end

  protected

    attr_accessor :data

    def merge_changes
      new_data = data.dup
      read
      # TODO recursive merge
      data.merge(new_data)
    end
  end
end
