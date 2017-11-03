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

require "yast"
require "yast2/execute"

Yast.import "Stage"
Yast.import "Service"
Yast.import "PackageSystem"

module Y2Firewall
  class Firewalld
    class Error < RuntimeError
    end

    # Firewalld command line API supporting two modes (:offline and :running)
    #
    # The :offline mode is useful in environments where the daemon is not running or
    # the DBUS API is not accesible, in other case the :running mode should be
    # used.
    class Api
      include Yast::Logger
      include Yast::I18n
      extend Forwardable

      # Map firewalld modes with their command line tools
      COMMAND = { offline: "firewall-offline-cmd", running: "firewall-cmd" }.freeze
      # FIXME: Do not like to define twice
      PACKAGE = "firewalld".freeze

      # Determines the mode in which firewalld is running and as consequence the
      # command to be used.
      attr_accessor :mode

      # Constructor
      def initialize(mode: nil, permanent: true)
        @mode =
          if mode == :running || running?
            :running
          else
            :offline
          end
        @permanent = permanent
      end

      # Whether the mode is :offline or not
      #
      # @return [Boolean] true if current mode if :offline; false otherwise
      def offline?
        @mode == :offline
      end

      # Whether the command called to modify configuration should make the
      # changes permanent or not
      #
      # @return [Boolean]
      def permanent?
        return false if offline?

        @permanent
      end

      # Whether firewalld is running or not
      #
      # @return [Boolean] true if the state is running; false otherwise
      def running?
        return false if Yast::Stage.initial
        return false if !Yast::PackageSystem.Installed(PACKAGE)

        state == "running"
      end

      def enable!
        offline? ? run_command("--enable") : Yast::Service.Enable("firewalld")
      end

      def disable!
        offline? ? run_command("--disable") : Yast::Service.Disable("firewalld")
      end

      # @return [Boolean] The firewalld service state (exit code)
      def state
        case Yast::Execute.on_target("firewallctl", "state", allowed_exitstatus: [0, 252])
        when 0
          "running"
        when 252
          "not running"
        else
          "unknown"
        end
      end

      # Return the default zone
      #
      # @return [String] default zone
      def default_zone
        run_command("--get-default-zone")
      end

      # Set the default zone
      #
      # @param zone [String] The firewall zone
      # @return [String] default zone
      def default_zone=(zone)
        run_command("--set-default-zone=#{zone}")
      end

      # @return [Boolean] The firewalld reload result (exit code)
      def reload
        return false if offline?
        run_command("--reload")
      end

      # @return [Boolean] The firewalld complete-reload result (exit code)
      def complete_reload
        return false if offline?

        run_command("--complete-reload")
      end

      ### Zones ####

      # @return [Array<String>] List of firewall zones
      def zones
        run_command("--get-zones").split(" ")
      end

      # @param zone [String] The firewall zone
      # @return [Array<String>] list of zone's interfaces
      def list_interfaces(zone)
        run_command("--zone=#{zone}", "--list-interfaces").split(" ")
      end

      # @param zone [String] The firewall zone
      # @return [Arrray<String>] list of zone's services
      def list_services(zone)
        run_command("--zone=#{zone}", "--list-services").split(" ")
      end

      # @param zone [String] The firewall zone
      # @return [Array<String>] list of zone's ports
      def list_ports(zone)
        run_command("--zone=#{zone}", "--list-ports").split(" ")
      end

      # @param zone [String] The firewall zone
      # @return [Array<String>] list of zone's protocols
      def list_protocols(zone)
        run_command("--zone=#{zone}", "--list-protocols").split(" ")
      end

      # @param zone [String] The firewall zone
      # @return [Array<String>] list of all information for given zone
      def list_all(zone)
        run_command("--zone=#{zone}", "--list-all").split(" ")
      end

      # @return [Array<String>] list of all information for all firewall zones
      def list_all_zones
        run_command("--list-all-zones").split("\n")
      end

      ### Interfaces ###

      # Return the name of the zone the interface belongs to or nil.
      #
      # @param interface [String] interface name
      # @return [String, nil] the interface zone or nil
      def interface_zone(interface)
        run_command("--get-zone-of-interface=#{interface}")
      end

      # @param zone [String] The firewall zone
      # @param interface [String] The network interface
      # @return [Boolean] True if interface is assigned to zone
      def interface_enabled?(zone, interface)
        run_command("--zone=#{zone} --query-interface=#{interface}")
      end

      # @param zone [String] The firewall zone
      # @param interface [String] The network interface
      # @return [Boolean] True if interface was added to zone
      def add_interface(zone, interface, permanent: permanent?)
        run_command("--zone=#{zone}", "--add-interface=#{interface}", permanent: permanent)
      end

      # @param zone [String] The firewall zone
      # @param interface [String] The network interface
      # @return [Boolean] True if interface was removed from zone
      def remove_interface(zone, interface, permanent: permanent?)
        run_command("--zone=#{zone}", "--remove-interface=#{interface}", permanent: permanent)
      end

      ### Services ###

      # @return [Array<String>] List of firewall services
      def services
        run_command("--get-services").split(" ")
      end

      # @param service [String] The firewall service
      # @return [Array<String>] list of all information for the given service
      def info_service(service)
        run_command("--info-service", service.to_s).split("\n")
      end

      # @param service [String] The firewall service
      # @return [String] Short description for service
      def service_short(service)
        # these may not exist on early firewalld releases
        run_command("--service=#{service}", "--get-short").rstrip
      end

      # @param service [String] the firewall service
      # @return [String] Description for service
      def service_description(service)
        run_command("--service=#{service}", "--get-description").rstrip
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
        run_command("--zone=#{zone}", "--query-service=#{service}")
      end

      # @param service [String] The firewall service
      # @return [Array<String>] The firewall service ports
      def service_ports(service)
        run_command("--service=#{service}", "--get-ports").strip
      end

      # @param service [String] The firewall service
      # @return [Array<String>] The firewall service protocols
      def service_protocols(service)
        run_command("--service=#{service}", "--get-protocols").strip
      end

      # @param service [String] The firewall service
      # @return [Array<String>] The firewall service modules
      def service_modules(service)
        run_command("--service=#{service}", "--get-modules").strip
      end

      # @param zone [String] The firewall zone
      # @param port [String] The firewall port
      # @return [Boolean] True if port is enabled in zone
      def port_enabled?(zone, port)
        run_command("--zone=#{zone}", "--query-port=#{port}")
      end

      # @param zone [String] The firewall zone
      # @param protocol [String] The zone protocol
      # @return [Boolean] True if protocol is enabled in zone
      def protocol_enabled?(zone, protocol)
        run_command("--zone=#{zone}", "--query-protocol=#{protocol}")
      end

      # @param zone [String] The firewall zone
      # @param service [String] The firewall service
      # @return [Boolean] True if service was added to zone
      def add_service(zone, service, permanent: permanent?)
        run_command("--zone=#{zone}", "--add-service=#{service}", permanent: permanent)
      end

      # @param zone [String] The firewall zone
      # @param port [String] The firewall port
      # @return [Boolean] True if port was added to zone
      def add_port(zone, port, permanent: permanent?)
        run_command("--zone=#{zone}", "--add-port=#{port}", permanent: permanent)
      end

      # @param zone [String] The firewall zone
      # @param protocol [String] The firewall protocol
      # @return [Boolean] True if protocol was added to zone
      def add_protocol(zone, protocol, permanent: permanent?)
        run_command("--zone=#{zone}", "--add-protocol=#{protocol}", permanent: permanent)
      end

      # @param zone [String] The firewall zone
      # @param service [String] The firewall service
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
      # @return [Boolean] True if port was removed from zone
      def remove_port(zone, port, permanent: permanent?)
        run_command("--zone=#{zone}", "--remove-port=#{port}", permanent: permanent)
      end

      # @param zone [String] The firewall zone
      # @param protocol [String] The firewall protocol
      # @return [Boolean] True if protocol was removed from zone
      def remove_protocol(zone, protocol, permanent: permanent?)
        run_command("--zone=#{zone}", "--remove-protocol=#{protocol}", permanent: permanent)
      end

      # @param zone [String] The firewall zone
      # @return [Boolean] True if masquerade is enabled in zone
      def masquerade_enabled?(zone)
        run_command("--zone=#{zone}", "--query-masquerade")
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

      ### Logging ###

      # @param kind [String] Denied packets to log. Possible values are:
      # all, unicast, broadcast, multicast and off
      # @return [Boolean] True if desired packet type is being logged when denied
      def log_denied_packets?(kind)
        run_command("--get-log-denied").strip == kind ? true : false
      end

      # @param kind [String] Denied packets to log. Possible values are:
      # all, unicast, broadcast, multicast and off
      # @return [Boolean] True if desired packet type was set to being logged
      # when denied
      def log_denied_packets=(kind)
        run_command("--set-log-denied=#{kind}")
      end

      # @return [String] packet type which is being logged when denied
      def log_denied_packets
        run_command("--get-log-denied").strip
      end

    private

      # Command to be used depending on the current mode.
      # @return [String] command for the current mode.
      def command
        COMMAND[@mode]
      end

      # Executes the command for the current mode with the given arguments.
      #
      # @see #command
      # @return [String] stdout result of the command executed
      def run_command(*args, permanent: false)
        arguments = permanent ? ["--permanent"] : []
        arguments.concat(args)
        log.info("Executing #{command} with #{arguments.inspect}")

        Yast::Execute.on_target(command, *arguments, stdout: :capture).to_s.chomp
      end
    end
  end
end
