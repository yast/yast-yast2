# typed: false
# ***************************************************************************
#
# Copyright (c) 2002 - 2016 Novell, Inc.
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

require "yast"

module Yast
  # Service not found exception
  class SuSEFirewalServiceNotFound < StandardError
    def initialize(message)
      super message
    end
  end

  # Global Definition of Firewall Services
  # Manages services for SuSEFirewall2 and FirewallD
  class SuSEFirewallServicesClass < Module
    include Yast::Logger

    # this is how services defined by package are distinguished
    DEFINED_BY_PKG_PREFIX = "service:".freeze

    DEFAULT_SERVICE = {
      "tcp_ports"       => [],
      "udp_ports"       => [],
      "rpc_ports"       => [],
      "ip_protocols"    => [],
      "broadcast_ports" => [],
      "name"            => "",
      "description"     => ""
    }.freeze

    def initialize
      textdomain "base"
    end

    # Function returns the map of supported (known) services.
    #
    # @return [Hash{String => String}] supported services
    #
    # **Structure:**
    #
    #     { service_id => localized_service_name }
    #     {
    #         "service:dns-server" => "DNS Server",
    #         "service:vnc" => "Remote Administration",
    #     }
    def GetSupportedServices
      supported_services = {}
      all_services.each do |service_id, service_definition|
        # TRANSLATORS: Name of unknown service. %1 is a requested service id like nfs-server
        supported_services[service_id] = service_definition["name"] || Builtins.sformat(_("Unknown service '%1'"), service_id)
      end
      supported_services
    end

    # Function returns if the service_id is a known (defined) service
    #
    # @param [String] service_id (including the "service:" prefix)
    # @return  [Boolean] if is known (defined)
    def IsKnownService(service_id)
      !service_details(service_id, true).nil?
    end

    # Returns list of service-ids defined by packages.
    # (including the "service:" prefix)
    #
    # @return [Array<String>] service ids
    def GetListOfServicesAddedByPackage
      all_services.keys
    end

    # Function returns needed TCP ports for service
    #
    # @param [String] service (including the "service:" prefix)
    # @return  [Array<String>] of needed TCP ports
    def GetNeededTCPPorts(service)
      service_details(service)["tcp_ports"] || []
    end

    # Function returns needed UDP ports for service
    #
    # @param [String] service (including the "service:" prefix)
    # @return  [Array<String>] of needed UDP ports
    def GetNeededUDPPorts(service)
      service_details(service)["udp_ports"] || []
    end

    # Function returns needed RPC ports for service
    #
    # @param [String] service (including the "service:" prefix)
    # @return  [Array<String>] of needed RPC ports
    def GetNeededRPCPorts(service)
      service_details(service)["rpc_ports"] || []
    end

    # Function returns needed IP protocols for service
    #
    # @param [String] service (including the "service:" prefix)
    # @return  [Array<String>] of needed IP protocols
    def GetNeededIPProtocols(service)
      service_details(service)["ip_protocols"] || []
    end

    # Function returns description of a firewall service
    #
    # @param [String] service (including the "service:" prefix)
    # @return  [String] service description
    def GetDescription(service)
      service_details(service)["description"] || []
    end

    # Function returns needed ports and protocols for service.
    # Service needs to be known (installed in the system).
    # Function throws an exception SuSEFirewalServiceNotFound
    # if service is not known (undefined).
    #
    # @param [String] service (including the "service:" prefix)
    # @return  [Hash{String => Array<String>}] of needed ports and protocols
    #
    # @example
    #   GetNeededPortsAndProtocols ("service:aaa") -> {
    #           "tcp_ports"      => [ "122", "ftp-data" ],
    #           "udp_ports"      => [ "427" ],
    #           "rpc_ports"      => [ "portmap", "ypbind" ],
    #           "ip_protocols"   => [],
    #           "broadcast_ports"=> [ "427" ],
    #   }
    def GetNeededPortsAndProtocols(service)
      DEFAULT_SERVICE.merge(service_details(service))
    end

    # Returns all known services loaded from disk on-the-fly
    # @api private
    def all_services
      ReadServicesDefinedByRPMPackages() if @services.nil?
      @services
    end

    # Sets that configuration was not modified
    def ResetModified
      @sfws_modified = false

      nil
    end

    # Returns whether configuration was modified
    #
    # @return [Boolean] modified
    def GetModified
      @sfws_modified
    end

    # Returns whether the service ID is defined by package.
    # Returns 'false' if it isn't.
    #
    # @param [String] service
    # @return  [Boolean] whether service is defined by package
    #
    # @example
    #   ServiceDefinedByPackage ("http-server") -> false
    #   ServiceDefinedByPackage ("service:http-server") -> true
    def ServiceDefinedByPackage(service)
      service.start_with? DEFINED_BY_PKG_PREFIX
    end

    # Creates a file name from service name defined by package.
    # Service MUST be defined by package, otherwise it returns 'nil'.
    #
    # @param [String] service name (e.g., 'service:abc')
    # @return [String] file name (e.g., 'abc')
    #
    # @example
    #   GetFilenameFromServiceDefinedByPackage ("service:abc") -> "abc"
    #   GetFilenameFromServiceDefinedByPackage ("abc") -> nil
    def GetFilenameFromServiceDefinedByPackage(service)
      if !ServiceDefinedByPackage(service)
        log.error "Service #{service} is not defined by package"
        return nil
      end

      service[/\A#{DEFINED_BY_PKG_PREFIX}(.*)/, 1]
    end

    # Returns SCR Agent definition.
    #
    # @return [Yast::Term] with agent definition
    # @param filefullpath [String] full filename path (to read by this agent)
    # @api private
    def GetMetadataAgent(filefullpath)
      term(
        :IniAgent,
        filefullpath,
        "options"  => [
          "global_values",
          "flat",
          "read_only",
          "ignore_case_regexps"
        ],
        "comments" => [
          # jail followed by anything but jail (immediately)
          "^[ \t]*#[^#].*$",
          # comments that are not commented key:value pairs (see "params")
          # they always use two jails
          "^[ \t]*##[ \t]*[^([a-zA-Z0-9_]+:.*)]$",
          # comments with three jails and more
          "^[ \t]*###.*$",
          # jail alone
          "^[ \t]*#[ \t]*$",
          # (empty space)
          "^[ \t]*$",
          # sysconfig entries
          "^[ \t]*[a-zA-Z0-9_]+.*"
        ],
        "params"   => [
          # commented key:value pairs
          # e.g.: ## Name: service name
          { "match" => ["^##[ \t]*([a-zA-Z0-9_]+):[ \t]*(.*)[ \t]*$", "%s: %s"] }
        ]
      )
    end
  end
end
