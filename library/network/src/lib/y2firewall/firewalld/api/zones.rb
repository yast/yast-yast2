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
          return [] unless Y2Firewall::Firewalld.instance.installed?
          string_command("--get-zones").split(" ")
        end

        # @param zone [String] The firewall zone
        # @return [Array<String>] list of zone's interfaces
        def list_interfaces(zone)
          return [] unless Y2Firewall::Firewalld.instance.installed?
          string_command("--zone=#{zone}", "--list-interfaces").split(" ")
        end

        # @param zone [String] The firewall zone
        # @return [Arrray<String>] list of zone's services
        def list_services(zone)
          return [] unless Y2Firewall::Firewalld.instance.installed?
          string_command("--zone=#{zone}", "--list-services").split(" ")
        end

        # @param zone [String] The firewall zone
        # @return [Array<String>] list of zone's ports
        def list_ports(zone)
          return [] unless Y2Firewall::Firewalld.instance.installed?
          string_command("--zone=#{zone}", "--list-ports").split(" ")
        end

        # @param zone [String] The firewall zone
        # @return [Array<String>] list of zone's protocols
        def list_protocols(zone)
          return [] unless Y2Firewall::Firewalld.instance.installed?
          string_command("--zone=#{zone}", "--list-protocols").split(" ")
        end

        # @param zone [String] The firewall zone
        # @return [Array<String>] list of zone's sources
        def list_sources(zone)
          return [] unless Y2Firewall::Firewalld.instance.installed?
          string_command("--zone=#{zone}", "--list-sources").split(" ")
        end

        # @param zone [String] The firewall zone
        # @return [Array<String>] list of all information for given zone
        def list_all(zone)
          return [] unless Y2Firewall::Firewalld.instance.installed?
          string_command("--zone=#{zone}", "--list-all").split(" ")
        end

        # @return [Array<String>] list of all information for all firewall zones
        def list_all_zones
          return [] unless Y2Firewall::Firewalld.instance.installed?
          string_command("--list-all-zones").split("\n")
        end

        ### Interfaces ###

        # Return the name of the zone the interface belongs to or nil.
        #
        # @param interface [String] interface name
        # @return [String, nil] the interface zone or nil
        def interface_zone(interface)
          return nil unless Y2Firewall::Firewalld.instance.installed?
          string_command("--get-zone-of-interface=#{interface}")
        end

        # @param zone [String] The firewall zone
        # @param interface [String] The network interface
        # @return [Boolean] True if interface is assigned to zone
        def interface_enabled?(zone, interface)
          return false unless Y2Firewall::Firewalld.instance.installed?
          query_command("--zone=#{zone} --query-interface=#{interface}")
        end

        # @param zone [String] The firewall zone
        # @param interface [String] The network interface
        # @param permanent [Boolean] if true it adds the --permanent option the
        # @return [Boolean] True if interface was added to zone
        def add_interface(zone, interface, permanent: permanent?)
          return false unless Y2Firewall::Firewalld.instance.installed?
          run_command("--zone=#{zone}", "--add-interface=#{interface}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param interface [String] The network interface
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if interface was removed from zone
        def remove_interface(zone, interface, permanent: permanent?)
          return false unless Y2Firewall::Firewalld.instance.installed?
          run_command("--zone=#{zone}", "--remove-interface=#{interface}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param interface [String] The network interface
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if interface was changed
        def change_interface(zone, interface, permanent: permanent?)
          return false unless Y2Firewall::Firewalld.instance.installed?
          run_command("--zone=#{zone}", "--change-interface=#{interface}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param source [String] The network source
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if source was added
        def add_source(zone, source, permanent: permanent?)
          return false unless Y2Firewall::Firewalld.instance.installed?
          run_command("--zone=#{zone}", "--add-source=#{source}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param source [String] The network source
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if source was removed
        def remove_source(zone, source, permanent: permanent?)
          return false unless Y2Firewall::Firewalld.instance.installed?
          run_command("--zone=#{zone}", "--remove-source=#{source}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param source [String] The network source
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if source was changed
        def change_source(zone, source, permanent: permanent?)
          return false unless Y2Firewall::Firewalld.instance.installed?
          run_command("--zone=#{zone}", "--change-source=#{source}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param service [String] The firewall service
        # @return [Boolean] True if service is enabled in zone
        def service_enabled?(zone, service)
          return false unless Y2Firewall::Firewalld.instance.installed?
          query_command("--zone=#{zone}", "--query-service=#{service}")
        end

        # @param zone [String] The firewall zone
        # @param port [String] The firewall port
        # @return [Boolean] True if port is enabled in zone
        def port_enabled?(zone, port)
          return false unless Y2Firewall::Firewalld.instance.installed?
          query_command("--zone=#{zone}", "--query-port=#{port}")
        end

        # @param zone [String] The firewall zone
        # @param protocol [String] The zone protocol
        # @return [Boolean] True if protocol is enabled in zone
        def protocol_enabled?(zone, protocol)
          return false unless Y2Firewall::Firewalld.instance.installed?
          query_command("--zone=#{zone}", "--query-protocol=#{protocol}")
        end

        # @param zone [String] The firewall zone
        # @param service [String] The firewall service
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if service was added to zone
        def add_service(zone, service, permanent: permanent?)
          return false unless Y2Firewall::Firewalld.instance.installed?
          run_command("--zone=#{zone}", "--add-service=#{service}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param port [String] The firewall port
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if port was added to zone
        def add_port(zone, port, permanent: permanent?)
          return false unless Y2Firewall::Firewalld.instance.installed?
          run_command("--zone=#{zone}", "--add-port=#{port}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param protocol [String] The firewall protocol
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if protocol was added to zone
        def add_protocol(zone, protocol, permanent: permanent?)
          return false unless Y2Firewall::Firewalld.instance.installed?
          run_command("--zone=#{zone}", "--add-protocol=#{protocol}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param service [String] The firewall service
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if service was removed from zone
        def remove_service(zone, service, permanent: permanent?)
          return false unless Y2Firewall::Firewalld.instance.installed?
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
          return false unless Y2Firewall::Firewalld.instance.installed?
          run_command("--zone=#{zone}", "--remove-port=#{port}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @param protocol [String] The firewall protocol
        # @param permanent [Boolean] if true it adds the --permanent option the
        # command to be executed
        # @return [Boolean] True if protocol was removed from zone
        def remove_protocol(zone, protocol, permanent: permanent?)
          return false unless Y2Firewall::Firewalld.instance.installed?
          run_command("--zone=#{zone}", "--remove-protocol=#{protocol}", permanent: permanent)
        end

        # @param zone [String] The firewall zone
        # @return [Boolean] True if masquerade is enabled in zone
        def masquerade_enabled?(zone)
          return false unless Y2Firewall::Firewalld.instance.installed?
          query_command("--zone=#{zone}", "--query-masquerade")
        end

        # @param zone [String] The firewall zone
        # @return [Boolean] True if masquerade was enabled in zone
        def add_masquerade(zone)
          return false unless Y2Firewall::Firewalld.instance.installed?
          return true if masquerade_enabled?(zone)

          run_command("--zone=#{zone}", "--add-masquerade")
        end

        # @param zone [String] The firewall zone
        # @return [Boolean] True if masquerade was removed in zone
        def remove_masquerade(zone)
          return false unless Y2Firewall::Firewalld.instance.installed?
          return true if !masquerade_enabled?(zone)

          run_command("--zone=#{zone}", "--remove-masquerade")
        end
      end
    end
  end
end
