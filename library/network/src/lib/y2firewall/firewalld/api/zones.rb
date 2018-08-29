# encoding: utf-8
#
# ***************************************************************************
#
# Copyright (c) 2018 SUSE LLC.
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

module Y2Firewall
  class Firewalld
    class Api
      # This module contains specific api methods for handling zones
      # configuration.
      module Zones
        # @return [Array<String>] List of firewall zones
        def zones
          string_command("--get-zones").split(" ")
        end

        # @param zone [String] The firewall zone
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Array<String>] list of zone's interfaces
        def list_interfaces(zone, permanent: permanent?)
          string_command("--zone=#{zone}", "--list-interfaces", permanent: permanent).split(" ")
        end

        # @param zone [String] The firewall zone
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Arrray<String>] list of zone's services
        def list_services(zone, permanent: permanent?)
          string_command("--zone=#{zone}", "--list-services", permanent: permanent).split(" ")
        end

        # @param zone [String] The firewall zone
        # @return [Array<String>] list of zone's ports
        def list_ports(zone, permanent: permanent?)
          string_command("--zone=#{zone}", "--list-ports", permanent: permanent).split(" ")
        end

        # @param zone [String] The firewall zone
        # @return [Array<String>] list of zone's protocols
        def list_protocols(zone, permanent: permanent?)
          string_command("--zone=#{zone}", "--list-protocols", permanent: permanent).split(" ")
        end

        # @param zone [String] The firewall zone
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Array<String>] list of zone's sources
        def list_sources(zone, permanent: permanent?)
          string_command("--zone=#{zone}", "--list-sources", permanent: permanent).split(" ")
        end

        # @param zone [String] The firewall zone
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Array<String>] list of all information for given zone
        def list_all(zone, permanent: permanent?, verbose: false)
          if verbose
            string_command("--zone=#{zone}", "--verbose", "--list-all", permanent: permanent).split(" ")
          else
            string_command("--zone=#{zone}", "--list-all", permanent: permanent).split(" ")
          end
        end

        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Array<String>] list of all information for all firewall zones
        def list_all_zones(permanent: permanent?, verbose: false)
          if verbose
            string_command("--list-all-zones", "--verbose", permanent: permanent).split("\n")
          else
            string_command("--list-all-zones", permanent: permanent).split("\n")
          end
        end

        ### Interfaces ###

        # Return the name of the zone the interface belongs to or nil.
        #
        # @param interface [String] interface name
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [String, nil] the interface zone or nil
        def interface_zone(interface, permanent: permanent?)
          string_command("--get-zone-of-interface=#{interface}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param interface [String] The network interface
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if interface is assigned to zone
        def interface_enabled?(zone, interface, permanent: permanent?)
          query_command("--zone=#{zone} --query-interface=#{interface}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param interface [String] The network interface
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if interface was added to zone
        def add_interface(zone, interface, permanent: permanent?)
          run_command("--zone=#{zone}", "--add-interface=#{interface}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param interface [String] The network interface
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if interface was removed from zone
        def remove_interface(zone, interface, permanent: permanent?)
          run_command("--zone=#{zone}", "--remove-interface=#{interface}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param interface [String] The network interface
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if interface was changed
        def change_interface(zone, interface, permanent: permanent?)
          run_command("--zone=#{zone}", "--change-interface=#{interface}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param source [String] The network source
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if source was added
        def add_source(zone, source, permanent: permanent?)
          run_command("--zone=#{zone}", "--add-source=#{source}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param source [String] The network source
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if source was removed
        def remove_source(zone, source, permanent: permanent?)
          run_command("--zone=#{zone}", "--remove-source=#{source}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param source [String] The network source
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if source was changed
        def change_source(zone, source, permanent: permanent?)
          run_command("--zone=#{zone}", "--change-source=#{source}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param service [String] The firewall service
        # @return [Boolean] True if service is enabled in zone
        def service_enabled?(zone, service)
          query_command("--zone=#{zone}", "--query-service=#{service}")
        end

        # @param zone [String] The firewall zone
        # @param port [String] The firewall port
        # @return [Boolean] True if port is enabled in zone
        def port_enabled?(zone, port)
          query_command("--zone=#{zone}", "--query-port=#{port}")
        end

        # @param zone [String] The firewall zone
        # @param protocol [String] The zone protocol
        # @return [Boolean] True if protocol is enabled in zone
        def protocol_enabled?(zone, protocol)
          query_command("--zone=#{zone}", "--query-protocol=#{protocol}")
        end

        # @param zone [String] The firewall zone
        # @param service [String] The firewall service
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if service was added to zone
        def add_service(zone, service, permanent: permanent?)
          run_command("--zone=#{zone}", "--add-service=#{service}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param port [String] The firewall port
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if port was added to zone
        def add_port(zone, port, permanent: permanent?)
          run_command("--zone=#{zone}", "--add-port=#{port}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param protocol [String] The firewall protocol
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if protocol was added to zone
        def add_protocol(zone, protocol, permanent: permanent?)
          run_command("--zone=#{zone}", "--add-protocol=#{protocol}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param service [String] The firewall service
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if service was removed from zone
        def remove_service(zone, service, permanent: permanent?)
          if offline?
            run_command("--zone=#{zone}", "--remove-service-from-zone=#{service}")
          else
            run_command("--zone=#{zone}", "--remove-service=#{service}", permanent: permanent)
          end
        end

        # @param zone [String] The firewall zone
        # @param port [String] The firewall port
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if port was removed from zone
        def remove_port(zone, port, permanent: permanent?)
          run_command("--zone=#{zone}", "--remove-port=#{port}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param protocol [String] The firewall protocol
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if protocol was removed from zone
        def remove_protocol(zone, protocol, permanent: permanent?)
          run_command("--zone=#{zone}", "--remove-protocol=#{protocol}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @return [Boolean] True if masquerade is enabled in zone
        def masquerade_enabled?(zone)
          query_command("--zone=#{zone}", "--query-masquerade")
        end

        # @param zone [String] The firewall zone
        # @return [Boolean] True if masquerade was enabled in zone
        def add_masquerade(zone)
          return true if masquerade_enabled?(zone)

          run_command("--zone=#{zone}", "--add-masquerade")
        end

        # @param zone [String] The firewall zone
        # @return [Boolean] True if masquerade was removed in zone
        def remove_masquerade(zone)
          return true if !masquerade_enabled?(zone)

          run_command("--zone=#{zone}", "--remove-masquerade")
        end

        def short(zone)
          string_command("--zone=#{zone}", "--get-short")
        end

        def short=(zone, short_description)
          string_command("--zone=#{zone}", "--set-short=#{short_description}")
        end

        def description(zone)
          string_command("--zone=#{zone}", "--get-description")
        end

        def description=(zone, long_description)
          run_command("--zone=#{zone}", "--set-description=#{long_description}")
        end

        def target(zone)
          string_command("--zone=#{zone}", "--get-target")
        end

        def target=(zone,target)
          run_command("--zone=#{zone}", "--set-target=#{target}")
        end
      end
    end
  end
end
