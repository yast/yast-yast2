require "yast2/execute"
require "date"

require "y2user/group"
require "y2user/user"
require "y2user/password"

Yast.import "UsersSimple"

module Y2User
  module Readers
    # Reads users configuration using old Yast Module UsersSimple.
    class UsersSimple
      def read_to(configuration)
        users = Yast::UsersSimple.GetUsers
        # TODO: only created users, not imported ones for now
        users.each do |user|
          configuration.users << User.new(configuration, user["uid"], gecos: [user["cn"]])
          # lets just use the strongest available
          configuration.passwords << Password.new(configuration, user["uid"],
            value: Yast::Builtins.cryptsha512(user["userPassword"]))
        end
      end
    end
  end
end
