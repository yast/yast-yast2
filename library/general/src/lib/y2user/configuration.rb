module Y2User
  # Holds references to elements of user configuration like users, groups or passwords.
  # Class itself holds references to different configuration instances.
  # TODO: write example
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
          require "y2user/readers/getent"
          reader = Readers::Getent.new
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
    attr_accessor :passwords

    def initialize(name, users: [], groups: [], passwords: [])
      @name = name
      @users = users
      @groups = groups
      @passwords = passwords
      self.class.register(self)
    end

    def clone_as(new_name)
      result = self.class.new(new_name)
      result.users = users.map { |u| u.clone_to(result) }
      result.groups = users.map { |u| u.clone_to(groups) }
      result.passwords = users.map { |u| u.clone_to(passwords) }

      result
    end
  end
end
