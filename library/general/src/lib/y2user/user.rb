require "yast2/execute"

module Y2User
  # Representing user configuration on system in contenxt of given User Configuration.
  # @note Immutable class.
  class User
    # @return[Y2User::Configuration] reference to configuration in which it lives
    attr_reader :configuration

    # @return[String] user name
    attr_reader :name

    # @return[String, nil] user ID or nil if it is not yet assigned.
    attr_reader :uid

    # @return[String, nil] primary group ID or nil if it is not yet assigned.
    # @note to get primary group use method #primary_group
    attr_reader :gid

    # @return[String, nil] default shell or nil if it is not yet assigned.
    attr_reader :shell

    # @return[String, nil] home directory or nil if it is not yet assigned.
    attr_reader :home

    # @return [Array<String>] Fields in GECOS entry.
    attr_reader :gecos

    # @return[:local, :ldap, :unknown] where is user defined
    attr_reader :source

    # @see respective attributes for possible values
    def initialize(configuration, name, uid: nil, gid: nil, shell: nil, home: nil, gecos: [], source: :unknown)
      # TODO: GECOS
      @configuration = configuration
      @name = name
      @uid = uid
      @gid = gid
      @shell = shell
      @home = home
      @source = source
      @gecos = gecos
    end

    # @return [Y2User::Group, nil] primary group set to given user or
    #   nil if group is not set yet
    def primary_group
      configuration.groups.find { |g| g.gid == gid }
    end

    # @return [Array<Y2User::Group>] list of groups where is user included including primary group
    def groups
      configuration.groups.select { |g| g.users.include?(self) }
    end

    # @return [Y2User::Password] Password configuration assigned to user
    def password
      configuration.passwords.find { |p| p.name == name }
    end

    # @return [String] Returns full name from gecos entry or username if not specified in gecos.
    def full_name
      gecos.first || name
    end

    ATTRS = [:name, :uid, :gid, :shell, :home].freeze

    # Clones user to different configuration object.
    # @return [Y2User::User] newly cloned user object
    def clone_to(configuration)
      new_config = ATTRS.each_with_object({}) { |a, r| r[a] = public_send(a) }
      new_config.delete(:name) # name is separate argument
      self.class.new(configuration, name, new_config)
    end

    # Compares user object if all attributes are same excluding configuration reference.
    # @return [Boolean] true if it is equal
    def ==(other)
      # do not compare configuration to allow comparison between different configs
      ATTRS.all? { |a| public_send(a) == other.public_send(a) }
    end
  end
end
