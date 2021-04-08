require "yast2/execute"

module Yast2
  class User
    class << self
      GETENT_PASSWD_MAPPING = {
        "name" => 0,
        "passwd" => 1,
        "uid" => 2,
        "gid" => 3,
        "gecos" => 4,
        "home" => 5,
        "shell" => 6
      }

      def all
        getent = Yast::Execute.on_target!("/usr/bin/getent", "passwd", stdout: :capture)
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

    attr_reader :name, :uid,, :gid, :shell, :home

    # TODO: GECOS
    def initialize(name, uid: nil, gid: nil, shell: nil, home: nil)
      @name = name
      @uid = uid
      @gid = gid
      @shell = shell
      @home = home
    end
  end
end
