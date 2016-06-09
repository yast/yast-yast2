# encoding: utf-8

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
#
# Authors:     Markos Chandras <mchandras@suse.de>, Karol Mroz <kmroz@suse.de>
#
# $Id$
#
# Module for handling SuSEfirewall2 or FirewallD
require "yast"

module Yast
  # Factory for construction of appropriate firewall object based on
  # desired backend.
  class SuSEFirewallClass < Module
    # @return [String] the systemd service name: "firewalld" or "SuSEfirewall2"
    attr_reader :firewall_service

    Yast.import "Mode"
    Yast.import "NetworkInterfaces"
    Yast.import "PackageSystem"
    Yast.import "PortRanges"

    include Yast::Logger

    # Function which returns if SuSEfirewall2 should start in Write process.
    # In fact it means that SuSEfirewall2 will at the end.
    #
    # @return	[Boolean] if the firewall should start
    def GetStartService
      Ops.get_boolean(@SETTINGS, "start_firewall", false)
    end

    # Function which sets if SuSEfirewall should start in Write process.
    #
    # @param [Boolean] start_service at Write() process
    # @see #GetStartService()
    def SetStartService(start_service)
      if !SuSEFirewallIsInstalled()
        Builtins.y2warning("Cannot set SetStartService")
        return nil
      end

      if GetStartService() != start_service
        SetModified()

        Builtins.y2milestone("Setting start-firewall to %1", start_service)
        Ops.set(@SETTINGS, "start_firewall", start_service)
      else
        # without set modified!
        Builtins.y2milestone(
          "start-firewall has been already set to %1",
          start_service
        )
        Ops.set(@SETTINGS, "start_firewall", start_service)
      end

      nil
    end

    # Function which returns whether SuSEfirewall should be enabled in
    # /etc/init.d/ starting scripts during the Write() process
    #
    # @see #Write()
    # @see #EnableServices()
    #
    # @return	[Boolean] if the firewall should start
    def GetEnableService
      Ops.get_boolean(@SETTINGS, "enable_firewall", false)
    end

    # Function which sets if SuSEfirewall should start in Write process
    #
    # @param	boolean start_service at Write() process
    def SetEnableService(enable_service)
      if !SuSEFirewallIsInstalled()
        Builtins.y2warning("Cannot set SetEnableService")
        return nil
      end

      if GetEnableService() != enable_service
        SetModified()

        Builtins.y2milestone("Setting enable-firewall to %1", enable_service)
        Ops.set(@SETTINGS, "enable_firewall", enable_service)
      else
        # without set modified
        Builtins.y2milestone(
          "enable-firewall has been already set to %1",
          enable_service
        )
        Ops.set(@SETTINGS, "enable_firewall", enable_service)
      end

      nil
    end

    # Functions starts services needed for SuSEFirewall
    #
    # @return	[Boolean] result
    def StartServices
      return true if Mode.testsuite

      return false if !SuSEFirewallIsInstalled()

      if Service.Start(@firewall_service)
        Builtins.y2milestone("Started")
        return true
      else
        Builtins.y2error("Cannot start service %1", @firewall_service)
        return false
      end
    end

    # Functions stops services needed for SuSEFirewall
    #
    # @return	[Boolean] result
    def StopServices
      return true if Mode.testsuite

      return false if !SuSEFirewallIsInstalled()

      if Service.Stop(@firewall_service)
        Builtins.y2milestone("Stopped")
        return true
      else
        Builtins.y2error("Could not stop service %1", @firewall_service)
        return false
      end
    end

    # Functions enables services needed for SuSEFirewall in /etc/inet.d/
    #
    # @return	[Boolean] result
    def EnableServices
      all_ok = true

      return false if !SuSEFirewallIsInstalled()

      if !Service.Enable(@firewall_service)
        all_ok = true
        # TRANSLATORS: a popup error message
        Report.LongError(Service.Error)
      end

      all_ok
    end

    # Functions disables services needed for SuSEFirewall in /etc/inet.d/
    #
    # @return	[Boolean] result
    def DisableServices
      return false if !SuSEFirewallIsInstalled()

      if Service.Disable(@firewall_service)
        return true
      else
        # TRANSLATORS: a popup error message
        Report.LongError(Service.Error)
        return false
      end
    end

    # Function determines if all SuSEFirewall scripts are enabled in
    # init scripts /etc/init.d/ now.
    # For configuration "enabled" status use GetEnableService().
    #
    # @return	[Boolean] if enabled
    def IsEnabled
      return false if !SuSEFirewallIsInstalled()

      if Service.Enabled(@firewall_service)
        Builtins.y2milestone("Firewall service is enabled")
        return true
      else
        Builtins.y2milestone("Firewall service is not enabled")
        return false
      end
    end

    # Function determines if at least one SuSEFirewall script is started now.
    # For configuration "started" status use GetStartService().
    #
    # @return	[Boolean] if started
    def IsStarted
      return false if !SuSEFirewallIsInstalled()

      return true if Mode.testsuite

      Builtins.y2milestone("Checking firewall status...")
      if Service.Status(@firewall_service) == 0
        Builtins.y2milestone("Firewall service is started")
        return true
      else
        Builtins.y2milestone("Firewall service is stopped")
        return false
      end
    end

    # Function returns list of known firewall zones (shortnames)
    #
    # @return	[Array<String>] of firewall zones
    #
    # @example GetKnownFirewallZones() -> ["DMZ", "EXT", "INT"]
    def GetKnownFirewallZones
      deep_copy(@known_firewall_zones)
    end

    # Function returns map of supported services in all firewall zones.
    #
    # @param	list <string> of services
    # @return	[Hash <String, Hash{String => Boolean>}]
    #
    #
    # **Structure:**
    #
    #    	Returns $[service : $[ zone_name : supported_status]]
    #
    # @example
    #  // Firewall in not protected from internal zone, that's why
    #  // all services report that they are enabled in INT zone
    #  GetServices (["samba-server", "service:irc-server"]) -> $[
    #    "samba-server" : $["DMZ":false, "EXT":false, "INT":true],
    #    "service:irc-server" : $["DMZ":false, "EXT":true, "INT":true]
    #  ]
    def GetServices(services)
      services = deep_copy(services)
      # $[ service : $[ firewall_zone : status ]]
      services_status = {}

      # for all services requested
      Builtins.foreach(services) do |service|
        Ops.set(services_status, service, {})
        # for all zones in configuration
        Builtins.foreach(GetKnownFirewallZones()) do |zone|
          Ops.set(
            services_status,
            [service, zone],
            IsServiceSupportedInZone(service, zone)
          )
        end
      end

      deep_copy(services_status)
    end

    # Function returns map of supported services all network interfaces.
    #
    # @param	list <string> of services
    # @return	[Hash <String, Hash{String => Boolean} >]
    #
    #
    # **Structure:**
    #
    #    	Returns $[service : $[ interface : supported_status ]]
    #
    # @example
    #	GetServicesInZones (["service:irc-server"]) -> $["service:irc-server":$["eth1":true]]
    #  // No such service "something"
    #	GetServicesInZones (["something"])) -> $["something":$["eth1":nil]]
    #  GetServicesInZones (["samba-server"]) -> $["samba-server":$["eth1":false]]
    def GetServicesInZones(services)
      services = deep_copy(services)
      # list of interfaces for each zone
      interfaces_in_zone = {}

      GetListOfKnownInterfaces().each do |i|
        z = GetZoneOfInterface(i)
        next if z.nil? || z.empty?
        interfaces_in_zone[z] ||= []
        interfaces_in_zone[z] << i
      end

      # $[ service : $[ network_interface : status ]]
      services_status = {}

      # for all services requested
      Builtins.foreach(services) do |service|
        Ops.set(services_status, service, {})
        # for all zones in configuration
        Builtins.foreach(interfaces_in_zone) do |zone, interfaces|
          status = IsServiceSupportedInZone(service, zone)
          # for all interfaces in zone
          Builtins.foreach(interfaces) do |interface|
            Ops.set(services_status, [service, interface], status)
          end
        end
      end

      deep_copy(services_status)
    end

    # Function sets status for several services on several network interfaces.
    #
    # @param	list <string> service ids
    # @param	list <string> network interfaces
    # @param	boolean new status of services
    # @return	[Boolean] if successfull
    #
    # @example
    #  // Disabling services
    #	SetServices (["samba-server", "service:irc-server"], ["eth1", "modem0"], false)
    #  // Enabling services
    #  SetServices (["samba-server", "service:irc-server"], ["eth1", "modem0"], true)
    # @see #SetServicesForZones()

    def SetServices(services_ids, interfaces, new_status)
      firewall_zones = GetZonesOfInterfacesWithAnyFeatureSupported(interfaces)
      if Builtins.size(firewall_zones) == 0
        Builtins.y2error(
          "Interfaces '%1' are not in any group of interfaces",
          interfaces
        )
        return false
      end

      SetModified()

      SetServicesForZones(services_ids, firewall_zones, new_status)
    end

    # Function sets internal variable, which indicates, that any
    # "firewall settings were modified", to "true".
    def SetModified
      @modified = true

      nil
    end

    # Do not use this function.
    # Only for firewall installation proposal.
    def ResetModified
      Builtins.y2milestone("Reseting firewall-modified to 'false'")
      @modified = false

      nil
    end

    # Functions returns whether any firewall's configuration was modified.
    #
    # @return	[Boolean] if the configuration was modified
    def GetModified
      Yast.import "SuSEFirewallServices"
      # Changed SuSEFirewall or
      # Changed SuSEFirewallServices (needs resatrting as well)
      @modified || SuSEFirewallServices.GetModified
    end

    # By default Firewall packages are just checked whether they are installed.
    # With this function, you can change the behavior to also offer installing
    # the packages.
    #
    # @param [Boolean] new_status, 'true' if packages should be offered for installation
    def SetInstallPackagesIfMissing(new_status)
      if new_status.nil?
        Builtins.y2error("Wrong value: %1", new_status)
        return
      end

      @check_and_install_package = new_status

      if @check_and_install_package
        Builtins.y2milestone("Firewall packages will installed if missing")
      else
        Builtins.y2milestone(
          "Firewall packages will not be installed even if missing"
        )
      end

      nil
    end

    # Function returns list of maps of known interfaces.
    #
    # **Structure:**
    #
    #     [ $[ "id":"modem1", "name":"Askey 815C", "type":"dialup", "zone":"EXT" ], ... ]
    #
    # @return	[Array<Hash{String => String>}]
    # @return [Array<Hash{String => String>}] of all interfaces
    def GetAllKnownInterfaces
      known_interfaces = []

      # All dial-up interfaces
      dialup_interfaces = NetworkInterfaces.List("dialup")
      dialup_interfaces = [] if dialup_interfaces.nil?

      # bugzilla #303858 - wrong values from NetworkInterfaces
      dialup_interfaces = Builtins.filter(dialup_interfaces) do |one_iface|
        if one_iface.nil? || one_iface == ""
          Builtins.y2error("Wrong interface definition '%1'", one_iface)
          next false
        end
        true
      end

      dialup_interfaces = Builtins.filter(dialup_interfaces) do |interface|
        interface != "" && !Builtins.issubstring(interface, "lo") &&
          !Builtins.issubstring(interface, "sit")
      end

      # All non-dial-up interfaces
      non_dialup_interfaces = NetworkInterfaces.List("")
      non_dialup_interfaces = [] if non_dialup_interfaces.nil?

      # bugzilla #303858 - wrong values from NetworkInterfaces
      non_dialup_interfaces = Builtins.filter(non_dialup_interfaces) do |one_iface|
        if one_iface.nil? || one_iface == ""
          Builtins.y2error("Wrong interface definition '%1'", one_iface)
          next false
        end
        true
      end

      non_dialup_interfaces = Builtins.filter(non_dialup_interfaces) do |interface|
        interface != "" && !Builtins.issubstring(interface, "lo") &&
          !Builtins.issubstring(interface, "sit") &&
          !Builtins.contains(dialup_interfaces, interface)
      end

      Builtins.foreach(dialup_interfaces) do |interface|
        known_interfaces = Builtins.add(
          known_interfaces,

          "id"   => interface,
          "type" => "dialup",
          # using function to get name
          "name" => NetworkInterfaces.GetValue(
            interface,
            "NAME"
          ),
          "zone" => GetZoneOfInterface(interface)

        )
      end

      Builtins.foreach(non_dialup_interfaces) do |interface|
        known_interfaces = Builtins.add(
          known_interfaces,

          "id"   => interface,
          # using function to get name
          "name" => NetworkInterfaces.GetValue(
            interface,
            "NAME"
          ),
          "zone" => GetZoneOfInterface(interface)

        )
      end

      deep_copy(known_interfaces)
    end

    # Function returns list of all known interfaces.
    #
    # @return	[Array<String>] of interfaces
    # @example GetListOfKnownInterfaces() -> ["eth1", "eth2", "modem0", "dsl5"]
    def GetListOfKnownInterfaces
      GetAllKnownInterfaces().map { |i| i["id"] }
    end

    # Function returns list of zones of requested interfaces
    #
    # @param [Array<String>] interfaces
    # @return	[Array<String>] firewall zones
    #
    # @example
    #	GetZonesOfInterfaces (["eth1","eth4"]) -> ["DMZ", "EXT"]
    def GetZonesOfInterfaces(interfaces)
      interfaces = deep_copy(interfaces)
      zones = []
      zone = ""

      Builtins.foreach(interfaces) do |interface|
        zone = GetZoneOfInterface(interface)
        zones = Builtins.add(zones, zone) if !zone.nil?
      end

      Builtins.toset(zones)
    end

    # Function returns localized name of the zone identified by zone shortname.
    #
    # @param	string short name
    # @return	[String] zone name
    #
    # @example
    #  LANG=en_US GetZoneFullName ("EXT") -> "External Zone"
    #  LANG=cs_CZ GetZoneFullName ("EXT") -> "Externí Zóna"
    def GetZoneFullName(zone)
      # TRANSLATORS: Firewall zone full-name, used as combo box item or dialog title
      Ops.get(@zone_names, zone, _("Unknown Zone"))
    end

    # Function returns if zone (shortname like "EXT") is supported by firewall.
    # Undefined zones are, for sure, unsupported.
    #
    # @param [String] zone shortname
    # @return	[Boolean] if zone is known and supported.
    def IsKnownZone(zone)
      is_zone = false

      Builtins.foreach(GetKnownFirewallZones()) do |known_zone|
        if known_zone == zone
          is_zone = true
          raise Break
        end
      end

      is_zone
    end

    # Returns whether all needed packages are installed (or selected for
    # installation)
    #
    # @return [Boolean] whether the selected firewall backend is installed
    def SuSEFirewallIsInstalled
      # Always recheck the status in inst-sys, user/solver might have change
      # the list of packages selected for installation
      # bnc#892935: in inst_finish, the package is already installed
      if Stage.initial
        @needed_packages_installed = Pkg.IsSelected(@FIREWALL_PACKAGE) || PackageSystem.Installed(@FIREWALL_PACKAGE)
        log.info "Selected for installation/installed -> #{@needed_packages_installed}"
      elsif @needed_packages_installed.nil?
        if Mode.normal
          @needed_packages_installed = PackageSystem.CheckAndInstallPackages([@FIREWALL_PACKAGE])
          log.info "CheckAndInstallPackages -> #{@needed_packages_installed}"
        else
          @needed_packages_installed = PackageSystem.Installed(@FIREWALL_PACKAGE)
          log.info "Installed -> #{@needed_packages_installed}"
        end
      end

      @needed_packages_installed
    end

    # Function for saving configuration and restarting firewall.
    # Is is the same as Write() but write is allways forced.
    #
    # @return	[Boolean] if successful
    def SaveAndRestartService
      Builtins.y2milestone("Forced save and restart")
      SetModified()

      SetStartService(true)

      return false if !Write()

      true
    end

    # Local function returns if protocol is supported by firewall.
    # Protocol name must be in upper-cases.
    #
    # @param [String] protocol
    # @return [Boolean] whether protocol is supported, that is, one of TCP, UDP, IP
    def IsSupportedProtocol(protocol)
      @supported_protocols.include?(protocol)
    end

    # Function sets additional ports/services from taken list. Firstly, all additional services
    # are removed also with their aliases. Secondly new ports/protocols are added.
    # It uses GetAdditionalServices() function to get the current state and
    # then it removes what has been removed and adds what has been added.
    #
    # @param [String] protocol
    # @param [String] zone
    # @param	list <string> list of ports/protocols
    # @see #GetAdditionalServices()
    #
    # @example
    #	SetAdditionalServices ("TCP", "EXT", ["53", "128"])
    def SetAdditionalServices(protocol, zone, new_list_services)
      new_list_services = deep_copy(new_list_services)
      old_list_services = Builtins.toset(GetAdditionalServices(protocol, zone))
      new_list_services = Builtins.toset(new_list_services)

      if new_list_services != old_list_services
        SetModified()

        add_services = []
        remove_services = []

        # Add these services
        Builtins.foreach(new_list_services) do |service|
          if !Builtins.contains(old_list_services, service)
            add_services = Builtins.add(add_services, service)
          end
        end
        # Remove these services
        Builtins.foreach(old_list_services) do |service|
          if !Builtins.contains(new_list_services, service)
            remove_services = Builtins.add(remove_services, service)
          end
        end

        if Ops.greater_than(Builtins.size(remove_services), 0)
          Builtins.y2milestone(
            "Removing additional services %1/%2 from zone %3",
            remove_services,
            protocol,
            zone
          )
          RemoveAllowedPortsOrServices(remove_services, protocol, zone, true)
        end
        if Ops.greater_than(Builtins.size(add_services), 0)
          Builtins.y2milestone(
            "Adding additional services %1/%2 into zone %3",
            add_services,
            protocol,
            zone
          )
          AddAllowedPortsOrServices(add_services, protocol, zone)
        end
      end

      nil
    end

    # Local function removes ports and their aliases (if check_for_aliases is true), for
    # requested protocol and zone.
    #
    # @param	list <string> ports to be removed
    # @param [String] protocol
    # @param [String] zone
    # @param	boolean check for port-aliases
    def RemoveAllowedPortsOrServices(remove_ports, protocol, zone, check_for_aliases)
      remove_ports = deep_copy(remove_ports)
      if Ops.less_than(Builtins.size(remove_ports), 1)
        Builtins.y2warning(
          "Undefined list of %1 services/ports for service",
          protocol
        )
        return
      end

      SetModified()

      # all allowed ports
      allowed_services = PortRanges.DividePortsAndPortRanges(
        GetAllowedServicesForZoneProto(zone, protocol),
        false
      )

      # removing all aliases of ports too, adding aliases into
      if check_for_aliases
        remove_ports_with_aliases = []
        Builtins.foreach(remove_ports) do |remove_port|
          # skip port ranges, they cannot have any port-alias
          if PortRanges.IsPortRange(remove_port)
            remove_ports_with_aliases = Builtins.add(
              remove_ports_with_aliases,
              remove_port
            )
            next
          end
          remove_these_ports = PortAliases.GetListOfServiceAliases(remove_port)
          remove_these_ports = [remove_port] if remove_these_ports.nil?
          remove_ports_with_aliases = Convert.convert(
            Builtins.union(remove_ports_with_aliases, remove_these_ports),
            from: "list",
            to:   "list <string>"
          )
        end
        remove_ports = deep_copy(remove_ports_with_aliases)
      end
      remove_ports = Builtins.toset(remove_ports)

      # Remove ports only once (because of port aliases), any => integers and strings
      already_removed = []

      Builtins.foreach(remove_ports) do |remove_port|
        # Removing from normal ports
        Ops.set(
          allowed_services,
          "ports",
          Builtins.filter(Ops.get(allowed_services, "ports", [])) do |allowed_port|
            allowed_port != "" && allowed_port != remove_port
          end
        )
        # Removing also from port ranges
        if Ops.get(allowed_services, "port_ranges", []) != []
          # Removing a real port from port ranges
          if !PortRanges.IsPortRange(remove_port)
            remove_port_nr = PortAliases.GetPortNumber(remove_port)
            # Because of all port aliases
            if !Builtins.contains(already_removed, remove_port_nr)
              already_removed = Builtins.add(already_removed, remove_port_nr)
              Ops.set(
                allowed_services,
                "port_ranges",
                PortRanges.RemovePortFromPortRanges(
                  remove_port_nr,
                  Ops.get(allowed_services, "port_ranges", [])
                )
              )
            end
            # Removing a port range from port ranges
          else
            if !Builtins.contains(already_removed, remove_port)
              # Just filtering the exact port range
              Ops.set(
                allowed_services,
                "port_ranges",
                Builtins.filter(Ops.get(allowed_services, "port_ranges", [])) do |one_port_range|
                  one_port_range != remove_port
                end
              )
              already_removed = Builtins.add(already_removed, remove_port)
            end
          end
        end
      end

      allowed_services_all = Convert.convert(
        Builtins.union(
          Ops.get(allowed_services, "ports", []),
          Ops.get(allowed_services, "port_ranges", [])
        ),
        from: "list",
        to:   "list <string>"
      )

      allowed_services_all = PortRanges.FlattenServices(
        allowed_services_all,
        protocol
      )

      SetAllowedServicesForZoneProto(allowed_services_all, zone, protocol)

      nil
    end

    # Function returns if another firewall is currently running on the
    # system. It uses command `iptables` to get information about just active
    # iptables rules and compares the output with current status of the selected
    # firewall backend
    #
    # @return	[Boolean] if other firewall is running
    def IsOtherFirewallRunning
      any_firewall_running = true

      # grep must return at least blank lines, else it returns 'exit 1' instead of 'exit 0'
      command = "LANG=C iptables -L -n | grep -v \"^\\(Chain\\|target\\)\""

      iptables = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), command)
      )
      if Ops.get_integer(iptables, "exit", 0) == 0
        iptables_list = Builtins.splitstring(
          Ops.get_string(iptables, "stdout", ""),
          "\n"
        )
        iptables_list = Builtins.filter(iptables_list) do |iptable_rule|
          iptable_rule != ""
        end

        Builtins.y2milestone(
          "Count of active iptables now: %1",
          Builtins.size(iptables_list)
        )

        # any iptables rule exist?
        any_firewall_running = Ops.greater_than(Builtins.size(iptables_list), 0)
      else
        # error running command
        Builtins.y2error(
          "Services Command: %1 (Exit %2) -> %3",
          command,
          Ops.get(iptables, "exit"),
          Ops.get(iptables, "stderr")
        )
        return nil
      end

      # any firewall is running but it is not desired one
      if any_firewall_running && !IsStarted()
        Builtins.y2warning("Any other firewall is running...")
        return true
      end
      # no firewall is running or the running firewall the desired one
      false
    end

    def ArePortsOrServicesAllowed(needed_ports, protocol, zone, check_for_aliases)
      needed_ports = deep_copy(needed_ports)
      are_allowed = true

      if Ops.less_than(Builtins.size(needed_ports), 1)
        Builtins.y2warning(
          "Undefined list of %1 services/ports for service",
          protocol
        )
        return true
      end

      allowed_ports = {}
      # BTW: only TCP and UDP ports can have aliases and only TCP and UDP ports can have port ranges
      if check_for_aliases
        allowed_ports = PortRanges.DividePortsAndPortRanges(
          GetAllowedServicesForZoneProto(zone, protocol),
          true
        )
      else
        Ops.set(
          allowed_ports,
          "ports",
          GetAllowedServicesForZoneProto(zone, protocol)
        )
      end

      Builtins.foreach(needed_ports) do |needed_port|
        if !Builtins.contains(Ops.get(allowed_ports, "ports", []), needed_port) &&
            !PortRanges.PortIsInPortranges(
              needed_port,
              Ops.get(allowed_ports, "port_ranges", [])
            )
          are_allowed = false
          raise Break
        end
      end

      are_allowed
    end

    # Function returns if requested service is allowed in respective zone.
    # Function takes care for service's aliases (only for TCP and UDP).
    # Service is defined by set of parameters such as port and protocol.
    #
    # @param [String] service (service name, port name, port alias or port number)
    # @param [String] protocol TCP, UDP, RCP or IP
    # @param [String] interface name (like modem0), firewall zone (like "EXT") or "any" for all zones.
    # @return	[Boolean] if service is allowed
    #
    # @example
    #	HaveService ("ssh", "TCP", "EXT") -> true
    #	HaveService ("ssh", "TCP", "modem0") -> false
    #	HaveService ("53", "UDP", "dsl") -> false
    def HaveService(service, protocol, interface)
      if !IsSupportedProtocol(protocol)
        Builtins.y2error("Unknown protocol: %1", protocol)
        return nil
      end

      # definition of searched zones
      zones = []

      # "any" for all zones, this is ugly
      if interface == "any"
        zones = GetKnownFirewallZones()
        # string interface is the zone name
      elsif IsKnownZone(interface)
        zones = Builtins.add(zones, interface)
        # interface is the interface name
      else
        interface = GetZoneOfInterface(interface)
        zones = Builtins.add(zones, interface) if !interface.nil?
      end

      # SuSEFirewall feature FW_PROTECT_FROM_INT
      # should not be protected and searched zones include also internal (or the zone IS internal, sure)
      if !GetProtectFromInternalZone() &&
          Builtins.contains(zones, @int_zone_shortname)
        Builtins.y2milestone(
          "Checking for service '%1', in '%2', PROTECT_FROM_INTERNAL='no' => allowed",
          service,
          interface
        )
        return true
      end

      # Check and return whether the service (port) is supported anywhere
      ret = false
      Builtins.foreach(zones) do |zone|
        # This function can also handle port ranges
        if ArePortsOrServicesAllowed([service], protocol, zone, true)
          ret = true
          raise Break
        end
      end

      ret
    end

    # Function adds service into selected zone (or zone of interface) for selected protocol.
    # Function take care about port-aliases, first of all, removes all of them.
    #
    # @param [String] service/port
    # @param [String] protocol TCP, UDP, RPC, IP
    # @param	string zone name or interface name
    # @return	[Boolean] success
    #
    # @example
    #	AddService ("ssh", "TCP", "EXT")
    #	AddService ("ssh", "TCP", "dsl0")
    def AddService(service, protocol, interface)
      Builtins.y2milestone(
        "Adding service %1, protocol %2 to %3",
        service,
        protocol,
        interface
      )

      if !IsSupportedProtocol(protocol)
        Builtins.y2error("Unknown protocol: %1", protocol)
        return false
      end

      zones_affected = []

      # "all" means for all known zones
      if interface == "all"
        zones_affected = GetKnownFirewallZones()

        # zone or interface name
      else
        # is probably an interface name
        if !IsKnownZone(interface)
          # interface is probably interface-name, checking for respective zone
          interface = GetZoneOfInterface(interface)
          # interface is not assigned to any zone
          if interface.nil?
            # TRANSLATORS: Error message, %1 = interface name (like eth0)
            Report.Error(
              Builtins.sformat(
                _(
                  "Interface '%1' is not assigned to any firewall zone.\nRun YaST2 Firewall and assign it.\n"
                ),
                interface
              )
            )
            Builtins.y2warning(
              "Interface '%1' is not assigned to any firewall zone",
              interface
            )
            return false
          end
        end
        zones_affected = [interface]
      end

      SetModified()

      # Adding service support into each mentioned zone
      Builtins.foreach(zones_affected) do |zone|
        # If there isn't already
        if !ArePortsOrServicesAllowed([service], protocol, zone, true)
          AddAllowedPortsOrServices([service], protocol, zone)
        else
          Builtins.y2milestone(
            "Port %1 has been already allowed in %2",
            service,
            zone
          )
        end
      end

      true
    end

    # Function removes service from selected zone (or for interface) for selected protocol.
    # Function takes care about port-aliases, removes all of them.
    #
    # @param [String] service/port
    # @param [String] protocol TCP, UDP, RPC, IP
    # @param	string zone name or interface name
    # @return	[Boolean] success
    #
    # @example
    #	RemoveService ("22", "TCP", "DMZ") -> true
    #  is the same as
    #	RemoveService ("ssh", "TCP", "DMZ") -> true
    def RemoveService(service, protocol, interface)
      Builtins.y2milestone(
        "Removing service %1, protocol %2 from %3",
        service,
        protocol,
        interface
      )

      if !IsSupportedProtocol(protocol)
        Builtins.y2error("Unknown protocol: %1", protocol)
        return false
      end

      zones_affected = []

      # "all" means for all known zones
      if interface == "all"
        zones_affected = GetKnownFirewallZones()

        # zone or interface name
      else
        if !IsKnownZone(interface)
          # interface is probably interface-name, checking for respective zone
          interface = GetZoneOfInterface(interface)
          # interface is not assigned to any zone
          if interface.nil?
            # TRANSLATORS: Error message, %1 = interface name (like eth0)
            Report.Error(
              Builtins.sformat(
                _(
                  "Interface '%1' is not assigned to any firewall zone.\nRun YaST2 Firewall and assign it.\n"
                ),
                interface
              )
            )
            Builtins.y2warning(
              "Interface '%1' is not assigned to any firewall zone",
              interface
            )
            return false
          end
        end
        zones_affected = [interface]
      end

      SetModified()

      # Adding service support into each mentioned zone
      Builtins.foreach(zones_affected) do |zone|
        # if the service is allowed
        if ArePortsOrServicesAllowed([service], protocol, zone, true)
          RemoveAllowedPortsOrServices([service], protocol, zone, true)
        else
          Builtins.y2milestone(
            "Port %1 has been already removed from %2",
            service,
            zone
          )
        end
      end

      true
    end

    # Function adds a special interface 'xenbr+' into the FW_FORWARD_ALWAYS_INOUT_DEV variable.
    #
    # @see #https://bugzilla.novell.com/show_bug.cgi?id=154133
    # @see #https://bugzilla.novell.com/show_bug.cgi?id=233934
    # @see #https://bugzilla.novell.com/show_bug.cgi?id=375482
    def AddXenSupport
      Builtins.y2milestone(
        "The whole functionality is currently handled by SuSEfirewall2 itself"
      )

      nil
    end
  end
end
