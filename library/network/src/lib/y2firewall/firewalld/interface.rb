# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "yast"
require "y2firewall/firewalld"

module Y2Firewall
  class Firewalld
    # Class to work with firewalld interfaces
    class Interface
      # @return [Symbol]
      attr_accessor :id

      # Constructor
      #
      # @param name [String] interface name
      def initialize(name)
        Yast.import "NetworkInterfaces"

        @id = name.to_sym
      end

      # Return an array with all the known or configured interfaces
      #
      # @return [Array<Y2Firewall::Firewalld::Interface>] known interfaces
      def self.known
        Yast.import "NetworkInterfaces"
        interfaces = Yast::NetworkInterfaces.List("").reject { |i| i == "lo" }

        interfaces.map { |i| new(i) }
      end

      # @return [String] interface name
      def name
        id.to_s
      end

      # @return [String] device name
      def device_name
        Yast::NetworkInterfaces.GetValue(name, "NAME")
      end

      # Return the zone name for a given interface from the firewalld instance
      # instead of from the API.
      #
      # @return [String, nil] zone name whether belongs to some or nil if not
      def zone
        zone = fw.zones.find { |z| z.interfaces.include?(id.to_s) }

        zone ? zone.name : nil
      end

    private

      # Return an instance of Y2Firewall::Firewalld
      #
      # @return [Y2Firewall::Firewalld] a firewalld instance
      def fw
        Y2Firewall::Firewalld.instance
      end
    end
  end
end
