require "yast2/execute"

module Y2User
  class User
    attr_reader :configuration, :name, :uid, :gid, :shell, :home

    # TODO: GECOS
    def initialize(configuration, name, uid: nil, gid: nil, shell: nil, home: nil)
      @configuration = configuration
      @name = name
      @uid = uid
      @gid = gid
      @shell = shell
      @home = home
    end

    def primary_group
      configuration.groups.find { |g| g.gid == gid }
    end

    def groups
      configuration.groups.select{ |g| g.users.include?(self) }
    end

    def clone_to(configuration)
      # TODO: write it
    end

    def ==(other)
      # TODO: write it
    end
  end
end
