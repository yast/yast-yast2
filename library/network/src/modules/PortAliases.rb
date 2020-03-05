# ***************************************************************************
#
# Copyright (c) 2002 - 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# ***************************************************************************
# File:  modules/PortAliases.ycp
# Package:  Ports Aliases.
# Summary:  Definition of Port Aliases.
# Authors:  Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
# Global Definition of Port Aliases for services taken from /etc/services.
# /etc/services are defined by IANA http://www.iana.org/assignments/port-numbers.
# This module provides full listing of port aliases (supporting also multiple
# aliases like "http", "www" and "www-http" for port 80).
# Results are cached, so repeated requests are answered faster.
require "yast"
require "yast2/execute"
require "shellwords"

module Yast
  class PortAliasesClass < Module
    include Yast::Logger

    KNOWN_SERVICES = {
      22   => ["ssh"],
      25   => ["smtp"],
      53   => ["domain"],
      67   => ["bootps"],
      68   => ["bootpc"],
      69   => ["tftp"],
      80   => ["http", "www", "www-http"],
      110  => ["pop3"],
      111  => ["sunrpc"],
      123  => ["ntp"],
      137  => ["netbios-ns"],
      138  => ["netbios-dgm"],
      139  => ["netbios-ssn"],
      143  => ["imap"],
      389  => ["ldap"],
      443  => ["https"],
      445  => ["microsoft-ds"],
      500  => ["isakmp"],
      631  => ["ipp"],
      636  => ["ldaps"],
      873  => ["rsync"],
      993  => ["imaps"],
      995  => ["pop3s"],
      3128 => ["ndl-aas"],
      4500 => ["ipsec-nat-t"],
      8080 => ["http-alt"]
    }.freeze
    private_constant :KNOWN_SERVICES

    Service = Struct.new(:port, :aliases) do
      def to_a
        [port, aliases].flatten.map(&:to_s)
      end
    end

    def main
      textdomain "base"

      # This variable contains characters allowed in port-names, backslashed for regexpmatch()
      @allowed_service_regexp = "^[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789*/+._-]*$"

      @cache_not_allowed_ports = []
    end

    # Function returns if the port name is allowed port name (or number).
    #
    # @return  [Boolean] if allowed
    def IsAllowedPortName(port_name)
      if port_name.nil?
        Builtins.y2error("Invalid port name: %1", port_name)
        false
        # port is number
      elsif Builtins.regexpmatch(port_name, "^[0123456789]+$")
        port_number = Builtins.tointeger(port_name)
        # checking range
        Ops.greater_or_equal(port_number, 0) &&
          Ops.less_or_equal(port_number, 65_535)
        # port is name
      else
        Builtins.regexpmatch(port_name, @allowed_service_regexp)
      end
    end

    # Function returns string describing allowed port name or number.
    #
    # @return  [String] with description
    def AllowedPortNameOrNumber
      # TRANSLATORS: popup informing message, allowed characters for port-names
      _(
        "A port name may consist of the characters 'a-z', 'A-Z', '0-9', and '*+._-'.\n" \
          "A port number may be a number from 0 to 65535.\n" \
          "No spaces are allowed.\n"
      )
    end

    # Function returns list of aliases (port-names and port-numbers) for
    # requested port-number or port-name. Also the requested name or port is returned.
    #
    # @param [String] port-number or port-name
    # @return  [Array] [string] of aliases
    def GetListOfServiceAliases(port)
      # service is a port number
      if Builtins.regexpmatch(port, "^[0123456789]+$")
        service = find_by_port(port)

        return service.to_a if service
      # service is a port name, any space isn't allowed
      elsif IsAllowedPortName(port)
        service = find_by_alias(port)

        return service.to_a if service
      elsif !Builtins.contains(@cache_not_allowed_ports, port)
        @cache_not_allowed_ports = Builtins.add(
          @cache_not_allowed_ports,
          port
        )
        Builtins.y2error("Port name '%1' is not allowed", port)
      else
        Builtins.y2debug("Port name '%1' is not allowed", port)
      end

      [port]
    end

    # Function returns if the requested port-name is known port.
    # Known port have an IANA alias.
    #
    # @param  string port-name
    # @return  [Boolean] if is known
    def IsKnownPortName(port_name)
      # function returns the requested port and aliases if exists
      return true if Ops.greater_than(Builtins.size(GetListOfServiceAliases(port_name)), 1)

      false
    end

    # Function returns a port number for the port name alias
    #
    # @param port_name_or_number
    # @param port_number or nil when not found
    def GetPortNumber(port_name)
      return Builtins.tointeger(port_name) if Builtins.regexpmatch(port_name, "^[0123456789]+$")

      service = services.find { |s| s.aliases.include?(port_name) }
      service&.port
    end

    publish function: :IsAllowedPortName, type: "boolean (string)"
    publish function: :AllowedPortNameOrNumber, type: "string ()"
    publish function: :GetListOfServiceAliases, type: "list <string> (string)"
    publish function: :IsKnownPortName, type: "boolean (string)"
    publish function: :GetPortNumber, type: "integer (string)"

  private

    # Returns the collection of port => service aliases
    #
    # @see #load_services_database
    #
    # @return [Hash<Integer => Array<String>]
    def services
      return @services if @services

      # First, register known services
      @services = KNOWN_SERVICES.map { |port, aliases| Service.new(port, aliases) }

      # Then, process those returned by `getent servies`
      load_services_database.each do |service|
        name, port, aliases = service.chomp.split(" ")

        port = port.to_i
        aliases = [name, aliases&.split].flatten.compact
        service = find_by_port(port)

        if service
          service.aliases |= aliases
        else
          service = Service.new(port, aliases)
          @services << service
        end
      end

      @services
    end

    # Returns services database after performing some cleanup
    #
    # Basically, it manipulates the `getent services` output to discard duplicated lines after
    # removing the protocol.
    #
    # Returned lines will look like
    #
    # EtherNet/IP-1         2222
    # EtherNet-IP-2         44818
    # rfb                   5900 vnc-server
    #
    # @return [Array<String>]
    def load_services_database
      Yast::Execute.stdout.on_target!(
        ["/usr/bin/getent", "services"],
        # remove the protocol from the output
        ["/usr/bin/sed", "-r", "s/(\\S)(\\/\\S+)(.*)?/\\1\\3/"],
        # get rid of duplicated lines
        ["/usr/bin/sort"],
        ["/usr/bin/uniq"]
      ).lines
    end

    # Convenience method to easily find a loaded service by its port number
    #
    # @param port [Integer, String] the port number
    # @return [Service, nil]
    def find_by_port(port_number)
      services.find { |s| s.port == port_number.to_i }
    end

    # Convenience method to easily find a loaded service by alias
    #
    # @param port [Integer, String] the port number
    # @return [Service, nil]
    def find_by_alias(service_alias)
      services.find { |s| s.aliases.include?(service_alias) }
    end
  end

  PortAliases = PortAliasesClass.new
  PortAliases.main
end
