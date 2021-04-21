require "yast2/execute"

module Y2User
  # Represents user groups on system.
  class Group
    # @return[Y2User::Configuration] reference to configuration in which it lives
    attr_reader :configuration

    # @return[String] group name
    attr_reader :name

    # @return[String, nil] group id  or nil if it is not yet assigned.
    attr_reader :gid

    # @return[Array<String>] list of user names
    # @note to get list of users in given group use method #groups
    attr_reader :users_name

    # @return[:local, :ldap, :unknown] where is user defined
    attr_reader :source

    # @see respective attributes for possible values
    def initialize(configuration, name, gid: nil, users_name: [], source: :unknown)
      @configuration = configuration
      @name = name
      @gid = gid
      @users_name = users_name
      @source = source
    end

    # @return [Array<Y2User::User>] all users in this group, including ones that
    # has it as primary group
    def users
      configuration.users.select { |u| u.gid == gid || users_name.include?(u.name) }
    end

    ATTRS = [:name, :gid, :users_name].freeze

    # Clones group to different configuration object.
    # @return [Y2User::Group] newly cloned group object
    def clone_to(configuration)
      new_config = ATTRS.each_with_object({}) { |a, r| r[a] = public_send(a) }
      new_config.delete(:name) # name is separate argument
      self.class.new(configuration, name, new_config)
    end

    # Compares group object if all attributes are same excluding configuration reference.
    # @return [Boolean] true if it is equal
    def ==(other)
      # do not compare configuration to allow comparison between different configs
      ATTRS.all? { |a| public_send(a) == other.public_send(a) }
    end
  end
end
