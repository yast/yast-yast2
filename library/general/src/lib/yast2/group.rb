require "yast2/execute"

module Yast2
  class Group
    class << self
      GETENT_GROUP_MAPPING = {
        "name" => 0,
        "passwd" => 1,
        "gid" => 2,
        "users" => 3
      }

      def all
        @all ||= read
      end

      def reset
        @all = nil
      end

      def read
        getent = Yast::Execute.on_target!("/usr/bin/getent", "group", stdout: :capture)
        getent.lines.map do |line|
          values = line.chomp.split(":")
          new(
            values[GETENT_GROUP_MAPPING["name"]],
            gid: values[GETENT_GROUP_MAPPING["gid"]],
            users_name: values[GETENT_GROUP_MAPPING["users"]]&.split(",") || []
          )
        end
      end
    end

    attr_reader :name, :gid, :users_name

    def initialize(name, gid: nil, users_name: [])
      @name = name
      @gid = gid
      @users_name = users_name
    end

    def users
      # lazy load to avoid circular deps
      require "yast2/user"
      User.all.select { |u| u.gid == gid || users_name.include?(u.name) }
    end
  end
end

