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
    # @return [Boolean] true if given value is allowed; false otherwise
    def IsAllowedPortName(needle)
      if needle.nil?
        log.error(format("Invalid port name: %s", needle))
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

    # Returns a string describing allowed service names and port numbers
    #
    # @return [String] an informative message
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
    # @note given argument will be also included
    #
    # @example when number is given
    #   GetListOfServicesAliases("22") #=> ["22", "ssh"]
    #
    # @example when name or alias is given
    #   GetListOfServicesAliases("ssh") #=> ["22", "ssh"]
    #
    # @example when there is not service for given information
    #   GetListOfServicesAliases("not-exist-yet") => ["not-exist-yet"]
    #
    # @param needle [String] the name, alias or port to look for a service
    # @return [Array<String>] list of aliases, including the port number
    def GetListOfServiceAliases(needle)
      # service is a port number
      if numeric?(needle)
        service = services[needle.to_i]

        return service.to_a if service
      # service is a port name, any space isn't allowed
      elsif IsAllowedPortName(needle)
        service = find_by_alias(needle)

        return service.to_a if service
      elsif !@cache_not_allowed_ports.include?(needle)
        @cache_not_allowed_ports << needle

        log.error(format("Port name '%s' is not allowed", needle))
      else
        log.debug(format("Port name '%s' is not allowed", needle))
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
    # @note when given argument looks like a digit, it will be returned after a proper conversion
    #
    # @param needle [String] the name or alias of the service
    # @return [Integer, nil] a port number if any
    def GetPortNumber(needle)
      return needle.to_i if numeric?(needle)

      service = find_by_alias(needle)
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
    # @see #services_database
    #
    # @return [Hash<Integer => Service>] a list of services indexed by the port
    def services
      @services ||= services_database.each_with_object({}) do |service, result|
        # Extract values splitting the line by spaces or `/`
        name, port, _protocol, aliases = service.split(/\s+|\//)

        port = port.to_i
        aliases = [name, aliases&.split].flatten.compact

        result[port] ||= Service.new(port, [])
        result[port].aliases |= aliases

        result
      end
    end

    # Returns content from services database
    #
    # Each returned line describes one service, and is of the form:
    #
    #     service-name   port/protocol   [aliases ...]
    #
    # @return [Array<String>] list of available services
    def services_database
      Yast::Execute.stdout.on_target!("/usr/bin/getent", "services").lines
    end

    # Convenience method to easily find a loaded service by alias
    #
    # @param port [Integer, String] the port number
    # @return [Service, nil] found service; nil if none
    def find_by_alias(service_alias)
      services.values.find { |s| s.aliases.include?(service_alias) }
    end

    # Convenience method to test if given string can be an integer
    #
    # @param value [String]
    # @return [Boolean] true if the value looks like an integer; false otherwise
    def numeric?(value)
      value.match?(/^-?\d+$/)
    end
  end

  PortAliases = PortAliasesClass.new
  PortAliases.main
end
