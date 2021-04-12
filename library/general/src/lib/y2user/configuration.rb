module Y2User
  class Configuration
    class << self
      def get(name)
        @register ||= {}
        @register[name]
      end

      def register(configuration)
        @register ||= {}
        @register[configuration.name] = configuration
      end

      def remove(configuration)
        name = configuration.is_a?(self) ? configuration.name : configuration

        @register.delete(name)
      end

      def system(reader: nil, force_read: false)
        res = get(:system)
        return res if res && !force_read

        if !reader
          require "y2user/reader/getent"
          reader = Reader::Getent.new
        end

        # TODO: make system config immutable, so it cannot be modified directly
        res = new(:system)
        reader.read_to(res)

        res
      end
    end

    attr_reader :name
    attr_accessor :users
    attr_accessor :groups

    def initialize(name, users: [], groups: [])
      @name = name
      @users = users
      @groups = groups
      self.class.register(self)
    end

    def clone_as(new_name)
      # TODO: write it
    end
  end
end
