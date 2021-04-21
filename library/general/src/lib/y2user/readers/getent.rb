require "yast2/execute"
require "date"

require "y2user/group"
require "y2user/user"
require "y2user/password"

module Y2User
  module Readers
    # Reads users configuration using getent utility.
    class Getent
      def read_to(configuration)
        configuration.users = read_users(configuration)
        configuration.groups = read_groups(configuration)
        configuration.passwords = read_passwords(configuration)
      end

    private

      PASSWD_MAPPING = {
        "name"   => 0,
        "passwd" => 1,
        "uid"    => 2,
        "gid"    => 3,
        "gecos"  => 4,
        "home"   => 5,
        "shell"  => 6
      }.freeze

      def read_users(configuration)
        getent = Yast::Execute.on_target!("/usr/bin/getent", "passwd", stdout: :capture)
        getent.lines.map do |line|
          values = line.chomp.split(":")
          gecos = values[PASSWD_MAPPING["gecos"]] || ""
          User.new(
            configuration,
            values[PASSWD_MAPPING["name"]],
            uid:   values[PASSWD_MAPPING["uid"]],
            gid:   values[PASSWD_MAPPING["gid"]],
            shell: values[PASSWD_MAPPING["shell"]],
            gecos: gecos.split(","),
            home:  values[PASSWD_MAPPING["home"]]
          )
        end
      end

      GROUP_MAPPING = {
        "name"   => 0,
        "passwd" => 1,
        "gid"    => 2,
        "users"  => 3
      }.freeze

      def read_groups(configuration)
        getent = Yast::Execute.on_target!("/usr/bin/getent", "group", stdout: :capture)
        getent.lines.map do |line|
          values = line.chomp.split(":")
          Group.new(
            configuration,
            values[GROUP_MAPPING["name"]],
            gid:        values[GROUP_MAPPING["gid"]],
            users_name: values[GROUP_MAPPING["users"]]&.split(",") || []
          )
        end
      end

      SHADOW_MAPPING = {
        "username"           => 0,
        "value"              => 1,
        "last_change"        => 2,
        "minimum_age"        => 3,
        "maximum_age"        => 4,
        "warning_period"     => 5,
        "inactivity_period"  => 6,
        "account_expiration" => 7
      }.freeze

      def read_passwords(configuration)
        getent = Yast::Execute.on_target!("/usr/bin/getent", "shadow", stdout: :capture)
        getent.lines.map do |line|
          values = line.chomp.split(":")
          max_age = values[SHADOW_MAPPING["maximum_age"]]
          inactivity_period = values[SHADOW_MAPPING["inactivity_period"]]
          Password.new(
            configuration,
            values[SHADOW_MAPPING["username"]],
            value:              values[SHADOW_MAPPING["value"]],
            last_change:        parse_last_change(values[SHADOW_MAPPING["last_change"]]),
            minimum_age:        values[SHADOW_MAPPING["minimum_age"]].to_i,
            maximum_age:        max_age&.to_i,
            warning_period:     values[SHADOW_MAPPING["warning_period"]].to_i,
            inactivity_period:  inactivity_period&.to_i,
            account_expiration: parse_account_expiration(values[SHADOW_MAPPING["account_expiration"]])
          )
        end
      end

      def parse_last_change(value)
        return nil if !value || value.empty?

        return :force_change if value == "0"

        # last_change is days till unix start 1970, so we expand it to number of seconds
        unix_time = value.to_i * 24 * 60 * 60
        Date.strptime(unix_time.to_s, "%s")
      end

      def parse_account_expiration(value)
        return nil if !value || value.empty?

        # last_change is days till unix start 1970, so we expand it to number of seconds
        unix_time = value.to_i * 24 * 60 * 60
        Date.strptime(unix_time.to_s, "%s")
      end
    end
  end
end
