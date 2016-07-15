# encoding: utf-8

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
# File:	modules/PortAliases.ycp
# Package:	Ports Aliases.
# Summary:	Definition of Port Aliases.
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
# Global Definition of Port Aliases for services taken from /etc/services.
# /etc/services are defined by IANA http://www.iana.org/assignments/port-numbers.
# This module provides full listing of port aliases (supporting also multiple
# aliases like "http", "www" and "www-http" for port 80).
# Results are cached, so repeated requests are answered faster.
require "yast"

module Yast
  class PortAliasesClass < Module
    def main
      textdomain "base"

      # an internal service aliases map for port-numbers pointing to port-names,
      # 	aliases are separated by space
      @SERVICE_PORT_TO_NAME = {
        22   => "ssh",
        25   => "smtp",
        53   => "domain",
        67   => "bootps",
        68   => "bootpc",
        69   => "tftp",
        80   => "http www www-http",
        110  => "pop3",
        111  => "sunrpc",
        123  => "ntp",
        137  => "netbios-ns",
        138  => "netbios-dgm",
        139  => "netbios-ssn",
        143  => "imap",
        389  => "ldap",
        443  => "https",
        445  => "microsoft-ds",
        500  => "isakmp",
        631  => "ipp",
        636  => "ldaps",
        873  => "rsync",
        993  => "imaps",
        995  => "pop3s",
        3128 => "ndl-aas",
        4500 => "ipsec-nat-t",
        8080 => "http-alt"
      }

      # an internal service aliases map for port-names pointing to port-numbers
      @SERVICE_NAME_TO_PORT = {
        "ssh"          => 22,
        "smtp"         => 25,
        "domain"       => 53,
        "bootps"       => 67,
        "bootpc"       => 68,
        "tftp"         => 69,
        "http"         => 80,
        "www"          => 80,
        "www-http"     => 80,
        "pop3"         => 110,
        "sunrpc"       => 111,
        "ntp"          => 123,
        "netbios-ns"   => 137,
        "netbios-dgm"  => 138,
        "netbios-ssn"  => 139,
        "imap"         => 143,
        "ldap"         => 389,
        "https"        => 443,
        "microsoft-ds" => 445,
        "isakmp"       => 500,
        "ipp"          => 631,
        "ldaps"        => 636,
        "rsync"        => 873,
        "imaps"        => 993,
        "pop3s"        => 995,
        "ndl-aas"      => 3128,
        "ipsec-nat-t"  => 4500,
        "http-alt"     => 8080
      }

      # This variable contains characters allowed in port-names, backslashed for regexpmatch()
      @allowed_service_regexp = "^[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789*/+._-]*$"

      @cache_not_allowed_ports = []
    end

    # Function returns if the port name is allowed port name (or number).
    #
    # @return	[Boolean] if allowed
    def IsAllowedPortName(port_name)
      if port_name.nil?
        Builtins.y2error("Invalid port name: %1", port_name)
        return false
        # port is number
      elsif Builtins.regexpmatch(port_name, "^[0123456789]+$")
        port_number = Builtins.tointeger(port_name)
        # checking range
        return Ops.greater_or_equal(port_number, 0) &&
            Ops.less_or_equal(port_number, 65_535)
        # port is name
      else
        return Builtins.regexpmatch(port_name, @allowed_service_regexp)
      end
    end

    # Function returns string describing allowed port name or number.
    #
    # @return	[String] with description
    def AllowedPortNameOrNumber
      # TRANSLATORS: popup informing message, allowed characters for port-names
      _(
        "A port name may consist of the characters 'a-z', 'A-Z', '0-9', and '*+._-'.\n" \
          "A port number may be a number from 0 to 65535.\n" \
          "No spaces are allowed.\n"
      )
    end

    # Internal function for preparing string for grep command
    def QuoteString(port_name)
      port_name = Builtins.mergestring(
        Builtins.splitstring(port_name, "\""),
        "\\\""
      )
      port_name = Builtins.mergestring(
        Builtins.splitstring(port_name, "*"),
        "\\*"
      )
      port_name = Builtins.mergestring(
        Builtins.splitstring(port_name, "."),
        "\\."
      )
      port_name
    end

    # Internal function for loading unknown ports into memory and returning them as list[string]
    def LoadAndReturnPortToName(port_number)
      command = Ops.add(
        Ops.add("grep \"^[^#].*[ \\t]", port_number),
        "/\" /etc/services | sed \"s/\\([^ \\t]*\\)[ \\t]*.*/\\1/\""
      )
      found = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      aliases = []

      if found["exit"] == 0
        found["stdout"].split("\n").each do |alias_|
          next if alias_.empty?
          aliases = Builtins.add(aliases, alias_)
        end
      else
        Builtins.y2error(
          "Services Command: %1 -> %2",
          command,
          Ops.get_string(found, "stderr", "")
        )
        return nil
      end

      # store results for later requests
      Ops.set(
        @SERVICE_PORT_TO_NAME,
        port_number,
        Builtins.mergestring(Builtins.toset(aliases), " ")
      )

      Ops.get(@SERVICE_PORT_TO_NAME, port_number, "")
    end

    # Internal function for loading unknown ports into memory and returning them as integer
    def LoadAndReturnNameToPort(port_name)
      if !IsAllowedPortName(port_name)
        Builtins.y2error("Disallwed port-name '%1'", port_name)
        return nil
      end

      command = Ops.add(
        Ops.add("grep --perl-regexp \"^", QuoteString(port_name)),
        "[ \\t]\" /etc/services | sed \"s/[^ \\t]*[ \\t]*\\([^/ \\t]*\\).*/\\1/\""
      )
      found = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      alias_found = nil

      if found["exit"] == 0
        found["stdout"].split("\n").each do |alias_|
          next if alias_.empty?
          alias_found = Builtins.tointeger(alias_)
        end
      else
        Builtins.y2error(
          "Services Command: %1 -> %2",
          command,
          Ops.get_string(found, "stderr", "")
        )
        return nil
      end

      # store results for later requests
      Ops.set(@SERVICE_NAME_TO_PORT, port_name, alias_found)

      alias_found
    end

    # Function returns list of aliases (port-names and port-numbers) for
    # requested port-number or port-name. Also the requested name or port is returned.
    #
    # @param [String] port-number or port-name
    # @return	[Array] [string] of aliases
    def GetListOfServiceAliases(port)
      service_aliases = [port]
      port_number = nil

      # service is a port number
      if Builtins.regexpmatch(port, "^[0123456789]+$")
        port_number = Builtins.tointeger(port)

        sport_name = Ops.get(@SERVICE_PORT_TO_NAME, port_number) do
          LoadAndReturnPortToName(port_number)
        end

        if !sport_name.nil?
          service_aliases = Convert.convert(
            Builtins.union(
              service_aliases,
              Builtins.splitstring(sport_name, " ")
            ),
            from: "list",
            to:   "list <string>"
          )
        end
        # service is a port name, any space isn't allowed
      elsif IsAllowedPortName(port)
        found_alias_port = Ops.get(@SERVICE_NAME_TO_PORT, port) do
          LoadAndReturnNameToPort(port)
        end
        if !found_alias_port.nil?
          service_aliases = Builtins.add(
            service_aliases,
            Builtins.tostring(found_alias_port)
          )

          # search for another port-name aliases when port-number found
          service_aliases = Convert.convert(
            Builtins.union(
              service_aliases,
              Builtins.splitstring(
                Ops.get(@SERVICE_PORT_TO_NAME, found_alias_port) do
                  LoadAndReturnPortToName(found_alias_port)
                end,
                " "
              )
            ),
            from: "list",
            to:   "list <string>"
          )
        end
      else
        if !Builtins.contains(@cache_not_allowed_ports, port)
          @cache_not_allowed_ports = Builtins.add(
            @cache_not_allowed_ports,
            port
          )
          Builtins.y2error("Port name '%1' is not allowed", port)
        else
          Builtins.y2debug("Port name '%1' is not allowed", port)
        end
        return [port]
      end

      Builtins.toset(service_aliases)
    end

    # Function returns if the requested port-name is known port.
    # Known port have an IANA alias.
    #
    # @param	string port-name
    # @return	[Boolean] if is known
    def IsKnownPortName(port_name)
      # function returns the requested port and aliases if exists
      if Ops.greater_than(Builtins.size(GetListOfServiceAliases(port_name)), 1)
        return true
      end
      false
    end

    # Function returns a port number for the port name alias
    #
    # @param port_name_or_number
    # @param port_number or nil when not found
    def GetPortNumber(port_name)
      return Builtins.tointeger(port_name) if Builtins.regexpmatch(port_name, "^[0123456789]+$")

      port_number = Ops.get(@SERVICE_NAME_TO_PORT, port_name) do
        LoadAndReturnNameToPort(port_name)
      end

      # not a known port
      return nil if port_number.nil?

      Builtins.tointeger(port_number)
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
