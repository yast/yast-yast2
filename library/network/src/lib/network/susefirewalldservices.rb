# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2016 Novell, Inc.
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
#
# Package:	Firewall Services, Ports Aliases.
# Summary:	Definition of Supported Firewall Services and Port Aliases for FirewallD
# Authors:	Markos Chandras <mchandras@suse.de>
#
# Global Definition of Firewall Services
# Defined using TCP, UDP and RPC ports and IP protocols and Broadcast UDP
# ports. Results are cached, so repeating requests are answered faster.

require "yast"
require "network/susefirewallservices"

module Yast
  class SuSEFirewalldServicesClass < SuSEFirewallServicesClass
    include Yast::Logger

    SERVICES_DIR = ["/etc/firewalld/services", "/usr/lib/firewalld/services"].freeze

    IGNORED_SERVICES = ["..", "."].freeze

    def initialize
      @services = nil

      @known_services_features = {
        "TCP"     => "tcp_ports",
        "UDP"     => "udp_ports",
        "IP"      => "ip_protocols",
        "MODULES" => "modules"
      }

      @known_metadata = { "Name" => "name", "Description" => "description" }

      # firewall needs restarting. Always false for firewalld
      @sfws_modified = false
    end

    # Reads services that can be used in FirewallD
    # @note Contrary to SF2 we do not read the full service details here
    # @note since that would mean to issue 5-6 API calls for every service
    # @note file which will take a lot of time for no particular reason.
    # @note We will read the full service information if needed in the
    # @note service_details method.
    # @return [Boolean] if successful
    # @api private
    def ReadServicesDefinedByRPMPackages
      log.info "Reading FirewallD services from #{SERVICES_DIR.join(" and ")}"

      @services ||= {}

      SuSEFirewall.api.services.each do |service_name|
        # Init everything
        @services[service_name] = {}
        @known_services_features.merge(@known_metadata).each_value do |param|
          # Set a good name for our service until we read its information
          @services[service_name][param] = case param
          when "description"
            # We intentionally don't call the API here. We will use it as a
            # flag to populate the full service details later on.
            default_service_description(service_name)
          when "name"
            # We have to call the API here because there are callers which
            # expect to at least provide a sensible service name without
            # worrying for the full service details. This is going to be
            # expensive though since the cost of calling --get-short grows
            # linearly with the number of available services :-(
            SuSEFirewall.api.service_short(service_name)
          else
            []
          end
        end
      end
    end

    # Returns service definition.
    # See @services for the format.
    # If `silent` is not defined or set to `true`, function throws an exception
    # SuSEFirewalServiceNotFound if service is not found on disk.
    #
    # @note Since we do not do full service population in ReadServicesDefinedByRPMPackages
    # @note we have to do it here but only if the service hasn't been populated
    # @note before. The way we determine if the service has been populated or not
    # @note is to look at the "description" key.
    #
    # @param [String] service name (may include the "service:" prefix)
    # @param [String] (optional) whether to silently return nil
    #                 when service is not found (default false)
    # @api private
    def service_details(service_name, silent = false)
      # Drop service: if needed
      service_name = service_name.partition(":")[2] if service_name.include?("service:")
      # If service description is the default one then we know that we haven't read the service
      # information just yet. Lets do it now
      populate_service(service_name) if all_services[service_name]["description"] ==
          default_service_description(service_name)
      service = all_services[service_name]
      if service.nil? && !silent
        log.error "Uknown service '#{service_name}'"
        log.info "Known services: #{all_services.keys}"

        raise(
          SuSEFirewalServiceNotFound,
          _("Service with name '%{service_name}' does not exist") % { service_name: service_name }
        )
      end

      service
    end

    # Sets that configuration was modified
    def SetModified
      @sfws_modified = true

      nil
    end

  private

    # A good default description for all services. We will use that to
    # determine if the service has been populated or not.
    #
    # @param service_name [String] The service name
    # @return [String] Default description for service
    def default_service_description(service_name)
      _("The %{service_name} Service") % { service_name: service_name.upcase }
    end

    # Populate service's internal data structures.
    #
    # @param service_name [String] The service name
    def populate_service(service_name)
      # This going to be too expensive (5 API calls per service) but this
      # is really the slowpath since we rarely need to extract so much
      # information from a service
      SuSEFirewall.api.service_modules(service_name).split(" ").each do |x|
        @services[service_name]["modules"] << x
      end
      SuSEFirewall.api.service_protocols(service_name).split(" ").each do |x|
        @services[service_name]["protocols"] << x
      end
      SuSEFirewall.api.service_ports(service_name).split(" ").each do |x|
        port_proto = x.split("/")
        @services[service_name]["tcp_ports"] << port_proto[0] if port_proto[1] == "tcp"
        @services[service_name]["udp_ports"] << port_proto[0] if port_proto[1] == "udp"
      end
      @services[service_name]["description"] = SuSEFirewall.api.service_description(service_name)

      log.debug("Added service '#{service_name}' with info: #{@services[service_name]}")

      true
    end

    publish function: :ReadServicesDefinedByRPMPackages, type: "boolean ()"
    publish function: :GetSupportedServices, type: "map <string, string> ()"
    publish function: :GetListOfServicesAddedByPackage, type: "list <string> ()"
    publish function: :GetNeededTCPPorts, type: "list <string> (string)"
    publish function: :GetNeededUDPPorts, type: "list <string> (string)"
    publish function: :GetNeededRPCPorts, type: "list <string> (string)"
    publish function: :GetNeededIPProtocols, type: "list <string> (string)"
    publish function: :GetDescription, type: "string (string)"
    publish function: :IsKnownService, type: "boolean (string)"
    publish function: :GetNeededPortsAndProtocols, type: "map <string, list <string>> (string)"
    publish function: :SetModified, type: "void ()"
    publish function: :ResetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
  end
end
