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
      service_aliases = [port]

      # service is a port number
      if Builtins.regexpmatch(port, "^[0123456789]+$")
        port_number = port.to_i

        service_aliases << services[port_number]
      # service is a port name, any space isn't allowed
      elsif IsAllowedPortName(port)
        aliases = services.select { |_, v| v.include?(port) }

        if aliases
          service_aliases.unshift(aliases.keys.map(&:to_s))
          service_aliases << aliases.values
        end
      elsif !Builtins.contains(@cache_not_allowed_ports, port)
        @cache_not_allowed_ports = Builtins.add(
          @cache_not_allowed_ports,
          port
        )
        Builtins.y2error("Port name '%1' is not allowed", port)
      else
        Builtins.y2debug("Port name '%1' is not allowed", port)
      end

      service_aliases.compact.flatten.uniq
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

      service = services.select { |_, v| v.include?(port_name) }

      service.keys.first
    end

    # Returns the collection of port => service aliases
    #
    # @see #load_services_database
    #
    # @return [Hash<Integer => Array<String>]
    def services
      return @services if @services

      @services = KNOWN_SERVICES.dup

      load_services_database.each do |service|
        # Each service line contains the name, port, protocol and optionally aliases as follow
        # service-name    port/protocol    service-aliases
        name, port, _protocol, aliases = service.chomp.gsub(/\s+/, " ").split(/[\s,\|]/)

        key = port.to_i
        aliases = [@services[key], name, aliases&.split].flatten.compact.sort.uniq

        @services[key] = aliases
      end

      @services
    end

    # Returns the services enumerated in the system database
    #
    # @return [Array<String>]
    def load_services_database
      Yast::Execute.stdout.on_target!("/usr/bin/getent", "services").lines
    end

    publish function: :IsAllowedPortName, type: "boolean (string)"
    publish function: :AllowedPortNameOrNumber, type: "string ()"
    publish function: :GetListOfServiceAliases, type: "list <string> (string)"
    publish function: :IsKnownPortName, type: "boolean (string)"
    publish function: :GetPortNumber, type: "integer (string)"
  end

  PortAliases = PortAliasesClass.new
  PortAliases.main
end
