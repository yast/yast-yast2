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
#
# Summary:  FirewallD offline API
# Authors:  Knut Anderssen <kanderssen@suse.de>

require 'yast'
require 'yast2/execute'

Yast.import "Stage"

module Y2Firewalld
  class Error < RuntimeError
  end

  class Api
    include Yast::Logger
    extend Forwardable

    COMMAND = {:offline => "firewall-offline-cmd", :running => "firewall-cmd"}.freeze

    attr_accessor :mode

    def initialize(mode: nil)
      @mode =
        if mode == :running || is_running?
          :running
        else
          :offline
        end
    end

    def offline_mode?
      @mode == :offline
    end

    def command
      COMMAND[@mode]
    end

    def query(args)
      Yast::Execute.on_target(command, *args.split(" "), stdout: :capture)
    end

    def is_running?
      return false if Yast::Stage.initial

      state == "running"
    end

    # @return [Boolean] The firewalld service state (exit code)
    def state
      if @mode == :running
        query("--state")
      else
        Yast::Execute.on_target("firewallctl", "state", stdout: :capture)
      end
    end

    # @return [Boolean] The firewalld reload result (exit code)
    def reload
      return false if offline_mode?

      query("--reload")
    end

    # @return [Boolean] The firewalld complete-reload result (exit code)
    def complete_reload
      return false if offline_mode?

      query("--complete-reload")
    end

    # @return [Boolean] The firewalld runtime-to-permanent result (exit code)
    def make_permanent
      return false if offline_mode?

      query("--runtime-to-permanent")
    end

    ### Zones ####

    # @return [Array<String>] List of firewall zones
    def zones
      query("--get-zones").chomp.split(" ")
    end

    # @param zone [String] The firewall zone
    # @return [Array<String>] list of zone's interfaces
    def list_interfaces(zone)
      query("--zone=#{zone} --list-interfaces").split(" ")
    end

    # @param zone [String] The firewall zone
    # @return [Arrray<String>] list of zone's services
    def list_services(zone)
      query("--zone=#{zone} --list-services").split(" ")
    end

    # @param zone [String] The firewall zone
    # @return [Array<String>] list of zone's ports
    def list_ports(zone)
      query("--zone=#{zone} --list-ports").split(" ")
    end

    # @param zone [String] The firewall zone
    # @return [Array<String>] list of zone's protocols
    def list_protocols(zone)
      query("--zone=#{zone} --list-protocols").split(" ")
    end

    # @param zone [String] The firewall zone
    # @return [Array<String>] list of all information for given zone
    def list_all(zone)
      query("--zone=#{zone} --list-all").split(" ")
    end

    # @return [Array<String>] list of all information for all firewall zones
    def list_all_zones
      query("--list-all-zones").split("\n")
    end

    ### Interfaces ###

    # @param zone [String] The firewall zone
    # @param interface [String] The network interface
    # @return [Boolean] True if interface is assigned to zone
    def interface_enabled?(zone, interface)
      query("--zone=#{zone} --query-interface=#{interface}")
    end

    # @param zone [String] The firewall zone
    # @param interface [String] The network interface
    # @return [Boolean] True if interface was added to zone
    def add_interface(zone, interface)
      query("--zone=#{zone} --add-interface=#{interface}")
    end

    # @param zone [String] The firewall zone
    # @param interface [String] The network interface
    # @return [Boolean] True if interface was removed from zone
    def remove_interface(zone, interface)
      query("--zone=#{zone} --remove-interface=#{interface}")
    end

    ### Services ###

    # @return [Array<String>] List of firewall services
    def services
      query("--get-services").to_s.split(" ")
    end

    # @param service [String] The firewall service
    # @return [Array<String>] list of all information for the given service
    def info_service(service)
      query("--info-service #{service}").split("\n")
    end

    # @param service [String] The firewall service
    # @return [String] Short description for service
    def service_short(service)
      # these may not exist on early firewalld releases
      query("--service=#{service} --get-short").rstrip
    end

    # @param service [String] the firewall service
    # @return [String] Description for service
    def service_description(service)
      query("--service=#{service} --get-description").rstrip
    end

    # @param service [String] The firewall service
    # @return [Boolean] True if service definition exists
    def service_supported?(service)
      services.include?(service)
    end

    # @param zone [String] The firewall zone
    # @param service [String] The firewall service
    # @return [Boolean] True if service is enabled in zone
    def service_enabled?(zone, service)
      query("--zone=#{zone} --query-service=#{service}")
    end

    # @param service [String] The firewall service
    # @return [Array<String>] The firewall service ports
    def service_ports(service)
      query("--service=#{service} --get-ports").strip
    end

    # @param service [String] The firewall service
    # @return [Array<String>] The firewall service protocols
    def service_protocols(service)
      query("--service=#{service} --get-protocols").strip
    end

    # @param service [String] The firewall service
    # @return [Array<String>] The firewall service modules
    def service_modules(service)
      query("--service=#{service} --get-modules").strip
    end

    # @param zone [String] The firewall zone
    # @param port [String] The firewall port
    # @return [Boolean] True if port is enabled in zone
    def port_enabled?(zone, port)
      query("--zone=#{zone} --query-port=#{port}")
    end

    # @param zone [String] The firewall zone
    # @param protocol [String] The zone protocol
    # @return [Boolean] True if protocol is enabled in zone
    def protocol_enabled?(zone, protocol)
      query("--zone=#{zone} --query-protocol=#{protocol}")
    end

    # @param zone [String] The firewall zone
    # @param service [String] The firewall service
    # @return [Boolean] True if service was added to zone
    def add_service(zone, service)
      query("--zone=#{zone} --add-service=#{service}")
    end

    # @param zone [String] The firewall zone
    # @param port [String] The firewall port
    # @return [Boolean] True if port was added to zone
    def add_port(zone, port)
      query("--zone=#{zone} --add-port=#{port}")
    end

    # @param zone [String] The firewall zone
    # @param protocol [String] The firewall protocol
    # @return [Boolean] True if protocol was added to zone
    def add_protocol(zone, protocol)
      query("--zone=#{zone} --add-protocol=#{protocol}")
    end

    # @param zone [String] The firewall zone
    # @param service [String] The firewall service
    # @return [Boolean] True if service was removed from zone
    def remove_service(zone, service)
      query("--zone=#{zone} --remove-service=#{service}")
    end

    # @param zone [String] The firewall zone
    # @param port [String] The firewall port
    # @return [Boolean] True if port was removed from zone
    def remove_port(zone, port)
      query("--zone=#{zone} --remove-port=#{port}")
    end

    # @param zone [String] The firewall zone
    # @param protocol [String] The firewall protocol
    # @return [Boolean] True if protocol was removed from zone
    def remove_protocol(zone, protocol)
      query("--zone=#{zone} --remove-protocol=#{protocol}")
    end

    # @param zone [String] The firewall zone
    # @return [Boolean] True if masquerade is enabled in zone
    def masquerade_enabled?(zone)
      query("--zone=#{zone} --query-masquerade")
    end

    # @param zone [String] The firewall zone
    # @return [Boolean] True if masquerade was enabled in zone
    def add_masquerade(zone)
      return true if masquerade_enabled?(zone)
      query("--zone=#{zone} --add-masquerade")
    end

    # @param zone [String] The firewall zone
    # @return [Boolean] True if masquerade was removed in zone
    def remove_masquerade(zone)
      return true if !masquerade_enabled?(zone)
      query("--zone=#{zone} --remove-masquerade")
    end

    ### Logging ###

    # @param kind [String] Denied packets to log. Possible values are:
    # all, unicast, broadcast, multicast and off
    # @return [Boolean] True if desired packet type is being logged when denied
    def log_denied_packets?(kind)
      query("--get-log-denied").strip == kind ? true : false
    end

    # @param kind [String] Denied packets to log. Possible values are:
    # all, unicast, broadcast, multicast and off
    # @return [Boolean] True if desired packet type was set to being logged
    # when denied
    def log_denied_packets=(kind)
      query("--set-log-denied=#{kind}")
    end

    # @return [String] packet type which is being logged when denied
    def log_denied_packets
      query("--get-log-denied").strip
    end
  end
end
