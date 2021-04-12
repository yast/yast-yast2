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

    def clone_to(configuration)
      # TODO: write it
    end

    def ==(other)
      # TODO: write it
    end
  end
end

