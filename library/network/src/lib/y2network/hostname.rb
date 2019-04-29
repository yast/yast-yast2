# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

module Y2Network
  # This class represents the system's hostname
  class Hostname
    # @return [String] host fully qualified domain name
    attr_accessor :fqdn

    # Constructor
    #
    # @param fqdn [String]
    def initialize(fqdn: "")
      @fqdn = fqdn
    end

    # return the domain part of the hostname
    #
    # @return [string] hostname domain's part
    def domain
      fqdn.split(".")[1..-1].join(".")
    end

    # return the short part of the hostname
    #
    # @return [string] hostname short part
    def short
      fqdn.split(".")[0]
    end
  end
end
