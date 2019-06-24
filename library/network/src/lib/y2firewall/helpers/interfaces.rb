# encoding: utf-8

#
# ***************************************************************************
#
# Copyright (c) 2018 SUSE LLC.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 or 3 of the GNU General
# Public License as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com
#
# ***************************************************************************
require "yast"
require "y2firewall/firewalld/interface"

module Y2Firewall
  module Helpers
    # Set of helpers methods for operating with NetworkInterfaces and firewalld
    # zones.
    module Interfaces
      def self.included(_base)
        Yast.import "NetworkInterfaces"
      end

      # Return an instance of Y2Firewall::Firewalld
      #
      # @return [Y2Firewall::Firewalld] a firewalld instance
      def firewalld
        Y2Firewall::Firewalld.instance
      end

      # Return the name of interfaces which belongs to the default zone
      #
      # @return [Array<String>] default zone interface names
      def default_interfaces
        known_interfaces.reject(&:zone).map(&:name)
      end

      # Return the zone name for a given interface from the firewalld instance
      # instead of from the API.
      #
      # @param name [String] interface name
      # @return [String, nil] zone name whether belongs to some or nil if not
      def interface_zone(name)
        Y2Firewall::Firewalld::Interface.new(name).zone
      end

      # Convenience method to return the default zone object
      #
      # @return [Y2Firewall::Firewalld::Zone] default zone
      def default_zone
        @default_zone ||= firewalld.find_zone(firewalld.default_zone)
      end

      # Return an array with all the known (sysconfig configured) firewalld
      # interfaces.
      #
      # @return [Array<Y2Firewall::Firewalld::Interface>] known interfaces
      def known_interfaces
        return @known_interfaces if @known_interfaces

        @known_interfaces = Y2Firewall::Firewalld::Interface.known
      end

      # Return an array with all the interfaces configured in some firewalld
      # zone but not configured in sysconfig.
      #
      # @return [Array<Y2Firewall::Firewalld::Interface>] unknown interfaces
      def unknown_interfaces
        Y2Firewall::Firewalld::Interface.unknown
      end
    end
  end
end
