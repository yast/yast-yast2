require "yast2/execute"

require "y2user/group"
require "y2user/user"
require "y2user/password"

module Y2User
  module Reader
    class Getent
      def read_to(configuration)
        configuration.users = read_users(configuration)
        configuration.groups = read_groups(configuration)
      end

    private

      PASSWD_MAPPING = {
        "name" => 0,
        "passwd" => 1,
        "uid" => 2,
        "gid" => 3,
        "gecos" => 4,
        "home" => 5,
        "shell" => 6
      }

      def read_users(configuration)
        getent = Yast::Execute.on_target!("/usr/bin/getent", "passwd", stdout: :capture)
        getent.lines.map do |line|
          values = line.chomp.split(":")
          User.new(
            configuration,
            values[PASSWD_MAPPING["name"]],
            uid: values[PASSWD_MAPPING["uid"]],
            gid: values[PASSWD_MAPPING["gid"]],
            shell: values[PASSWD_MAPPING["shell"]],
            home: values[PASSWD_MAPPING["home"]]
          )
        end
      end

      GROUP_MAPPING = {
        "name" => 0,
        "passwd" => 1,
        "gid" => 2,
        "users" => 3
      }

      def read_groups(configuration)
        getent = Yast::Execute.on_target!("/usr/bin/getent", "group", stdout: :capture)
        getent.lines.map do |line|
          values = line.chomp.split(":")
          Group.new(
            configuration,
            values[GROUP_MAPPING["name"]],
            gid: values[GROUP_MAPPING["gid"]],
            users_name: values[GROUP_MAPPING["users"]]&.split(",") || []
          )
        end
      end
    end
  end
end
