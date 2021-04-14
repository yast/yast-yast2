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

    ATTRS = [:name, :uid, :gid, :shell, :home]

    def clone_to(configuration)
      new_config = ATTRS.each_with_object({}) { |a, r| r[a] = public_send(a) }
      new_config.delete(:name) # name is separate argument
      self.class.new(configuration, name, new_config)
    end

    def ==(other)
      # do not compare configuration to allow comparison between different configs
      ATTRS.all? { |a| public_send(a) == other.public_send(a) }
    end
  end
end
