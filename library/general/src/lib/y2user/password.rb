require "yast2/execute"
require "y2user/group"

module Y2User
  class ShadowPassword
    class << self
      GETENT_SHADOW_MAPPING = {
        "username" => 0,
        "value" => 1,
        "last_change" => 2,
        "minimum_age" => 3,
        "maximum_age" => 4,
        "warning_period" => 5,
        "inactivity_period" => 6,
        "account_expire_date" => 7
      }

      def all
        @all ||= read
      end

      def reset
        @all = nil
      end

      def read
        getent = Yast::Execute.on_target!("/usr/bin/getent", "shadow", stdout: :capture)
        getent.lines.map do |line|
          values = line.chomp.split(":")
          new(
            values[GETENT_PASSWD_MAPPING["name"]],
            uid: values[GETENT_PASSWD_MAPPING["uid"]],
            gid: values[GETENT_PASSWD_MAPPING["gid"]],
            shell: values[GETENT_PASSWD_MAPPING["shell"]],
            home: values[GETENT_PASSWD_MAPPING["home"]]
          )
        end
      end
    end

    # @return [String] login name for given password
    attr_reader :name
    # @return [String, nil] Encrypted password. It can have several specific values:
    #   - "!" or "*" is disabled login by password
    #   - "" password-less login allowed
    #   - "!..." disabled password. After exclamation mark is old value that no longer can be used for login
    #   - nil means password is not yet set
    attr_reader :value
    # @return [DateTime, nil]
    attr_reader :last_change

    # TODO: GECOS
    def initialize(name, value: nil, last_change: nil, minimum_age: nil,
        maximum_age: nil, warning_period: nil, inactivity_period: nil,
        account_expiration: nil)
      @name = name
      @value = value
      @last_change = last_change
      @minimum_age = minimum_age
      @maximum_age = maximum_age
      @warning_period = warning_period
      @inactivity_period = inactivity_period
      @account_expiration = account_expiration
    end
  end
end
