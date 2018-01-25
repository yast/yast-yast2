# encoding: utf-8
#
# ***************************************************************************
#
# Copyright (c) 2017 SUSE LLC.
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
require "y2firewall/firewalld"

module Yast
  # This module add support for handling firewalld configuration and it is
  # mainly a firewalld wrapper. It is inteded to be used mostly by YaST
  # modules written in Perl like yast-dns-server.
  class FirewalldWrapperClass < Module
    include Logger

    VALID_PROTOCOLS = ["udp", "tcp"].freeze

    def initialize
      Yast.import "PortAliases"
      Yast.import "PortRanges"
    end

    # Convenience method for calling firewalld.read
    def read
      firewalld.read
    end

    # Convenience method for calling firewalld.write
    def write
      firewalld.write
    end

    # Convenience method for calling firewalld.write_only
    def write_only
      firewalld.write_only
    end

    # Add the port or range of ports with the given protocol to the zone the
    # interface belongs to.
    #
    # @example
    #   FirewalldWrapper.add_port("80", "TCP", "eth0")
    #   FirewalldWrapper.add_port("8080:8090", "TCP", "eth0")
    #   FirewalldWrapper.add_port("nameserver", "UDP", "eth0")
    #
    # @param port_or_range [String] port or range of ports to be added to the zone
    # @param protocol [String] port protocol
    # @param interface [String] interface name
    def add_port(port_or_range, protocol, interface)
      return false unless validate_port(port_or_range)
      return false unless supported_protocol?(protocol)

      zone = interface_zone(interface)
      return false unless zone
      port = "#{port_or_range.sub(":", "-")}/#{protocol.downcase}"
      zone.add_port(port)
    end

    # Remove the port or range of ports with the given protocol to the zone the
    # interface belongs to.
    #
    # @example
    #   FirewalldWrapper.remove_port("80", "TCP", "eth0")
    #   FirewalldWrapper.remove_port("8080:8090", "TCP", "eth0")
    #   FirewalldWrapper.remove_port("nameserver", "UDP", "eth0")
    #
    # @param port_or_range [String] port or range of ports to be removed from
    # the interface zone
    # @param protocol [String] port protocol
    # @param interface [String] interface name
    def remove_port(port_or_range, protocol, interface)
      return false unless validate_port(port_or_range)
      return false unless supported_protocol?(protocol)

      zone = interface_zone(interface)
      return false unless zone
      port = "#{port_or_range.sub(":", "-")}/#{protocol.downcase}"
      zone.remove_port(port)
    end

    publish function: :read, type: "boolean ()"
    publish function: :write, type: "boolean ()"
    publish function: :write_only, type: "boolean ()"
    publish function: :add_port, type: "boolean (string, string, string)"
    publish function: :remove_port, type: "boolean (string, string, string)"

  private

    def firewalld
      Y2Firewall::Firewalld.instance
    end

    # Return whether the given port of range of ports is valid
    #
    # @example
    #   FirewalldWrapper.validate_port("80") #=> true
    #   FirewalldWrapper.validate_port("8080:8090") #=> true
    #   FirewalldWrapper.validate_port("ssh") #=> true
    #   FirewalldWrapper.validate_port("8080:8070") #=> false
    #   FirewalldWrapper.validate_port("klasjdkla") #=> false
    #
    # @param port_or_range [String] port or port range to be added to the zone
    def validate_port(port_or_range)
      if !PortRanges.IsValidPortRange(port_or_range)
        unless PortAliases.GetPortNumber(port_or_range)
          log.error("The given port or range of ports are not valid: #{port_or_range}")
          return false
        end
      end

      true
    end

    # Return whether the given protocol is supported or not
    #
    # @return [Boolean] true if supported; false otherwise
    def supported_protocol?(protocol)
      VALID_PROTOCOLS.include?(protocol.downcase)
    end

    # Return the interface zone if present or nil otherwise
    # Return [Y2Firewall::Firewalld::Zone,nil] the interface zone if present;
    # nil otherwise
    def interface_zone(interface)
      zone = firewalld.zones.find { |z| z.interfaces.include?(interface) }
      log.error("There is no zone for the interface #{interface}") if !zone
      zone
    end
  end

  FirewalldWrapper = FirewalldWrapperClass.new
end
