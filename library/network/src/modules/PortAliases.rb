# Copyright (c) [2013-2020] SUSE LLC
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
require "yast"
require "yast2/execute"
require "shellwords"

module Yast
  # Module providing full listing of port aliases for services, supporting also multiple aliases for
  # the same port (like "http", "www", "www-http" for port 80)
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

    # Internal representation of a service
    Service = Struct.new(:port, :aliases) do
      def to_a
        [port, aliases].flatten.map(&:to_s)
      end
    end

    def main
      textdomain "base"

      @cache_not_allowed_ports = []
    end

    # Whether the given argument is an allowed service name, alias or port
    #
    # @param needle [Integer, String] a service name, alias or port
    # @return  [Boolean] if allowed
    def IsAllowedPortName(needle)
      if needle.nil?
        log.error("Invalid port name: %s" % needle)
        false
      elsif numeric?(needle)
        # port is number
        port_number = needle.to_i

        port_number > 0 && port_number <= 65_535
      else
        # port is name
        needle.match?(/^\S+$/)
      end
    end

    # Returns an string describing allowed service names and port numbers
    #
    # @return [String]
    def AllowedPortNameOrNumber
      # TRANSLATORS: popup informing message, allowed characters for port-names
      _(
        "A port name may consist of the characters 'a-z', 'A-Z', '0-9', and '*+._-'.\n" \
          "A port number may be a number from 0 to 65535.\n" \
          "No spaces are allowed.\n"
      )
    end

    # Returns list of aliases (including the port number) for service.
    #
    # NOTE: given argument will be also included
    #
    # @param needle [String] the name, alias or port to look for a service
    # @return [Array<String>]
    def GetListOfServiceAliases(needle)
      # service is a port number
      if numeric?(needle)
        service = find_by_port(needle)

        return service.to_a if service
      # service is a port name, any space isn't allowed
      elsif IsAllowedPortName(needle)
        service = find_by_alias(needle)

        return service.to_a if service
      elsif !@cache_not_allowed_ports.include?(needle)
        @cache_not_allowed_ports << needle

        log.error("Port name '%s' is not allowed" % needle)
      else
        log.debug("Port name '%s' is not allowed" % needle)
      end

      [needle]
    end

    # Whether the requested argument is a known service
    #
    # @param needle [String] service name, alias or port number
    # @return [Boolean] true is found a service; false otherwise
    def IsKnownPortName(needle)
      return true if GetListOfServiceAliases(needle).size > 1

      false
    end

    # Returns the port for requested service (if any)
    #
    # NOTE: when given argument looks like a digit, it will be returned after a proper conversion
    #
    # @param needle [String] the name or alias of the service
    # @return [Integer, nil] a port number if any
    def GetPortNumber(needle)
      return needle.to_i if numeric?(needle)

      service = services.find { |s| s.aliases.include?(needle) }
      service&.port
    end

    publish function: :IsAllowedPortName, type: "boolean (string)"
    publish function: :AllowedPortNameOrNumber, type: "string ()"
    publish function: :GetListOfServiceAliases, type: "list <string> (string)"
    publish function: :IsKnownPortName, type: "boolean (string)"
    publish function: :GetPortNumber, type: "integer (string)"

  private

    # Returns the collection of services
    #
    # Results are cached, so repeated requests are answered faster.
    #
    # @see #load_services_database
    #
    # @return [Array<Service>]
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

    # Convenience method to test if given string can be an integer
    #
    # @param value [String]
    # @return [Boolean]
    def numeric?(value)
      value.match?(/^-?\d+$/)
    end
  end

  PortAliases = PortAliasesClass.new
  PortAliases.main
end
