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
Yast.import "NetworkInterfaces"

module Y2Firewall
  class Firewalld
    # Class to work with firewalld interfaces
    class Interface
      include Yast::I18n
      # @return [Symbol]
      attr_accessor :id

      # Constructor
      #
      # @param name [String] interface name
      def initialize(name)
        textdomain "firewall"
        @id = name.to_sym
      end

      class << self
        # Return an instance of Y2Firewall::Firewalld
        #
        # @return [Y2Firewall::Firewalld] a firewalld instance
        def fw
          Y2Firewall::Firewalld.instance
        end

        # Return an array with all the known or configured interfaces
        #
        # @return [Array<Y2Firewall::Firewalld::Interface>] known interfaces
        def known
          interfaces = Yast::NetworkInterfaces.List("").reject { |i| i == "lo" }
          interfaces.map { |i| new(i) }
        end

        # Return an array with all the interfaces that belongs to some firewalld
        # zone but are not known (sysconfig configured)
        #
        # @return [Array<Y2Firewall::Firewalld::Interface>] known interfaces
        def unknown
          known_interfaces = Yast::NetworkInterfaces.List("").reject { |i| i == "lo" }
          configured_interfaces = fw.zones.map(&:interfaces).flatten.compact
          (configured_interfaces - known_interfaces).map { |i| new(i) }
        end
      end

      # Return whether the zone is a known one
      #
      # @see .known
      # @return [Boolean] true if the interface is known
      def known?
        Yast::NetworkInterfaces.List("").reject { |i| i == "lo" }.include?(name)
      end

      # @return [String] interface name
      def name
        id.to_s
      end

      # Return the network interface device name in case it is configured or
      # 'Unknown' in other case
      #
      # @return [String] its device name or 'Unknown' if not configured
      def device_name
        return _("Unknown") unless known?
        Yast::NetworkInterfaces.GetValue(name, "NAME")
      end

      # Return the zone name for a given interface from the firewalld instance
      # instead of from the API.
      #
      # @return [Y2Firewall::Firewalld::Zone,nil] zone if it belongs to some or nil otherwise
      def zone
        fw.zones.find { |z| z.interfaces.include?(name) }
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
