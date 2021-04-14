require "yast2/execute"

module Y2User
  class Group
    attr_reader :configuration, :name, :gid, :users_name

    def initialize(configuration, name, gid: nil, users_name: [])
      @configuration = configuration
      @name = name
      @gid = gid
      @users_name = users_name
    end

    def users
      configuration.users.select { |u| u.gid == gid || users_name.include?(u.name) }
    end

    ATTRS = [:name, :gid, :users_name]

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

