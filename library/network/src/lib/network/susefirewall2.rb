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
# Module for handling SuSEfirewall2 or FirewallD
# Package: SuSEFirewall configuration
# Summary: Interface manipulation of /etc/sysconfig/SuSEFirewall
# Authors: Lukas Ocilka <locilka@suse.cz
#
# $Id$
#
# Module for handling SuSEfirewall2
require "yast"
require "network/susefirewall"

module Yast
  # ----------------------------------------------------------------------------
  # SuSEFirewall2/SF2 Class. The original, simply created from the Firewall
  # factory class.
  class SuSEFirewall2Class < SuSEFirewallClass
    CONFIG_FILE = "/etc/sysconfig/SuSEfirewall2".freeze

    include Yast::Logger

    def main
      textdomain "base"

      Yast.import "Mode"
      Yast.import "Service"
      Yast.import "NetworkInterfaces"
      Yast.import "PortAliases"
      Yast.import "Report"
      Yast.import "Message"
      Yast.import "Progress"
      Yast.import "PortRanges"
      Yast.import "PackageSystem"
      Yast.import "FileUtils"
      Yast.import "Directory"
      Yast.import "Stage"
      Yast.import "Pkg"

      # <!-- SuSEFirewall VARIABLES //-->

      @FIREWALL_PACKAGE = "SuSEfirewall2"

      # configuration hasn't been read for the default
      # this should reduce the readings to only ONE
      @configuration_has_been_read = false

      # String which includes all interfaces not-defined in any zone
      @special_all_interface_string = "any"

      # Maximal number of port number, they are in the interval 1-65535 included
      @max_port_number = PortRanges.max_port_number

      # Zone which works with the special_all_interface_string string
      @special_all_interface_zone = "EXT"

      # firewall settings map
      @SETTINGS = {}

      # configuration was modified when true
      @modified = false

      # defines if SuSEFirewall is running
      @is_running = false

      # default settings for SuSEFirewall
      @DEFAULT_SETTINGS = {
        "FW_LOG_ACCEPT_ALL"          => "no",
        "FW_LOG_ACCEPT_CRIT"         => "yes",
        "FW_LOG_DROP_ALL"            => "no",
        "FW_LOG_DROP_CRIT"           => "yes",
        "FW_PROTECT_FROM_INT"        => "no",
        "FW_ROUTE"                   => "no",
        "FW_STOP_KEEP_ROUTING_STATE" => "no",
        "FW_MASQUERADE"              => "no",
        "FW_ALLOW_FW_TRACEROUTE"     => "yes",
        "FW_ALLOW_PING_FW"           => "yes",
        "FW_ALLOW_FW_BROADCAST_EXT"  => "no",
        "FW_ALLOW_FW_BROADCAST_INT"  => "no",
        "FW_ALLOW_FW_BROADCAST_DMZ"  => "no",
        "FW_IGNORE_FW_BROADCAST_EXT" => "yes",
        "FW_IGNORE_FW_BROADCAST_INT" => "no",
        "FW_IGNORE_FW_BROADCAST_DMZ" => "no",
        "FW_IPSEC_TRUST"             => "no",
        "FW_BOOT_FULL_INIT"          => "no"
      }

      # verbose_level -> if verbosity is more than 0, be verbose, starting in verbose mode
      @verbose_level = 1

      # list of known firewall zones
      @known_firewall_zones = ["INT", "DMZ", "EXT"]

      # map defines zone name for all known firewall zones
      @zone_names = {
        # TRANSLATORS: Firewall zone name - used in combo box or dialog title
        "EXT" => _(
          "External Zone"
        ),
        # TRANSLATORS: Firewall zone name - used in combo box or dialog title
        "INT" => _(
          "Internal Zone"
        ),
        # TRANSLATORS: Firewall zone name - used in combo box or dialog title
        "DMZ" => _(
          "Demilitarized Zone"
        )
      }

      # internal zone identification - useful for protect-from-internal
      @int_zone_shortname = "INT"

      # list of protocols supported in firewall, use only upper-cases
      @supported_protocols = ["TCP", "UDP", "RPC", "IP"]

      # list of keys in map of definition well-known services
      @service_defined_by = [
        "tcp_ports",
        "udp_ports",
        "rpc_ports",
        "ip_protocols",
        "broadcast_ports"
      ]

      # list of services currently allowed, which share ports (for instance RPC services)
      @allowed_conflict_services = {}

      @firewall_service = "SuSEfirewall2"

      @SuSEFirewall_variables = [
        # zones and interfaces
        "FW_DEV_INT",
        "FW_DEV_DMZ",
        "FW_DEV_EXT",
        # services in zones
        "FW_SERVICES_INT_TCP",
        "FW_SERVICES_INT_UDP",
        "FW_SERVICES_INT_RPC",
        "FW_SERVICES_INT_IP",
        "FW_SERVICES_DMZ_TCP",
        "FW_SERVICES_DMZ_UDP",
        "FW_SERVICES_DMZ_RPC",
        "FW_SERVICES_DMZ_IP",
        "FW_SERVICES_EXT_TCP",
        "FW_SERVICES_EXT_UDP",
        "FW_SERVICES_EXT_RPC",
        "FW_SERVICES_EXT_IP",
        "FW_PROTECT_FROM_INT",
        # global routing, masquerading
        "FW_ROUTE",
        "FW_STOP_KEEP_ROUTING_STATE",
        "FW_MASQUERADE",
        "FW_FORWARD_MASQ",
        "FW_FORWARD_ALWAYS_INOUT_DEV",
        # broadcast packets
        "FW_ALLOW_FW_BROADCAST_EXT",
        "FW_ALLOW_FW_BROADCAST_INT",
        "FW_ALLOW_FW_BROADCAST_DMZ",
        "FW_IGNORE_FW_BROADCAST_EXT",
        "FW_IGNORE_FW_BROADCAST_INT",
        "FW_IGNORE_FW_BROADCAST_DMZ",
        # FATE #300970: Support for 'Samba & friends' browsing
        "FW_SERVICES_ACCEPT_RELATED_EXT",
        "FW_SERVICES_ACCEPT_RELATED_INT",
        "FW_SERVICES_ACCEPT_RELATED_DMZ",
        # logging
        "FW_LOG_DROP_CRIT",
        "FW_LOG_DROP_ALL",
        "FW_LOG_ACCEPT_CRIT",
        "FW_LOG_ACCEPT_ALL",
        # IPsec support
        "FW_IPSEC_TRUST",
        # Custom rulezz
        #     net,protocol[,dport][,sport]
        "FW_SERVICES_ACCEPT_EXT",
        "FW_SERVICES_ACCEPT_INT",
        "FW_SERVICES_ACCEPT_DMZ",
        # Custom kernel modules, e.g., for FTP
        "FW_LOAD_MODULES",
        # Services defined in /usr/share/SuSEfirewall2/services/ directory
        # FATE #300687: Ports for SuSEfirewall added via packages
        "FW_CONFIGURATIONS_EXT",
        "FW_CONFIGURATIONS_INT",
        "FW_CONFIGURATIONS_DMZ",
        # bsc#916376: Ports need to be open already during boot
        "FW_BOOT_FULL_INIT"
      ]

      # FATE #300970: Firewall support for SMB browsing
      @broadcast_related_module = "nf_conntrack_netbios_ns"

      # Variable for ReportOnlyOnce() function
      @report_only_once = []

      # <!-- SuSEFirewall LOCAL FUNCTIONS //-->

      # <!-- SuSEFirewall GLOBAL FUNCTIONS //-->

      # bnc #388773
      # By default needed packages are just checked, not installed
      @check_and_install_package = false

      # Are needed packages (SuSEfirewall2) installed?
      @needed_packages_installed = nil

      # Configuration has been read and it's useful
      @fw_service_can_be_configured = false

      # old internal services definitions are converted to new services defined by packages
      # but only once
      @converted_to_services_dbp_file = Ops.add(
        Directory.vardir,
        "/yast2-firewall-already-converted-to-sdbp"
      )

      # services have been already converted
      @already_converted = false

      @protocol_translations = {
        # protocol name
        "tcp"   => _("TCP"),
        # protocol name
        "udp"   => _("UDP"),
        # protocol name
        "_rpc_" => _("RPC"),
        # protocol name
        "ip"    => _("IP")
      }
    end

    # <!-- SuSEFirewall VARIABLES //-->

    # <!-- SuSEFirewall GLOBAL FUNCTIONS USED BY LOCAL ONES //-->

    # Report the error, warning, message only once.
    # Stores the error, warning, message in memory.
    # This is just a helper function that could avoid from filling y2log up with
    # a lot of the very same messages - 'foreach()' is a very powerful builtin.
    #
    # @param [String] what_to_report error, warning or message
    # @return [Boolean] whether the message should be reported or not
    #
    # @example
    #   string error = sformat("Port number %1 is invalid.", port_nr);
    #   if (ReportOnlyOnce(error)) y2error(error);
    def ReportOnlyOnce(what_to_report)
      return false if Builtins.contains(@report_only_once, what_to_report)

      @report_only_once = Builtins.add(@report_only_once, what_to_report)
      true
    end

    # <!-- SuSEFirewall GLOBAL FUNCTIONS USED BY LOCAL ONES //-->

    # <!-- SuSEFirewall LOCAL FUNCTIONS //-->

    # Function returns whether the feature 'any' network interface is supported in the
    # firewall configuration. The string 'any' must be in the 'EXT' zone.
    # Updated: Currently returns only 'true' as every unasigned interface is
    # automatically assigned to the EXT zone by SuSEfirewall2.
    #
    # @return [Boolean] is_supported whether the feature is supported or not
    def IsAnyNetworkInterfaceSupported
      # Currently unasigned interfaces belong to the EXT zone by dafault
      true
    end

    # Function return list of variables needed for SuSEFirewall's settings.
    #
    # @return [Array<String>] of names of variables
    def GetListOfSuSEFirewallVariables
      deep_copy(@SuSEFirewall_variables)
    end

    # Local function for increasing the verbosity level.
    def IncreaseVerbosity
      @verbose_level = Ops.add(@verbose_level, 1)

      nil
    end

    # Local function for decreasing the verbosity level.
    def DecreaseVerbosity
      @verbose_level = Ops.subtract(@verbose_level, 1)

      nil
    end

    # Local function returns if other functions should produce verbose output.
    # like popups, reporting errors, etc.
    #
    # @return [Boolean] is_verbose
    def IsVerbose
      # verbose level must be above zero to be verbose
      Ops.greater_than(@verbose_level, 0)
    end

    # Local function for returning default values (if defined) for sysconfig variables.
    #
    # @param [String] variable sysconfig variable
    # @return [String] default value
    def GetDefaultValue(variable)
      Ops.get(@DEFAULT_SETTINGS, variable, "")
    end

    # Local function for reading list of sysconfig variables into internal variables.
    #
    # @param [Array<String>] variables of sysconfig variables
    def ReadSysconfigSuSEFirewall(variables)
      variables = deep_copy(variables)
      Builtins.foreach(variables) do |variable|
        value = Convert.to_string(
          SCR.Read(Builtins.add(path(".sysconfig.SuSEfirewall2"), variable))
        )
        # if value is undefined, get default value
        value = GetDefaultValue(variable) if value.nil? || value == ""
        # BNC #426000
        # backslash at the end
        if Builtins.regexpmatch(value, "[ \t]*\\\\[ \t]*\n")
          rules = Builtins.splitstring(value, "\\ \t\n")
          rules = Builtins.filter(rules) do |one_rule|
            !one_rule.nil? && one_rule != ""
          end
          value = Builtins.mergestring(rules, " ")
        end
        # BNC #194419
        # replace all "\n" with " " in variables
        if Builtins.regexpmatch(value, "\n")
          value = Builtins.mergestring(Builtins.splitstring(value, "\n"), " ")
        end
        # replace all "\t" with " " in variables
        if Builtins.regexpmatch(value, "\t")
          value = Builtins.mergestring(Builtins.splitstring(value, "\t"), " ")
        end
        Ops.set(@SETTINGS, variable, value)
      end

      nil
    end

    # Local function for reseting list of sysconfig variables in internal variables.
    #
    # @param [Array<String>] variables of sysconfig variables
    def ResetSysconfigSuSEFirewall(variables)
      variables = deep_copy(variables)
      Builtins.foreach(variables) do |variable|
        # reseting means getting default variables
        Ops.set(@SETTINGS, variable, GetDefaultValue(variable))
      end

      nil
    end

    # Local function for writing the list of internal variables into sysconfig.
    # List of variables is list of keys in SETTINGS map, to sync configuration
    # into the disk, use `nil` as the last list item.
    #
    # @param [Array<String>] variables of sysconfig variables
    # @return [Boolean] if successful
    def WriteSysconfigSuSEFirewall(variables)
      variables = deep_copy(variables)
      write_status = true
      value = ""

      Builtins.foreach(variables) do |variable|
        # if variable is undefined, get default value
        value = Ops.get_string(@SETTINGS, variable) { GetDefaultValue(variable) }
        write_status = SCR.Write(
          Builtins.add(path(".sysconfig.SuSEfirewall2"), variable),
          value
        )
        if !write_status
          Report.Error(
            Message.CannotWriteSettingsTo("/etc/sysconfig/SuSEFirewall2")
          )
          raise Break
        end
      end

      write_status = SCR.Write(path(".sysconfig.SuSEfirewall2"), nil)
      if !write_status
        Report.Error(
          Message.CannotWriteSettingsTo("/etc/sysconfig/SuSEFirewall2")
        )
      end

      write_status
    end

    # Local function returns configuration string used in configuration for zone.
    # For instance "ext" for "EXT" zone.
    #
    # @param [String] zone shortname
    # @return [String] zone configuration string
    def GetZoneConfigurationString(zone)
      if IsKnownZone(zone)
        # zones in SuSEFirewall configuration are identified by lowercased zone shorters
        return Builtins.tolower(zone)
      end
      nil
    end

    # Local function returns zone name (shortname) for configuration string.
    # For instance "EXT" for "ext" zone.
    #
    # @param [String] zone_string configuration string
    # @return [String] zone shortname
    def GetConfigurationStringZone(zone_string)
      if IsKnownZone(Builtins.toupper(zone_string))
        # zones in SuSEFirewall configuration are identified by lowercased zone shorters
        return Builtins.toupper(zone_string)
      end
      nil
    end

    # Function returns list of allowed services for zone and protocol
    #
    # @param [String] zone
    # @param [String] protocol
    # @return [Array<String>] of allowed services/ports
    def GetAllowedServicesForZoneProto(zone, protocol)
      Builtins.splitstring(
        Ops.get_string(
          @SETTINGS,
          Ops.add(Ops.add(Ops.add("FW_SERVICES_", zone), "_"), protocol),
          ""
        ),
        " "
      )
    end

    # Function sets list of services as allowed ports for zone and protocol
    #
    # @param [Array<String>] allowed_services of allowed ports/services
    # @param [String] zone
    # @param [String] protocol
    def SetAllowedServicesForZoneProto(allowed_services, zone, protocol)
      allowed_services = deep_copy(allowed_services)
      SetModified()

      Ops.set(
        @SETTINGS,
        Ops.add(Ops.add(Ops.add("FW_SERVICES_", zone), "_"), protocol),
        Builtins.mergestring(Builtins.toset(allowed_services), " ")
      )

      nil
    end

    # Local function returns configuration string for broadcast packets.
    #
    # @return [String] with broadcast configuration
    def GetBroadcastConfiguration(zone)
      Ops.get_string(@SETTINGS, Ops.add("FW_ALLOW_FW_BROADCAST_", zone), "no")
    end

    # Local function saves configuration string for broadcast packets.
    #
    # @param [String] zone
    # @param [String] broadcast_configuration with broadcast configuration
    def SetBroadcastConfiguration(zone, broadcast_configuration)
      SetModified()

      Ops.set(
        @SETTINGS,
        Ops.add("FW_ALLOW_FW_BROADCAST_", zone),
        broadcast_configuration
      )

      nil
    end

    # Local function return map of allowed ports (without aliases).
    # If any list for zone is defined but empty, all allowed
    # UDP ports for this zone also accept broadcast packets.
    # This function returns only ports that are mentioned in configuration,
    # it doesn't return ports that are listed in some service (defined by package)
    # which is enabled.
    #
    # @return [Hash{String => Array<String>}] strings are allowed ports or port ranges
    #
    #
    # **Structure:**
    #
    #     $[
    #        "ZONE1" : [ "port1", "port2" ],
    #        "ZONE2" : [ "port3", "port4" ],
    #        "ZONE3" : [ ]
    #      ]
    #      or
    #      $[
    #        "ZONE1" : [ "yes" ],  // will work for all ports automatically
    #        "ZONE3" : [ ],
    #        "ZONE3" : [ ]
    #      ]
    def GetBroadcastAllowedPorts
      allowed_ports = {}

      Builtins.foreach(GetKnownFirewallZones()) do |zone|
        broadcast = GetBroadcastConfiguration(zone)
        # no broadcast allowed for this zone
        if broadcast == "no"
          Ops.set(allowed_ports, zone, [])
          # BNC #694782: "yes" is automatically translated by SuSEfirewall2
        elsif broadcast == "yes"
          Ops.set(allowed_ports, zone, ["yes"])
          # only listed ports allows broadcast
        else
          Ops.set(allowed_ports, zone, Builtins.splitstring(broadcast, " "))
          Ops.set(
            allowed_ports,
            zone,
            Builtins.filter(Builtins.splitstring(broadcast, " ")) do |not_space|
              not_space != ""
            end
          )
        end
      end

      Builtins.y2debug("Allowed Broadcast Ports: %1", allowed_ports)

      deep_copy(allowed_ports)
    end

    # Function creates allowed-broadcast-ports string from broadcast map and saves it.
    #
    # @param [Hash<String,Array<String>>] broadcast strings are allowed ports or port ranges
    # @see GetBroadcastAllowedPorts() for an example of data
    def SetBroadcastAllowedPorts(broadcast)
      broadcast = deep_copy(broadcast)
      SetModified()

      Builtins.foreach(GetKnownFirewallZones()) do |zone|
        Ops.set(broadcast, zone, ["no"]) if Ops.get(broadcast, zone, []) == []
        SetBroadcastConfiguration(
          zone,
          Builtins.mergestring(Ops.get(broadcast, zone, []), " ")
        )
      end

      nil
    end

    # Function returns if broadcast is allowed for needed ports in zone.
    #
    # @param [Array<String>] needed_ports
    # @param [String] zone
    # @return [Boolean] if is allowed
    #
    # @example
    #    IsBroadcastAllowed (["port-xyz", "53"], "EXT") -> true
    def IsBroadcastAllowed(needed_ports, zone)
      needed_ports = deep_copy(needed_ports)
      if Builtins.size(needed_ports) == 0
        Builtins.y2warning("Unknown service with no needed ports!")
        return nil
      end

      # getting broadcast allowed ports
      allowed_ports_map = GetBroadcastAllowedPorts()

      # Divide allowed port ranges and aliases (also with their port aliases)
      allowed_ports_divided = PortRanges.DividePortsAndPortRanges(
        Ops.get(allowed_ports_map, zone, []),
        true
      )

      # If there are no allowed ports at all
      if Ops.get(allowed_ports_divided, "ports", []) == [] &&
          Ops.get(allowed_ports_divided, "port_ranges", []) == []
        return false
      end

      is_allowed = true
      # checking all needed ports;
      Builtins.foreach(needed_ports) do |needed_port|
        # allowed ports don't contain the needed one and also portranges don't
        if !Builtins.contains(
          Ops.get(allowed_ports_divided, "ports", []),
          needed_port
        ) &&
            !PortRanges.PortIsInPortranges(
              needed_port,
              Ops.get(allowed_ports_divided, "port_ranges", [])
            )
          is_allowed = false
          raise Break
        end
      end

      is_allowed
    end

    # Local function removes list of ports from port allowing broadcast packets in zone.
    #
    # @param [Array<String>] needed_ports to be removed
    # @param [String] zone
    def RemoveAllowedBroadcast(needed_ports, zone)
      needed_ports = deep_copy(needed_ports)
      SetModified()

      allowed_ports = GetBroadcastAllowedPorts()
      list_ports_allowed = Ops.get(allowed_ports, zone, [])

      # ports to be allowed one by one
      Builtins.foreach(needed_ports) do |allow_this_port|
        # remove all aliases of ports yet mentioned in zone
        aliases_of_port = PortAliases.GetListOfServiceAliases(allow_this_port)
        list_ports_allowed = Builtins.filter(list_ports_allowed) do |just_allowed|
          !Builtins.contains(aliases_of_port, just_allowed)
        end
      end
      Ops.set(allowed_ports, zone, list_ports_allowed)

      # save it using function
      SetBroadcastAllowedPorts(allowed_ports)

      nil
    end

    # Local function adds list of ports to ports accepting broadcast
    #
    # @param [Array<String>] needed_ports of ports
    # @param [String] zone
    def AddAllowedBroadcast(needed_ports, zone)
      needed_ports = deep_copy(needed_ports)
      # changing only if ports are not allowed
      if !IsBroadcastAllowed(needed_ports, zone)
        SetModified()

        allowed_ports = GetBroadcastAllowedPorts()
        list_ports_allowed = Ops.get(allowed_ports, zone, [])

        # ports to be allowed one by one
        Builtins.foreach(needed_ports) do |allow_this_port|
          # at first: remove all aliases of ports yet mentioned in zone
          aliases_of_port = PortAliases.GetListOfServiceAliases(allow_this_port)
          list_ports_allowed = Builtins.filter(list_ports_allowed) do |just_allowed|
            !Builtins.contains(aliases_of_port, just_allowed)
          end
          # at second: add only one
          list_ports_allowed = Builtins.add(list_ports_allowed, allow_this_port)
        end
        Ops.set(allowed_ports, zone, list_ports_allowed)

        # save it using function
        SetBroadcastAllowedPorts(allowed_ports)
      end

      nil
    end

    # Local function for removing (disallowing) single service/port
    # for defined protocol and zone. Functions doesn't take care of
    # port-aliases.
    #
    # @param [String] remove_service service/port
    # @param [String] protocol
    # @param [String] zone
    # @return [Boolean] success
    def RemoveServiceFromProtocolZone(remove_service, protocol, zone)
      SetModified()

      key = Ops.add(Ops.add(Ops.add("FW_SERVICES_", zone), "_"), protocol)

      allowed = Builtins.splitstring(Ops.get_string(@SETTINGS, key, ""), " ")
      allowed = Builtins.filter(allowed) do |single_service|
        single_service != "" && single_service != remove_service
      end
      Ops.set(
        @SETTINGS,
        key,
        Builtins.mergestring(Builtins.toset(allowed), " ")
      )

      true
    end

    # Removes service defined by package (FATE #300687) from enabled services.
    #
    # @param [String] service
    # @param [String] zone
    #
    # @example
    #    RemoveServiceDefinedByPackageFromZone ("service:irc-server", "EXT");
    def RemoveServiceDefinedByPackageFromZone(service, zone)
      return nil if !IsKnownZone(zone)

      if service.nil?
        Builtins.y2error("Service Id can't be nil!")
        return nil
      elsif Builtins.regexpmatch(service, "^service:.*")
        service = Builtins.regexpsub(service, "^service:(.*)", "\\1")
      end

      # services defined by package are listed without "service:" which is here
      # just to distinguish between dynamic and static definitions
      supported_services = Builtins.splitstring(
        Ops.get_string(@SETTINGS, Ops.add("FW_CONFIGURATIONS_", zone), ""),
        " "
      )
      # Removing the service
      supported_services = Builtins.filter(supported_services) do |one_service|
        one_service != service
      end
      Ops.set(
        @SETTINGS,
        Ops.add("FW_CONFIGURATIONS_", zone),
        Builtins.mergestring(supported_services, " ")
      )

      SetModified()

      nil
    end

    # Adds service defined by package (FATE #300687) into list of enabled services.
    #
    # @param [String] service
    # @param [String] zone
    #
    # @example
    #    AddServiceDefinedByPackageIntoZone ("service:irc-server", "EXT");
    def AddServiceDefinedByPackageIntoZone(service, zone)
      return nil if !IsKnownZone(zone)

      if service.nil?
        Builtins.y2error("Service Id can't be nil!")
        return nil
      elsif Builtins.regexpmatch(service, "^service:.*")
        service = Builtins.regexpsub(service, "^service:(.*)", "\\1")
      end

      # services defined by package are listed without "service:" which is here
      # just to distinguish between dynamic and static definitions
      supported_services = Builtins.splitstring(
        Ops.get_string(@SETTINGS, Ops.add("FW_CONFIGURATIONS_", zone), ""),
        " "
      )
      # Adding the service
      supported_services = Builtins.toset(
        Builtins.add(supported_services, service)
      )
      Ops.set(
        @SETTINGS,
        Ops.add("FW_CONFIGURATIONS_", zone),
        Builtins.mergestring(supported_services, " ")
      )

      SetModified()

      nil
    end

    # Local function removes well-known service's support from zone.
    # Allowed ports are removed with all of their port-aliases.
    #
    # @param [String] service id
    # @param [String] zone
    def RemoveServiceSupportFromZone(service, zone)
      Yast.import "SuSEFirewallServices" # lazy import due to circular dependencies

      needed = SuSEFirewallServices.GetNeededPortsAndProtocols(service)
      # unknown service
      if needed.nil?
        Builtins.y2error("Undefined service '%1'", service)
        return nil
      end

      # FATE #300687: Ports for SuSEfirewall added via packages
      if SuSEFirewallServices.ServiceDefinedByPackage(service)
        if IsServiceSupportedInZone(service, zone) == true
          RemoveServiceDefinedByPackageFromZone(service, zone)
        end

        return nil
      end

      SetModified()

      # Removing service ports (and also port aliases for TCP and UDP)
      Builtins.foreach(@service_defined_by) do |key|
        needed_ports = Ops.get(needed, key, [])
        next if needed_ports == []
        if key == "tcp_ports"
          RemoveAllowedPortsOrServices(needed_ports, "TCP", zone, true)
        elsif key == "udp_ports"
          RemoveAllowedPortsOrServices(needed_ports, "UDP", zone, true)
        elsif key == "rpc_ports"
          RemoveAllowedPortsOrServices(needed_ports, "RPC", zone, false)
        elsif key == "ip_protocols"
          RemoveAllowedPortsOrServices(needed_ports, "IP", zone, false)
        elsif "broadcast_ports" == key
          RemoveAllowedBroadcast(needed_ports, zone)
        else
          Builtins.y2error("Unknown key '%1'", key)
        end
      end

      nil
    end

    # Local function adds well-known service's support into zone. It first of all
    # removes the current support for service with port-aliases.
    #
    # @param [String] service id
    # @param [String] zone
    def AddServiceSupportIntoZone(service, zone)
      Yast.import "SuSEFirewallServices" # lazy import due to circular dependencies

      needed = SuSEFirewallServices.GetNeededPortsAndProtocols(service)
      # unknown service
      if needed.nil?
        Builtins.y2error("Undefined service '%1'", service)
        return nil
      end

      SetModified()

      # FATE #300687: Ports for SuSEfirewall added via packages
      if SuSEFirewallServices.ServiceDefinedByPackage(service)
        AddServiceDefinedByPackageIntoZone(service, zone)

        return nil
      end

      # Removing service ports first (and also port aliases for TCP and UDP)
      if IsServiceSupportedInZone(service, zone) == true
        RemoveServiceSupportFromZone(service, zone)
      end

      Builtins.foreach(@service_defined_by) do |key|
        needed_ports = Ops.get(needed, key, [])
        next if needed_ports == []
        if key == "tcp_ports"
          AddAllowedPortsOrServices(needed_ports, "TCP", zone)
        elsif key == "udp_ports"
          AddAllowedPortsOrServices(needed_ports, "UDP", zone)
        elsif key == "rpc_ports"
          AddAllowedPortsOrServices(needed_ports, "RPC", zone)
        elsif key == "ip_protocols"
          AddAllowedPortsOrServices(needed_ports, "IP", zone)
        elsif "broadcast_ports" == key
          AddAllowedBroadcast(needed_ports, zone)
        else
          Builtins.y2error("Unknown key '%1'", key)
        end
      end

      nil
    end

    # Function resets flag which doesn't allow to read configuration from disk again.
    # So you actually can reread the configuration from disk. Currently, only the first
    # Read() call reads the configuration from disk.
    def ResetReadFlag
      @configuration_has_been_read = false

      nil
    end

    # Function sets if firewall should be protected from internal zone.
    #
    # @param [Boolean] set_protect set to be protected from internal zone
    def SetProtectFromInternalZone(set_protect)
      SetModified()

      if set_protect
        Ops.set(@SETTINGS, "FW_PROTECT_FROM_INT", "yes")
      else
        Ops.set(@SETTINGS, "FW_PROTECT_FROM_INT", "no")
      end

      nil
    end

    # Function returns if firewall is protected from internal zone.
    #
    # @return [Boolean] if protected from internal
    def GetProtectFromInternalZone
      Ops.get_string(@SETTINGS, "FW_PROTECT_FROM_INT", "no") == "yes"
    end

    # Function sets if firewall should support routing.
    #
    # @param [Boolean] set_route set to support route or not
    def SetSupportRoute(set_route)
      SetModified()

      if set_route
        Ops.set(@SETTINGS, "FW_STOP_KEEP_ROUTING_STATE", "yes")
        Ops.set(@SETTINGS, "FW_ROUTE", "yes")
      else
        Ops.set(@SETTINGS, "FW_STOP_KEEP_ROUTING_STATE", "no")
        Ops.set(@SETTINGS, "FW_ROUTE", "no")
      end

      nil
    end

    # Function returns if firewall supports routing.
    #
    # @return [Boolean] if route is supported
    def GetSupportRoute
      Ops.get_string(@SETTINGS, "FW_ROUTE", "no") == "yes"
    end

    # Function sets how firewall should trust successfully decrypted IPsec packets.
    # It should be the zone name (shortname) or 'no' to trust packets the same as
    # firewall trusts the zone from which IPsec packet came.
    #
    # @param [String] zone or "no"
    def SetTrustIPsecAs(zone)
      SetModified()

      # do not trust
      if zone == "no"
        Ops.set(@SETTINGS, "FW_IPSEC_TRUST", "no")
      # trust IPsec is a known zone
      elsif IsKnownZone(zone)
        zone = GetZoneConfigurationString(zone)
        Ops.set(@SETTINGS, "FW_IPSEC_TRUST", zone)
        # unknown zone, changing to default value
      else
        defaultv = GetDefaultValue("FW_IPSEC_TRUST")
        Builtins.y2warning(
          "Trust IPsec as '%1' (unknown zone) changed to '%2'",
          zone,
          defaultv
        )
        Ops.set(@SETTINGS, "FW_IPSEC_TRUST", defaultv)
      end

      nil
    end

    # Function returns the trust level of IPsec packets.
    # See SetTrustIPsecAs() for more information.
    #
    # @return [String] zone or "no"
    def GetTrustIPsecAs
      # do not trust
      return "no" if Ops.get(@SETTINGS, "FW_IPSEC_TRUST") == "no"

      # default value for 'yes" ~= "INT"
      return "INT" if Ops.get(@SETTINGS, "FW_IPSEC_TRUST") == "yes"

      zone = GetConfigurationStringZone(
        Ops.get_string(@SETTINGS, "FW_IPSEC_TRUST", "")
      )

      # trust as named zone (if known)
      return zone if IsKnownZone(zone)

      # unknown zone, change to default value
      SetModified()
      defaultv = GetDefaultValue("FW_IPSEC_TRUST")
      Builtins.y2warning(
        "Trust IPsec as '%1' (unknown zone) changed to '%2'",
        Ops.get_string(@SETTINGS, "FW_IPSEC_TRUST", ""),
        defaultv
      )
      SetTrustIPsecAs(defaultv)
      "no"
    end

    # Function for getting exported SuSEFirewall configuration
    #
    # @return [Hash{String => Object}] with configuration
    def Export
      deep_copy(@SETTINGS)
    end

    # Function for setting SuSEFirewall configuration from input
    #
    # @param [Hash<String, Object>] import_settings with configuration
    def Import(import_settings)
      Read()
      @SETTINGS.merge!(import_settings || {})
      @configuration_has_been_read = true

      SetModified()

      nil
    end

    # Function returns if the interface is in zone.
    #
    # @param [String] interface
    # @param [String] zone firewall zone
    # @return [Boolean] is in zone
    #
    # @example IsInterfaceInZone ("eth-id-01:11:DA:9C:8A:2F", "INT") -> false
    def IsInterfaceInZone(interface, zone)
      interfaces = Builtins.splitstring(
        Ops.get_string(@SETTINGS, Ops.add("FW_DEV_", zone), ""),
        " "
      )
      Builtins.contains(interfaces, interface)
    end

    # Function returns the firewall zone of interface, nil if no zone includes
    # the interface. Error is reported when interface is found in multiple
    # firewall zones, then the first appearance is returned.
    #
    # @param [String] interface
    # @return [String] zone
    #
    # @example GetZoneOfInterface ("eth-id-01:11:DA:9C:8A:2F") -> "DMZ"
    def GetZoneOfInterface(interface)
      interface_zone = []

      Builtins.foreach(GetKnownFirewallZones()) do |zone|
        if IsInterfaceInZone(interface, zone)
          interface_zone = Builtins.add(interface_zone, zone)
        end
      end

      # Fallback handling for 'any' in the FW_DEV_* configuration
      if interface == @special_all_interface_string &&
          Builtins.size(interface_zone) == 0
        interface_zone = [@special_all_interface_zone]
      end

      if IsVerbose() && Ops.greater_than(Builtins.size(interface_zone), 1)
        # TRANSLATORS: Error message, %1 = interface name (like eth0)
        Report.Error(
          Builtins.sformat(
            _(
              "Interface '%1' is included in multiple firewall zones.\n" \
                "Continuing with configuration can produce errors.\n" \
                "\n" \
                "It is recommended to leave the configuration and repair it manually in\n" \
                "the file '/etc/sysconfig/SuSEFirewall'."
            ),
            interface
          )
        )
      end

      # return the first existence of interface in zones
      # if it is not presented anywhere, nil is returned
      Ops.get_string(interface_zone, 0)
    end

    # Function returns list of zones of requested interfaces.
    # Special string 'any' in 'EXT' zone is supported.
    #
    # @param [Array<String>] interfaces
    # @return [Array<String>] firewall zones
    #
    # @example
    #    GetZonesOfInterfaces (["eth1","eth4"]) -> ["EXT"]
    def GetZonesOfInterfacesWithAnyFeatureSupported(interfaces)
      interfaces = deep_copy(interfaces)
      zones = []
      zone = ""

      # 'any' in 'EXT'
      interfaces_covered_by_any = GetInterfacesInZoneSupportingAnyFeature(
        @special_all_interface_zone
      )

      Builtins.foreach(interfaces) do |interface|
        # interface is covered by 'any' in 'EXT'
        zone = if Builtins.contains(interfaces_covered_by_any, interface)
          @special_all_interface_zone
        else
          # interface is explicitely mentioned in some zone
          GetZoneOfInterface(interface)
        end
        zones = Builtins.add(zones, zone) if !zone.nil?
      end

      Builtins.toset(zones)
    end

    # Function returns list of non-dial-up interfaces.
    #
    # @return [Array<String>] of non-dial-up interface names
    # @example GetAllNonDialUpInterfaces() -> ["eth1", "eth2"]
    def GetAllNonDialUpInterfaces
      non_dial_up_interfaces = []
      Builtins.foreach(GetAllKnownInterfaces()) do |interface|
        if Ops.get(interface, "type") != "dial_up"
          non_dial_up_interfaces = Builtins.add(
            non_dial_up_interfaces,
            Ops.get(interface, "id", "")
          )
        end
      end

      deep_copy(non_dial_up_interfaces)
    end

    # Function returns list of dial-up interfaces.
    #
    # @return [Array<String>] of dial-up interface names
    # @example GetAllDialUpInterfaces() -> ["modem0", "dsl5"]
    def GetAllDialUpInterfaces
      dial_up_interfaces = []
      Builtins.foreach(GetAllKnownInterfaces()) do |interface|
        if Ops.get(interface, "type") == "dial_up"
          dial_up_interfaces = Builtins.add(
            dial_up_interfaces,
            Ops.get(interface, "id", "")
          )
        end
      end

      deep_copy(dial_up_interfaces)
    end

    # Function removes interface from defined zone.
    #
    # @param [String] interface
    # @param [String] zone
    # @example RemoveInterfaceFromZone ("modem0", "EXT")
    def RemoveInterfaceFromZone(interface, zone)
      SetModified()

      Builtins.y2milestone(
        "Removing interface '%1' from '%2' zone.",
        interface,
        zone
      )

      interfaces_in_zone = Builtins.splitstring(
        Ops.get_string(@SETTINGS, Ops.add("FW_DEV_", zone), ""),
        " "
      )
      interfaces_in_zone = Builtins.filter(interfaces_in_zone) do |single_interface|
        single_interface != "" && single_interface != interface
      end
      Ops.set(
        @SETTINGS,
        Ops.add("FW_DEV_", zone),
        Builtins.mergestring(interfaces_in_zone, " ")
      )

      nil
    end

    # Functions adds interface into defined zone.
    # All appearances of interface in other zones are removed.
    #
    # @param [String] interface
    # @param [String] zone
    # @example AddInterfaceIntoZone ("eth5", "DMZ")
    def AddInterfaceIntoZone(interface, zone)
      SetModified()

      current_zone = GetZoneOfInterface(interface)

      DecreaseVerbosity()
      # removing all appearances of interface in zones, excepting current_zone==new_zone
      while !current_zone.nil? && current_zone != zone
        # interface is in any zone already, removing it at first
        RemoveInterfaceFromZone(interface, current_zone) if current_zone != zone
        current_zone = GetZoneOfInterface(interface)
      end
      IncreaseVerbosity()

      Builtins.y2milestone(
        "Adding interface '%1' into '%2' zone.",
        interface,
        zone
      )
      interfaces_in_zone = Builtins.splitstring(
        Ops.get_string(@SETTINGS, Ops.add("FW_DEV_", zone), ""),
        " "
      )
      interfaces_in_zone = Builtins.toset(
        Builtins.add(interfaces_in_zone, interface)
      )
      Ops.set(
        @SETTINGS,
        Ops.add("FW_DEV_", zone),
        Builtins.mergestring(interfaces_in_zone, " ")
      )

      nil
    end

    # Function returns list of known interfaces in requested zone.
    # Special strings like 'any' or 'auto' and unknown interfaces are removed from list.
    #
    # @param [String] zone
    # @return [Array<String>] of interfaces
    # @example GetInterfacesInZone ("DMZ") -> ["eth4", "eth5"]
    def GetInterfacesInZone(zone)
      interfaces_in_zone = Builtins.splitstring(
        Ops.get_string(@SETTINGS, Ops.add("FW_DEV_", zone), ""),
        " "
      )

      known_interfaces_now = GetListOfKnownInterfaces()

      # filtering special strings
      interfaces_in_zone = Builtins.filter(interfaces_in_zone) do |interface|
        interface != "" && Builtins.contains(known_interfaces_now, interface)
      end

      deep_copy(interfaces_in_zone)
    end

    # Function returns all interfaces already configured in firewall.
    #
    # @return [Array<String>] of configured interfaces
    def GetFirewallInterfaces
      firewall_configured_devices = []

      Builtins.foreach(GetKnownFirewallZones()) do |zone|
        firewall_configured_devices = Convert.convert(
          Builtins.union(firewall_configured_devices, GetInterfacesInZone(zone)),
          from: "list",
          to:   "list <string>"
        )
      end

      Builtins.toset(firewall_configured_devices)
    end

    # Returns list of interfaces not mentioned in any zone and covered by the
    # special string 'any' in zone 'EXT' if such string exists there and the zone
    # is EXT. If the feature 'any' is not set, function returns empty list.
    #
    # @param [String] zone
    # @return [Array<String>] of interfaces covered by special string 'any'
    # @see #IsAnyNetworkInterfaceSupported()
    def InterfacesSupportedByAnyFeature(zone)
      result = []

      if zone == @special_all_interface_zone && IsAnyNetworkInterfaceSupported()
        known_interfaces_now = GetListOfKnownInterfaces()
        configured_interfaces = GetFirewallInterfaces()
        Builtins.foreach(known_interfaces_now) do |one_interface|
          if !Builtins.contains(configured_interfaces, one_interface)
            Builtins.y2milestone(
              "Interface '%1' supported by special string '%2' in zone '%3'",
              one_interface,
              @special_all_interface_string,
              @special_all_interface_zone
            )
            result = Builtins.add(result, one_interface)
          end
        end
      end

      deep_copy(result)
    end

    # Function returns list of known interfaces in requested zone.
    # Special string 'any' in EXT zone covers all interfaces without
    # any zone assignment.
    #
    # @param [String] zone
    # @return [Array<String>] of interfaces
    def GetInterfacesInZoneSupportingAnyFeature(zone)
      interfaces_in_zone = GetInterfacesInZone(zone)

      # 'any' in EXT zone, add all interfaces without zone to this one
      interfaces_covered_by_any = InterfacesSupportedByAnyFeature(zone)
      if Ops.greater_than(Builtins.size(interfaces_covered_by_any), 0)
        interfaces_in_zone = Convert.convert(
          Builtins.union(interfaces_in_zone, interfaces_covered_by_any),
          from: "list",
          to:   "list <string>"
        )
      end

      deep_copy(interfaces_in_zone)
    end

    # Returns whether a service is mentioned in FW_CONFIGURATIONS_[EXT|INT|DMZ].
    # These services are defined by random packages.
    #
    # @param [String] service e.g., "service:sshd"
    # @param [String] zone e.g., "EXT"
    # @return [Boolean] if service is supported in zone
    #
    # @example
    #    IsServiceDefinedByPackageSupportedInZone ("service:sshd", "EXT") -> true
    def IsServiceDefinedByPackageSupportedInZone(service, zone)
      return nil if !IsKnownZone(zone)

      if service.nil?
        Builtins.y2error("Service Id can't be nil!")
        return nil
      elsif Builtins.regexpmatch(service, "^service:.*")
        service = Builtins.regexpsub(service, "^service:(.*)", "\\1")
      end

      # services defined by package are listed without "service:" which is here
      # just to distinguish between dynamic and static definitions
      supported_services = Builtins.splitstring(
        Ops.get_string(@SETTINGS, Ops.add("FW_CONFIGURATIONS_", zone), ""),
        " "
      )
      Builtins.contains(supported_services, service)
    end

    # Function returns if service is supported (allowed) in zone. Service must be defined
    # in the SuSEFirewallServices. Works transparently also with services defined by packages.
    # Such service starts with "service:" prefix.
    #
    # @see YCP Module SuSEFirewallServices
    # @param [String] service id
    # @param [String] zone
    # @return [Boolean] if supported
    #
    # @example
    #    // All ports defined by dns-server service in SuSEFirewallServices module
    #    // are enabled in the respective zone
    #    IsServiceSupportedInZone ("dns-server", "EXT") -> true
    #  // irc-server definition exists on the system and the irc-server
    #  // is mentioned in FW_CONFIGURATIONS_EXT variable of SuSEfirewall2
    #  IsServiceSupportedInZone ("service:irc-server", "EXT") -> true
    def IsServiceSupportedInZone(service, zone)
      return nil if !IsKnownZone(zone)

      Yast.import "SuSEFirewallServices" # lazy import due to circular dependencies

      needed = SuSEFirewallServices.GetNeededPortsAndProtocols(service)

      # SuSEFirewall feature FW_PROTECT_FROM_INT
      # should not be protected and searched zones include also internal (or the zone IS internal, sure)
      if zone == @int_zone_shortname && !GetProtectFromInternalZone()
        Builtins.y2milestone(
          "Checking for service '%1', in '%2', PROTECT_FROM_INTERNAL='no' => allowed",
          service,
          zone
        )
        return true
      end

      # FATE #300687: Ports for SuSEfirewall added via packages
      if SuSEFirewallServices.ServiceDefinedByPackage(service)
        supported = IsServiceDefinedByPackageSupportedInZone(service, zone)
        return supported
      end

      # starting with nil value, any false means that the service is not supported
      service_is_supported = nil
      Builtins.foreach(@service_defined_by) do |key|
        needed_ports = Ops.get(needed, key, [])
        next if needed_ports == []
        if key == "tcp_ports"
          service_is_supported = ArePortsOrServicesAllowed(
            needed_ports,
            "TCP",
            zone,
            true
          )
        elsif key == "udp_ports"
          service_is_supported = ArePortsOrServicesAllowed(
            needed_ports,
            "UDP",
            zone,
            true
          )
        elsif key == "rpc_ports"
          service_is_supported = ArePortsOrServicesAllowed(
            needed_ports,
            "RPC",
            zone,
            false
          )
        elsif key == "ip_protocols"
          service_is_supported = ArePortsOrServicesAllowed(
            needed_ports,
            "IP",
            zone,
            false
          )
        elsif "broadcast_ports" == key
          # testing for allowed broadcast ports
          service_is_supported = IsBroadcastAllowed(needed_ports, zone)
        else
          Builtins.y2error("Unknown key '%1'", key)
        end
        # service is not supported, we don't have to do more tests
        raise Break if service_is_supported == false
      end

      service_is_supported
    end

    # Function sets status for several services in several firewall zones.
    #
    # @param [Array<String>] services_ids
    # @param [Array<String>] firewall_zones (EXT|INT|DMZ...)
    # @param [Boolean] new_status of services
    # @return nil
    #
    # @example
    #    SetServicesForZones (["samba-server", "service:irc-server"], ["DMZ", "EXT"], false);
    #    SetServicesForZones (["samba-server", "service:irc-server"], ["EXT", "DMZ"], true);
    #
    # @see #GetServicesInZones()
    # @see #GetServices()
    def SetServicesForZones(services_ids, firewall_zones, new_status)
      # setting for each service
      Builtins.foreach(services_ids) do |service_id|
        Builtins.foreach(firewall_zones) do |firewall_zone|
          # zone must be known one
          if !IsKnownZone(firewall_zone)
            Builtins.y2error(
              "Zone '%1' is unknown firewall zone, skipping...",
              firewall_zone
            )
            next
          end
          SetModified()
          # setting new status
          if new_status == true
            Builtins.y2milestone(
              "Adding '%1' into '%2' zone",
              service_id,
              firewall_zone
            )
            AddServiceSupportIntoZone(service_id, firewall_zone)
          else
            Builtins.y2milestone(
              "Removing '%1' from '%2' zone",
              service_id,
              firewall_zone
            )
            RemoveServiceSupportFromZone(service_id, firewall_zone)
          end
        end
      end

      nil
    end

    # Local function sets the default configuration and fills internal values.
    def ReadDefaultConfiguration
      @SETTINGS = {}

      ResetSysconfigSuSEFirewall(GetListOfSuSEFirewallVariables())

      nil
    end

    # Local function reads current configuration and fills internal values.
    def ReadCurrentConfiguration
      @SETTINGS = {}

      # is firewall enabled in /etc/init.d/ ?
      Ops.set(@SETTINGS, "enable_firewall", IsEnabled())
      # is firewall started now?
      Ops.set(@SETTINGS, "start_firewall", IsStarted())

      ReadSysconfigSuSEFirewall(GetListOfSuSEFirewallVariables())

      nil
    end

    # Fills the configuration with default settings,
    # adjusts internal variables that firewall cannot be configured.
    def FillUpEmptyConfig
      # do not call it again
      @configuration_has_been_read = true

      # Default settings, services are disabled
      @SETTINGS = deep_copy(@DEFAULT_SETTINGS)
      Ops.set(@SETTINGS, "enable_firewall", false)
      Ops.set(@SETTINGS, "start_firewall", false)

      # Cannot be configured, packages weren't installed
      @fw_service_can_be_configured = false

      nil
    end

    # Function for reading SuSEFirewall configuration.
    # Fills internal variables only.
    #
    # @return [Boolean] if successful
    def Read
      # Do not read it again and again
      # to avoid rewriting changes already made
      if @configuration_has_been_read
        Builtins.y2milestone(
          "SuSEfirewall2 configuration has been read already."
        )
        return @fw_service_can_be_configured
      end

      # bnc #887406
      if !FileUtils.Exists(CONFIG_FILE) || !SuSEFirewallIsSelectedOrInstalled()
        log.warn "No firewall config -> firewall can't be read"
        FillUpEmptyConfig()
        return false
      end

      # Can be configured, packages were installed
      @fw_service_can_be_configured = true

      # Progress only for normal configuration
      have_progress = Mode.normal

      if have_progress
        # TRANSLATORS: Dialog caption
        read_caption = _("Initializing Firewall Configuration")

        Progress.New(
          read_caption,
          " ",
          3,
          [
            # TRANSLATORS: Progress step
            _("Check for network devices"),
            # TRANSLATORS: Progress step
            _("Read current configuration"),
            # TRANSLATORS: Progress step
            _("Check possibly conflicting services")
          ],
          [
            # TRANSLATORS: Progress step
            _("Checking for network devices..."),
            # TRANSLATORS: Progress step
            _("Reading current configuration..."),
            # TRANSLATORS: Progress step
            _("Checking possibly conflicting services..."),
            Message.Finished
          ],
          ""
        )

        Progress.NextStage
      end

      # Always call NI::Read, bnc #396646
      NetworkInterfaces.Read

      Progress.NextStage if have_progress

      ReadCurrentConfiguration()

      Progress.NextStage if have_progress

      # checking if any possibly conficting services were turned on in configuration
      # filling internal values for later checkings
      # CheckAllPossiblyConflictingServices();
      # -- Function has been turned off as we don't support services defined by YaST itself anymore --

      Builtins.y2milestone(
        "Firewall configuration has been read: %1.",
        @SETTINGS
      )
      # to read configuration only once
      @configuration_has_been_read = true

      Progress.NextStage if have_progress

      # bnc #399217
      # Converting built-in service definitions to services defined by packages
      ConvertToServicesDefinedByPackages()

      Progress.Finish if have_progress

      true
    end

    # Function returns whether some RPC service is allowed in the configuration.
    # These services reallocate their ports when restarted. See details in
    # bugzilla bug #186186.
    #
    # @return [Boolean] some_RPC_service_used
    def AnyRPCServiceInConfiguration
      ret = false

      Builtins.foreach(GetKnownFirewallZones()) do |fw_zone|
        fw_rule = Builtins.sformat("FW_SERVICES_%1_RPC", fw_zone)
        listed_services = Ops.get_string(@SETTINGS, fw_rule) do
          GetDefaultValue(fw_rule)
        end
        # easy case
        next if listed_services.nil? || listed_services == ""
        # something listed but it still might be empty definition
        services_list = Builtins.splitstring(listed_services, " \n\t")
        services_list = Builtins.filter(services_list) do |service|
          service != ""
        end
        if Ops.greater_than(Builtins.size(services_list), 0)
          ret = true
          raise Break
        end
      end

      Builtins.y2milestone("Some RPC service found: %1", ret)
      ret
    end

    # Function which stops firewall. Then firewall is started immediately when firewall
    # is wanted to be started: SetStartService(boolean).
    #
    # @return [Boolean] if successful
    def ActivateConfiguration
      # just disabled
      return true if !SuSEFirewallIsInstalled()

      # starting firewall during second stage can cause deadlock in systemd - bnc#798620
      # Moreover, it is not needed. Firewall gets started via dependency on multi-user.target
      # when second stage is over.
      if Mode.installation && !Mode.autoinst
        Builtins.y2milestone("Do not touch firewall services during installation")

        return true
      end

      # Firewall should start after Write()
      if GetStartService()
        # Not started - start it
        if !IsStarted()
          Builtins.y2milestone("Starting firewall services")
          return StartServices()
        # Started - restart it
        # modified - restart it, or ...
        # bugzilla #186186
        # If any RPC service is configured to be allowed, always restart the firewall
        # Some of these service's ports might have been reallocated (when SuSEFirewall
        # is used from outside, e.g., yast2-nfs-server)
        elsif GetModified() || AnyRPCServiceInConfiguration()
          Builtins.y2milestone("Stopping firewall services")
          StopServices()
          Builtins.y2milestone("Starting firewall services")
          return StartServices()
        # not modified - skip restart
        else
          Builtins.y2milestone(
            "Configuration hasn't modified, skipping restarting services"
          )
          return true
        end
      # Firewall should stop after Write()
      # started - stop
      elsif IsStarted()
        Builtins.y2milestone("Stopping firewall services")
        return StopServices()
        # stopped - skip stopping
      else
        Builtins.y2milestone("Firewall has been stopped already")
        return true
      end
    end

    # Function writes configuration into /etc/sysconfig/ and enables or disables
    # firewall in /etc/init.d/ by the setting SetEnableService(boolean).
    # This is a write-only configuration, firewall is never started only enabled
    # or disabled.
    #
    # @return [Boolean] if successful
    def WriteConfiguration
      # just disabled
      return true if !SuSEFirewallIsInstalled()

      # Progress only for normal configuration and command line
      have_progress = Mode.normal

      if have_progress
        # TRANSLATORS: Dialog caption
        write_caption = _("Writing Firewall Configuration")

        Progress.New(
          write_caption,
          " ",
          2,
          [
            # TRANSLATORS: Progress step
            _("Write firewall settings"),
            # TRANSLATORS: Progress step
            _("Adjust firewall service")
          ],
          [
            # TRANSLATORS: Progress step
            _("Writing firewall settings..."),
            # TRANSLATORS: Progress step
            _("Adjusting firewall service..."),
            # TRANSLATORS: Progress step
            Message.Finished
          ],
          ""
        )

        Progress.NextStage
      end

      # only modified configuration is written
      if GetModified()
        Builtins.y2milestone(
          "Firewall configuration has been changed. Writing: %1.",
          @SETTINGS
        )

        if !WriteSysconfigSuSEFirewall(GetListOfSuSEFirewallVariables())
          # TRANSLATORS: a popup error message
          Report.Error(_("Writing settings failed"))
          return false
        end
      else
        Builtins.y2milestone("Firewall settings weren't modified, skipping...")
      end

      Progress.NextStage if have_progress

      # Adjusting services
      if GetModified()
        # enabling firewall in /etc/init.d/
        if Ops.get_boolean(@SETTINGS, "enable_firewall", false)
          Builtins.y2milestone("Enabling firewall services")
          return false if !EnableServices()
          # disabling firewall in /etc/init.d/
        else
          Builtins.y2milestone("Disabling firewall services")
          return false if !DisableServices()
        end
      else
        Builtins.y2milestone(
          "Firewall enable/disable wasn't modified, skipping..."
        )
      end

      Progress.NextStage if have_progress

      if @already_converted &&
          !FileUtils.Exists(@converted_to_services_dbp_file)
        Builtins.y2milestone(
          "Writing %1: %2",
          @converted_to_services_dbp_file,
          SCR.Write(path(".target.string"), @converted_to_services_dbp_file, "")
        )
      end

      Progress.Finish if have_progress

      true
    end

    # Helper function for the backward compatibility.
    # See WriteConfiguration(). Remove from code ASAP.
    #
    # @return [Boolean] if succesful
    def WriteOnly
      WriteConfiguration()
    end

    # Function for writing and enabling configuration it is an union of
    # WriteConfiguration() and ActivateConfiguration().
    #
    # @return [Boolean] if succesfull
    def Write
      CheckKernelModules()

      # just disabled
      return true if !SuSEFirewallIsInstalled()

      return false if !WriteConfiguration()

      return false if !ActivateConfiguration()

      true
    end

    # This powerful function returns list of services/ports which are
    # not assigned to any fully-supported known-services.
    # This function doesn't check for services defined by packages.
    # They are listed by a different way.
    #
    # @return [Array<String>] of additional (unassigned) services
    #
    # @example
    #    GetAdditionalServices("TCP", "EXT") -> ["53", "128"]
    def GetAdditionalServices(protocol, zone)
      if !IsSupportedProtocol(protocol)
        Builtins.y2error("Unknown protocol '%1'", protocol)
        return nil
      end
      if !IsKnownZone(zone)
        Builtins.y2error("Unknown zone '%1'", zone)
        return nil
      end

      # all ports or services allowed in zone for protocol
      all_allowed_services = GetAllowedServicesForZoneProto(zone, protocol)

      # all ports or services used by known service
      all_used_services = []

      Yast.import "SuSEFirewallServices" # lazy import due to circular dependencies

      # trying all possible (known) services
      Builtins.foreach(SuSEFirewallServices.GetSupportedServices) do |service_id, _service_name|
        # only when the service is allowed in zone - remove all its needed ports
        if IsServiceSupportedInZone(service_id, zone) == true
          # all needed ports etc for service/protocol
          needed_all = []
          if protocol == "TCP"
            needed_all = SuSEFirewallServices.GetNeededTCPPorts(service_id)
          elsif protocol == "UDP"
            needed_all = SuSEFirewallServices.GetNeededUDPPorts(service_id)
          elsif protocol == "RPC"
            needed_all = SuSEFirewallServices.GetNeededRPCPorts(service_id)
          elsif protocol == "IP"
            needed_all = SuSEFirewallServices.GetNeededIPProtocols(service_id)
          end
          Builtins.foreach(needed_all) do |remove_port|
            # all used services and their aliases
            all_used_services = Convert.convert(
              Builtins.union(
                all_used_services,
                PortAliases.GetListOfServiceAliases(remove_port)
              ),
              from: "list",
              to:   "list <string>"
            )
          end
        end
      end

      # some services are used by known defined-services
      if Ops.greater_than(Builtins.size(all_used_services), 0)
        all_used_services = Builtins.toset(all_used_services)
        # removing all used services from all allowed
        all_allowed_services = Builtins.filter(all_allowed_services) do |port|
          !Builtins.contains(all_used_services, port)
        end
      end

      # well, actually it returns list of services not-assigned to any well-known service
      deep_copy(all_allowed_services)
    end

    # Function returns map of `interfaces in zones`.
    #
    # @return [Hash{String => Array<String>}] interface in zones
    #
    #
    # **Structure:**
    #
    #        map $[zone : [list of interfaces]]
    #
    # @example
    #    GetFirewallInterfacesMap() -> $["DMZ":[], "EXT":["dsl0"], "INT":["eth1", "eth2"]]
    def GetFirewallInterfacesMap
      firewall_interfaces_now = {}

      # list of all known interfaces
      known_interfaces = GetListOfKnownInterfaces()

      # searching each zone
      Builtins.foreach(GetKnownFirewallZones()) do |zone|
        # filtering non-existing interfaces
        Ops.set(
          firewall_interfaces_now,
          zone,
          Builtins.filter(GetInterfacesInZone(zone)) do |interface|
            Builtins.contains(known_interfaces, interface)
          end
        )
      end

      deep_copy(firewall_interfaces_now)
    end

    # Function returns list of special strings like 'any' or 'auto' and uknown interfaces.
    #
    # @param [String] zone
    # @return [Array<String>] special strings or unknown interfaces
    #
    # @example
    #    GetSpecialInterfacesInZone("EXT") -> ["any", "unknown-1", "wrong-3"]
    def GetSpecialInterfacesInZone(zone)
      interfaces_in_zone = Builtins.splitstring(
        Ops.get_string(@SETTINGS, Ops.add("FW_DEV_", zone), ""),
        " "
      )

      known_interfaces_now = GetInterfacesInZone(zone)

      # filtering known interfaces and spaces
      interfaces_in_zone = Builtins.filter(interfaces_in_zone) do |interface|
        interface != "" && !Builtins.contains(known_interfaces_now, interface)
      end

      deep_copy(interfaces_in_zone)
    end

    # Function removes special string from defined zone.
    #
    # @param [String] interface
    # @param [String] zone
    def RemoveSpecialInterfaceFromZone(interface, zone)
      SetModified()

      Builtins.y2milestone(
        "Removing special string '%1' from '%2' zone.",
        interface,
        zone
      )

      interfaces_in_zone = Builtins.splitstring(
        Ops.get_string(@SETTINGS, Ops.add("FW_DEV_", zone), ""),
        " "
      )
      interfaces_in_zone = Builtins.filter(interfaces_in_zone) do |single_interface|
        single_interface != "" && single_interface != interface
      end
      Ops.set(
        @SETTINGS,
        Ops.add("FW_DEV_", zone),
        Builtins.mergestring(interfaces_in_zone, " ")
      )

      nil
    end

    # Functions adds special string into defined zone.
    #
    # @param [String] interface
    # @param [String] zone
    def AddSpecialInterfaceIntoZone(interface, zone)
      SetModified()

      Builtins.y2milestone(
        "Adding special string '%1' into '%2' zone.",
        interface,
        zone
      )
      interfaces_in_zone = Builtins.splitstring(
        Ops.get_string(@SETTINGS, Ops.add("FW_DEV_", zone), ""),
        " "
      )
      interfaces_in_zone = Builtins.toset(
        Builtins.add(interfaces_in_zone, interface)
      )
      Ops.set(
        @SETTINGS,
        Ops.add("FW_DEV_", zone),
        Builtins.mergestring(interfaces_in_zone, " ")
      )

      nil
    end

    # Function returns actual state of Masquerading support.
    #
    # @param _zone Ignored
    # @return [Boolean] if supported
    def GetMasquerade(_zone = nil)
      Ops.get_string(@SETTINGS, "FW_MASQUERADE", "no") == "yes" &&
        Ops.get_string(@SETTINGS, "FW_ROUTE", "no") == "yes"
    end

    # Function sets Masquerade support.
    #
    # @param enable [Boolean] to support or not to support it
    # @param _zone ignored
    def SetMasquerade(enable, _zone = nil)
      SetModified()

      Ops.set(@SETTINGS, "FW_MASQUERADE", enable ? "yes" : "no")

      # routing is needed for masquerading, but we can't swithc it off when disabling masquerading
      Ops.set(@SETTINGS, "FW_ROUTE", "yes") if enable

      nil
    end

    # Function returns list of rules of forwarding ports
    # to masqueraded IPs.
    #
    # @return  [Array<Hash{String => String>}] list of rules
    #
    #
    # **Structure:**
    #
    #     list [$[ key: value ]]
    #
    # @example
    #    GetListOfForwardsIntoMasquerade() -> [
    # $[
    #   "forward_to":"172.24.233.1",
    #   "protocol":"tcp",
    #   "req_ip":"192.168.0.3",
    #   "req_port":"355",
    #   "source_net":"192.168.0.0/20",
    #   "to_port":"533"],
    #   ...
    # ]
    def GetListOfForwardsIntoMasquerade
      list_of_rules = []

      Builtins.foreach(
        Builtins.splitstring(
          Ops.get_string(@SETTINGS, "FW_FORWARD_MASQ", ""),
          " "
        )
      ) do |forward_rule|
        next if forward_rule == ""
        # Format: <source network>,<ip to forward to>,<protocol>,<port>[,redirect port,[destination ip]]
        fw_rul = Builtins.splitstring(forward_rule, ",")
        # first four parameters has to be defined
        if Ops.get(fw_rul, 0, "") == "" || Ops.get(fw_rul, 1, "") == "" ||
            Ops.get(fw_rul, 2, "") == "" ||
            Ops.get(fw_rul, 3, "") == ""
          Builtins.y2warning(
            "Wrong definition of redirect rule: '%1', part of '%2'",
            forward_rule,
            Ops.get_string(@SETTINGS, "FW_FORWARD_MASQ", "")
          )
        end
        list_of_rules = Builtins.add(
          list_of_rules,

          "source_net" => Ops.get(fw_rul, 0, ""),
          "forward_to" => Ops.get(fw_rul, 1, ""),
          "protocol"   => Builtins.tolower(Ops.get(fw_rul, 2, "")),
          "req_port"   => Builtins.tolower(Ops.get(fw_rul, 3, "")),
          # to_port is req_port when undefined
          "to_port"    => Builtins.tolower(
            Ops.get(fw_rul, 4, Ops.get(fw_rul, 3, ""))
          ),
          "req_ip"     => Builtins.tolower(Ops.get(fw_rul, 5, ""))

        )
      end

      deep_copy(list_of_rules)
    end

    # Function removes rule for forwarding into masquerade
    # from the list of current rules returned by GetListOfForwardsIntoMasquerade().
    #
    # @param remove_item [Integer] item number
    #
    # @see #GetListOfForwardsIntoMasquerade()
    def RemoveForwardIntoMasqueradeRule(remove_item)
      SetModified()

      forward_rules = []

      row_counter = 0
      Builtins.foreach(
        Builtins.splitstring(
          Ops.get_string(@SETTINGS, "FW_FORWARD_MASQ", ""),
          " "
        )
      ) do |forward_rule|
        next if forward_rule == ""
        if row_counter != remove_item
          forward_rules = Builtins.add(forward_rules, forward_rule)
        end
        row_counter = Ops.add(row_counter, 1)
      end

      Ops.set(
        @SETTINGS,
        "FW_FORWARD_MASQ",
        Builtins.mergestring(forward_rules, " ")
      )

      nil
    end

    # Adds forward into masquerade rule.
    #
    # @param [String] source_net
    # @param [String] forward_to_ip
    # @param [String] protocol
    # @param [String] req_port
    # @param [String] redirect_to_port
    # @param [String] requested_ip
    #
    # @example
    #    AddForwardIntoMasqueradeRule ("0/0", "192.168.32.1", "TCP", "80", "8080", "10.0.0.1")
    def AddForwardIntoMasqueradeRule(source_net, forward_to_ip, protocol, req_port, redirect_to_port, requested_ip)
      SetModified()

      masquerade_rules = Ops.get_string(@SETTINGS, "FW_FORWARD_MASQ", "")

      masquerade_rules = Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(masquerade_rules, masquerade_rules != "" ? " " : ""),
                    source_net
                  ),
                  ","
                ),
                forward_to_ip
              ),
              ","
            ),
            protocol
          ),
          ","
        ),
        req_port
      )

      if redirect_to_port != "" || requested_ip != ""
        if requested_ip != ""
          masquerade_rules = Ops.add(
            Ops.add(
              Ops.add(Ops.add(masquerade_rules, ","), redirect_to_port),
              ","
            ),
            requested_ip
          )
          # port1 -> port2 are same
        elsif redirect_to_port != req_port
          masquerade_rules = Ops.add(
            Ops.add(masquerade_rules, ","),
            redirect_to_port
          )
        end
      end

      Ops.set(@SETTINGS, "FW_FORWARD_MASQ", masquerade_rules)

      nil
    end

    # Function returns actual state of logging for rule taken as parameter.
    #
    # @param [String] rule definition 'ACCEPT' or 'DROP'
    # @return [String] 'ALL', 'CRIT', or 'NONE'
    #
    # @example
    #   GetLoggingSettings("ACCEPT") -> "CRIT"
    #   GetLoggingSettings("DROP") -> "CRIT"
    def GetLoggingSettings(rule)
      ret_val = nil

      if rule == "ACCEPT"
        ret_val = if Ops.get_string(@SETTINGS, "FW_LOG_ACCEPT_ALL", "no") == "yes"
          "ALL"
        elsif Ops.get_string(@SETTINGS, "FW_LOG_ACCEPT_CRIT", "yes") == "yes"
          "CRIT"
        else
          "NONE"
        end
      elsif rule == "DROP"
        ret_val = if Ops.get_string(@SETTINGS, "FW_LOG_DROP_ALL", "no") == "yes"
          "ALL"
        elsif Ops.get_string(@SETTINGS, "FW_LOG_DROP_CRIT", "yes") == "yes"
          "CRIT"
        else
          "NONE"
        end
      else
        Builtins.y2error("Possible rules are only 'ACCEPT' or 'DROP'")
      end

      ret_val
    end

    # Function sets state of logging for rule taken as parameter.
    #
    # @param [String] rule definition 'ACCEPT' or 'DROP'
    # @param [String] state new logging state 'ALL', 'CRIT', or 'NONE'
    #
    # @example
    #   SetLoggingSettings ("ACCEPT", "ALL")
    #   SetLoggingSettings ("DROP", "NONE")
    def SetLoggingSettings(rule, state)
      SetModified()

      if rule == "ACCEPT"
        if state == "ALL"
          Ops.set(@SETTINGS, "FW_LOG_ACCEPT_CRIT", "yes")
          Ops.set(@SETTINGS, "FW_LOG_ACCEPT_ALL", "yes")
        elsif state == "CRIT"
          Ops.set(@SETTINGS, "FW_LOG_ACCEPT_CRIT", "yes")
          Ops.set(@SETTINGS, "FW_LOG_ACCEPT_ALL", "no")
        else
          Ops.set(@SETTINGS, "FW_LOG_ACCEPT_CRIT", "no")
          Ops.set(@SETTINGS, "FW_LOG_ACCEPT_ALL", "no")
        end
      elsif rule == "DROP"
        if state == "ALL"
          Ops.set(@SETTINGS, "FW_LOG_DROP_CRIT", "yes")
          Ops.set(@SETTINGS, "FW_LOG_DROP_ALL", "yes")
        elsif state == "CRIT"
          Ops.set(@SETTINGS, "FW_LOG_DROP_CRIT", "yes")
          Ops.set(@SETTINGS, "FW_LOG_DROP_ALL", "no")
        else
          Ops.set(@SETTINGS, "FW_LOG_DROP_CRIT", "no")
          Ops.set(@SETTINGS, "FW_LOG_DROP_ALL", "no")
        end
      else
        Builtins.y2error("Possible rules are only 'ACCEPT' or 'DROP'")
      end

      nil
    end

    # Function returns yes/no - ingoring broadcast for zone
    #
    # @param [String] zone
    # @return [String] "yes" or "no"
    #
    # @example
    #    # Does not log ignored broadcast packets
    #    GetIgnoreLoggingBroadcast ("EXT") -> "yes"
    def GetIgnoreLoggingBroadcast(zone)
      if !IsKnownZone(zone)
        Builtins.y2error("Unknown zone '%1'", zone)
        return nil
      end

      Ops.get_string(@SETTINGS, Ops.add("FW_IGNORE_FW_BROADCAST_", zone), "no")
    end

    # Function sets yes/no - ingoring broadcast for zone
    #
    # @param [String] zone
    # @param [String] bcast ignore 'yes' or 'no'
    #
    # @example
    #   # Does not log broadcast packets from DMZ
    #   SetIgnoreLoggingBroadcast ("DMZ", "yes")
    def SetIgnoreLoggingBroadcast(zone, bcast)
      if !IsKnownZone(zone)
        Builtins.y2error("Unknown zone '%1'", zone)
        return nil
      end

      SetModified()

      Ops.set(@SETTINGS, Ops.add("FW_IGNORE_FW_BROADCAST_", zone), bcast)

      nil
    end

    # Firewall Expert Rulezz

    # Returns list of rules describing protocols and ports that are allowed
    # to be accessed from listed hosts. All is returned as a single string.
    # Zone needs to be defined.
    #
    # @param [String] zone
    # @return [String] with rules
    def GetAcceptExpertRules(zone)
      zone = Builtins.toupper(zone)

      # Check for zone
      if !Builtins.contains(GetKnownFirewallZones(), zone)
        Builtins.y2error("Unknown firewall zone: %1", zone)
        return nil
      end

      Ops.get_string(@SETTINGS, Ops.add("FW_SERVICES_ACCEPT_", zone), "")
    end

    # Sets expert allow rules for zone.
    #
    # @param [String] zone
    # @param [String] expert_rules whitespace-separated expert_rules
    # @return [Boolean] if successful
    def SetAcceptExpertRules(zone, expert_rules)
      zone = Builtins.toupper(zone)

      # Check for zone
      if !Builtins.contains(GetKnownFirewallZones(), zone)
        Builtins.y2error("Unknown firewall zone: %1", zone)
        return false
      end

      Ops.set(@SETTINGS, Ops.add("FW_SERVICES_ACCEPT_", zone), expert_rules)
      SetModified()

      true
    end

    # Returns list of additional kernel modules, that are loaded by firewall on startup.
    # For instance "ip_conntrack_ftp" and "ip_nat_ftp" for FTP service.
    #
    # @return [Array<String>] of kernel modules
    #
    # @see /etc/sysconfig/SuSEfirewall2 option nr. 32 (FW_LOAD_MODULES)
    def GetFirewallKernelModules
      k_modules = Builtins.splitstring(
        Ops.get_string(@SETTINGS, "FW_LOAD_MODULES", ""),
        " \t\n"
      )

      k_modules = Builtins.filter(k_modules) { |one_module| one_module != "" }

      Builtins.toset(k_modules)
    end

    # Sets list of additional kernel modules to be loaded by firewall on startup.
    #
    # @param [Array<String>] k_modules list of kernel modules
    #
    # @see /etc/sysconfig/SuSEfirewall2 option nr. 32
    #
    # @example
    #   SuSEFirewall::SetFirewallKernelModules (["ip_conntrack_ftp","ip_nat_ftp"]);
    def SetFirewallKernelModules(k_modules)
      k_modules = deep_copy(k_modules)
      k_modules = Builtins.filter(k_modules) do |one_module|
        if one_module.nil?
          Builtins.y2error(
            "List of modules %1 contains 'nil'! It will be ignored.",
            k_modules
          )
          next false
        elsif one_module == ""
          Builtins.y2warning(
            "List of modules %1 contains an empty string, it will be ignored.",
            k_modules
          )
          next false
        end
        if Builtins.regexpmatch(one_module, " ") ||
            Builtins.regexpmatch(one_module, "\t")
          Builtins.y2warning(
            "Additional module '%1' contains spaces. They will be evaluated as two or more modules later.",
            one_module
          )
        end
        true
      end

      Ops.set(
        @SETTINGS,
        "FW_LOAD_MODULES",
        Builtins.mergestring(k_modules, " ")
      )
      SetModified()

      nil
    end

    # Returns translated protocol name. Translation is provided from
    # SuSEfirewall2 sysconfig format to l10n format.
    #
    # @param protocol [String] from sysconfig (e.g., _rpc_)
    # @return [String] translated string (e.g., RPC)
    def GetProtocolTranslatedName(protocol)
      protocol = Builtins.tolower(protocol)

      if protocol == ""
        ""
      elsif Ops.get(@protocol_translations, protocol).nil?
        Builtins.y2error("Unknown protocol: %1", protocol)
        # table item, %1 stands for the buggy protocol name
        Builtins.sformat(_("Unknown protocol (%1)"), protocol)
      else
        Ops.get(@protocol_translations, protocol, "")
      end
    end

    # Returns list of FW_SERVICES_ACCEPT_RELATED_*: Services to allow that are
    # considered RELATED by the connection tracking engine, e.g., SLP browsing
    # reply or Samba browsing reply.
    #
    # @param [String] zone
    # @return [Array<String>] list of definitions
    #
    # @example
    #   GetServicesAcceptRelated ("EXT") -> ["0/0,udp,427", "0/0,udp,137"]
    #
    # @see #SetServicesAcceptRelated()
    def GetServicesAcceptRelated(zone)
      if !IsKnownZone(zone)
        Builtins.y2error("Uknown zone '%1'", zone)
        return []
      end

      Builtins.splitstring(
        Ops.get_string(
          @SETTINGS,
          Ops.add("FW_SERVICES_ACCEPT_RELATED_", zone),
          ""
        ),
        " \t\n"
      )
    end

    # Functions sets FW_SERVICES_ACCEPT_RELATED_*: Services to allow that are
    # considered RELATED by the connection tracking engine, e.g., SLP browsing
    # reply or Samba browsing reply.
    #
    # @param [String] zone
    # @param [Array<String>] ruleset list of rules
    #
    # @example
    #   SetServicesAcceptRelated ("EXT", ["0/0,udp,427", "0/0,udp,137"])
    #
    # @see #GetServicesAcceptRelated()
    def SetServicesAcceptRelated(zone, ruleset)
      ruleset = deep_copy(ruleset)
      if !IsKnownZone(zone)
        Builtins.y2error("Uknown zone '%1'", zone)
        return
      end

      ruleset = Builtins.filter(ruleset) { |one_rule| !one_rule.nil? }

      SetModified()

      Ops.set(
        @SETTINGS,
        Ops.add("FW_SERVICES_ACCEPT_RELATED_", zone),
        Builtins.mergestring(ruleset, "\n")
      )

      nil
    end

    def CheckKernelModules
      needs_additional_module = false

      Builtins.foreach(GetKnownFirewallZones()) do |one_zone|
        if Ops.greater_or_equal(
          Builtins.size(GetServicesAcceptRelated(one_zone)),
          0
        )
          Builtins.y2milestone("Some ServicesAcceptRelated are defined")
          needs_additional_module = true
          raise Break
        end
      end

      if needs_additional_module
        k_modules = Builtins.splitstring(
          Ops.get_string(@SETTINGS, "FW_LOAD_MODULES", ""),
          " "
        )

        if !Builtins.contains(k_modules, @broadcast_related_module)
          Builtins.y2warning(
            "FW_LOAD_MODULES doesn't contain %1, adding",
            @broadcast_related_module
          )
          k_modules = Builtins.add(k_modules, @broadcast_related_module)
          Ops.set(
            @SETTINGS,
            "FW_LOAD_MODULES",
            Builtins.mergestring(k_modules, " ")
          )
          SetModified()
        end
      end

      nil
    end

    # Removes old-service definitions before they are added as services defined
    # by packages.
    def RemoveOldAllowedServiceFromZone(old_service_def, zone)
      old_service_def = deep_copy(old_service_def)
      Builtins.y2milestone("Removing: %1 from zone %2", old_service_def, zone)

      if Ops.get_list(old_service_def, "tcp_ports", []) != []
        Builtins.foreach(Ops.get_list(old_service_def, "tcp_ports", [])) do |one_service|
          RemoveService(one_service, "TCP", zone)
        end
      end

      if Ops.get_list(old_service_def, "udp_ports", []) != []
        Builtins.foreach(Ops.get_list(old_service_def, "udp_ports", [])) do |one_service|
          RemoveService(one_service, "UDP", zone)
        end
      end

      if Ops.get_list(old_service_def, "rpc_ports", []) != []
        Builtins.foreach(Ops.get_list(old_service_def, "rpc_ports", [])) do |one_service|
          RemoveService(one_service, "RPC", zone)
        end
      end

      if Ops.get_list(old_service_def, "ip_protocols", []) != []
        Builtins.foreach(Ops.get_list(old_service_def, "ip_protocols", [])) do |one_service|
          RemoveService(one_service, "IP", zone)
        end
      end

      if Ops.get_list(old_service_def, "broadcast_ports", []) != []
        broadcast = GetBroadcastAllowedPorts()

        Ops.set(broadcast, zone, Builtins.filter(Ops.get(broadcast, zone, [])) do |one_port|
          !Builtins.contains(
            Ops.get_list(old_service_def, "broadcast_ports", []),
            one_port
          )
        end)

        SetBroadcastAllowedPorts(broadcast)
      end

      nil
    end

    # Converts old built-in service definitions to services defined by packages.
    #
    # @see #bnc 399217
    def ConvertToServicesDefinedByPackages
      return if @already_converted

      if FileUtils.Exists(@converted_to_services_dbp_file)
        @already_converted = true
        return
      end

      # $[ zone : $[ protocol : [ list of ports ] ] ]
      current_conf = {}

      Builtins.foreach(GetKnownFirewallZones()) do |zone|
        Ops.set(current_conf, zone, {})
        Builtins.foreach(@supported_protocols) do |protocol|
          Ops.set(
            current_conf,
            [zone, protocol],
            GetAllowedServicesForZoneProto(zone, protocol)
          )
          Ops.set(
            current_conf,
            [zone, "broadcast"],
            Builtins.splitstring(GetBroadcastConfiguration(zone), " \n")
          )
        end
      end

      Builtins.y2milestone("Current conf: %1", current_conf)

      Yast.import "SuSEFirewallServices" # lazy import due to circular dependencies

      Builtins.foreach(GetKnownFirewallZones()) do |zone|
        Builtins.foreach(SuSEFirewallServices.OLD_SERVICES) do |old_service_id, old_service_def|
          Builtins.y2milestone("Checking %1 in %2 zone", old_service_id, zone)
          if Ops.get_list(old_service_def, "tcp_ports", []) != [] &&
              ArePortsOrServicesAllowed(
                Ops.get_list(old_service_def, "tcp_ports", []),
                "TCP",
                zone,
                true
              ) != true
            next
          end
          if Ops.get_list(old_service_def, "udp_ports", []) != [] &&
              ArePortsOrServicesAllowed(
                Ops.get_list(old_service_def, "udp_ports", []),
                "UDP",
                zone,
                true
              ) != true
            next
          end
          if Ops.get_list(old_service_def, "rpc_ports", []) != [] &&
              ArePortsOrServicesAllowed(
                Ops.get_list(old_service_def, "rpc_ports", []),
                "RPC",
                zone,
                false
              ) != true
            next
          end
          if Ops.get_list(old_service_def, "ip_protocols", []) != [] &&
              ArePortsOrServicesAllowed(
                Ops.get_list(old_service_def, "ip_protocols", []),
                "IP",
                zone,
                false
              ) != true
            next
          end
          if Ops.get_list(old_service_def, "broadcast_ports", []) != [] &&
              IsBroadcastAllowed(
                Ops.get_list(old_service_def, "broadcast_ports", []),
                zone
              ) != true
            next
          end
          if Ops.get_list(old_service_def, "convert_to", []) == []
            Builtins.y2milestone(
              "Service %1 supported, but it doesn't have any replacement",
              old_service_id
            )
            next
          end
          replaced = false
          Builtins.foreach(Ops.get_list(old_service_def, "convert_to", [])) do |replacement|
            if SuSEFirewallServices.IsKnownService(replacement)
              Builtins.y2milestone(
                "Old service %1 matches %2",
                old_service_id,
                replacement
              )
              RemoveOldAllowedServiceFromZone(old_service_def, zone)
              SetServicesForZones([replacement], [zone], true)
              replaced = true
              raise Break
            end
          end
          if !replaced
            Builtins.y2warning(
              "Old service %1 matches %2 but none are installed",
              old_service_id,
              Ops.get_list(old_service_def, "convert_to", [])
            )
          end
        end
      end

      Builtins.y2milestone("Converting done")
      @already_converted = true

      nil
    end

    # Local function allows ports for requested protocol and zone.
    #
    # @param [Array<string>] add_ports ports to be added
    # @param [String] protocol
    # @param [String] zone
    def AddAllowedPortsOrServices(add_ports, protocol, zone)
      add_ports = deep_copy(add_ports)
      if Ops.less_than(Builtins.size(add_ports), 1)
        Builtins.y2warning(
          "Undefined list of %1 services/ports for service",
          protocol
        )
        return
      end

      SetModified()

      # all allowed ports
      allowed_services = GetAllowedServicesForZoneProto(zone, protocol)

      allowed_services = Convert.convert(
        Builtins.union(allowed_services, add_ports),
        from: "list",
        to:   "list <string>"
      )
      allowed_services = PortRanges.FlattenServices(allowed_services, protocol)

      SetAllowedServicesForZoneProto(allowed_services, zone, protocol)

      nil
    end

    # Sets whether ports need to be open already during boot
    # bsc#916376
    #
    # @param [Boolean] new_state
    # @return [Boolean] current state
    def full_init_on_boot(new_state)
      @SETTINGS["FW_BOOT_FULL_INIT"] = new_state ? "yes" : "no"
      SetModified()
      @SETTINGS["FW_BOOT_FULL_INIT"] == "yes"
    end

    publish variable: :FIREWALL_PACKAGE, type: "const string"
    publish variable: :configuration_has_been_read, type: "boolean", private: true
    publish variable: :special_all_interface_string, type: "string"
    publish variable: :max_port_number, type: "integer"
    publish variable: :special_all_interface_zone, type: "string"
    publish variable: :SETTINGS, type: "map <string, any>", private: true
    publish variable: :modified, type: "boolean", private: true
    publish variable: :is_running, type: "boolean", private: true
    publish variable: :DEFAULT_SETTINGS, type: "map <string, string>", private: true
    publish variable: :verbose_level, type: "integer", private: true
    publish variable: :known_firewall_zones, type: "list <string>", private: true
    publish variable: :zone_names, type: "map <string, string>", private: true
    publish variable: :int_zone_shortname, type: "string", private: true
    publish variable: :supported_protocols, type: "list <string>", private: true
    publish variable: :service_defined_by, type: "list <string>", private: true
    publish variable: :allowed_conflict_services, type: "map <string, list <string>>", private: true
    publish variable: :firewall_service, type: "string", private: true
    publish variable: :SuSEFirewall_variables, type: "list <string>", private: true
    publish variable: :broadcast_related_module, type: "string", private: true
    publish function: :SetModified, type: "void ()"
    publish function: :ResetModified, type: "void ()"
    publish function: :GetKnownFirewallZones, type: "list <string> ()"
    publish function: :IsServiceSupportedInZone, type: "boolean (string, string)"
    publish function: :GetSpecialInterfacesInZone, type: "list <string> (string)"
    publish function: :AddSpecialInterfaceIntoZone, type: "void (string, string)"
    publish variable: :report_only_once, type: "list <string>", private: true
    publish function: :ReportOnlyOnce, type: "boolean (string)", private: true
    publish function: :IsAnyNetworkInterfaceSupported, type: "boolean ()"
    publish function: :GetListOfSuSEFirewallVariables, type: "list <string> ()", private: true
    publish function: :IncreaseVerbosity, type: "void ()", private: true
    publish function: :DecreaseVerbosity, type: "void ()", private: true
    publish function: :IsVerbose, type: "boolean ()", private: true
    publish function: :GetDefaultValue, type: "string (string)", private: true
    publish function: :ReadSysconfigSuSEFirewall, type: "void (list <string>)", private: true
    publish function: :ResetSysconfigSuSEFirewall, type: "void (list <string>)", private: true
    publish function: :WriteSysconfigSuSEFirewall, type: "boolean (list <string>)", private: true
    publish function: :IsSupportedProtocol, type: "boolean (string)", private: true
    publish function: :IsKnownZone, type: "boolean (string)", private: true
    publish function: :GetZoneConfigurationString, type: "string (string)", private: true
    publish function: :GetConfigurationStringZone, type: "string (string)", private: true
    publish function: :GetAllowedServicesForZoneProto, type: "list <string> (string, string)", private: true
    publish function: :SetAllowedServicesForZoneProto, type: "void (list <string>, string, string)", private: true
    publish function: :GetBroadcastConfiguration, type: "string (string)", private: true
    publish function: :SetBroadcastConfiguration, type: "void (string, string)", private: true
    publish function: :GetBroadcastAllowedPorts, type: "map <string, list <string>> ()"
    publish function: :SetBroadcastAllowedPorts, type: "void (map <string, list <string>>)"
    publish function: :IsBroadcastAllowed, type: "boolean (list <string>, string)", private: true
    publish function: :RemoveAllowedBroadcast, type: "void (list <string>, string)", private: true
    publish function: :AddAllowedBroadcast, type: "void (list <string>, string)", private: true
    publish function: :RemoveServiceFromProtocolZone, type: "boolean (string, string, string)", private: true
    publish function: :RemoveAllowedPortsOrServices, type: "void (list <string>, string, string, boolean)", private: true
    publish function: :AddAllowedPortsOrServices, type: "void (list <string>, string, string)", private: true
    publish function: :RemoveServiceDefinedByPackageFromZone, type: "void (string, string)", private: true
    publish function: :AddServiceDefinedByPackageIntoZone, type: "void (string, string)", private: true
    publish function: :RemoveServiceSupportFromZone, type: "void (string, string)", private: true
    publish function: :AddServiceSupportIntoZone, type: "void (string, string)", private: true
    publish variable: :check_and_install_package, type: "boolean", private: true
    publish function: :SetInstallPackagesIfMissing, type: "void (boolean)"
    publish function: :SuSEFirewallIsInstalled, type: "boolean ()"
    publish variable: :fw_service_can_be_configured, type: "boolean", private: true
    publish function: :GetModified, type: "boolean ()"
    publish function: :ResetReadFlag, type: "void ()"
    publish function: :GetZoneFullName, type: "string (string)"
    publish function: :SetProtectFromInternalZone, type: "void (boolean)"
    publish function: :GetProtectFromInternalZone, type: "boolean ()"
    publish function: :SetSupportRoute, type: "void (boolean)"
    publish function: :GetSupportRoute, type: "boolean ()"
    publish function: :SetTrustIPsecAs, type: "void (string)"
    publish function: :GetTrustIPsecAs, type: "string ()"
    publish function: :GetStartService, type: "boolean ()"
    publish function: :SetStartService, type: "void (boolean)"
    publish function: :GetEnableService, type: "boolean ()"
    publish function: :SetEnableService, type: "void (boolean)"
    publish function: :StartServices, type: "boolean ()"
    publish function: :StopServices, type: "boolean ()"
    publish function: :EnableServices, type: "boolean ()"
    publish function: :DisableServices, type: "boolean ()"
    publish function: :IsEnabled, type: "boolean ()"
    publish function: :IsStarted, type: "boolean ()"
    publish function: :Export, type: "map <string, any> ()"
    publish function: :Import, type: "void (map <string, any>)"
    publish function: :read_and_import, type: "void (map <string, any>)"
    publish function: :IsInterfaceInZone, type: "boolean (string, string)"
    publish function: :GetZoneOfInterface, type: "string (string)"
    publish function: :GetZonesOfInterfaces, type: "list <string> (list <string>)"
    publish function: :GetInterfacesInZoneSupportingAnyFeature, type: "list <string> (string)"
    publish function: :GetZonesOfInterfacesWithAnyFeatureSupported, type: "list <string> (list <string>)"
    publish function: :GetAllKnownInterfaces, type: "list <map <string, string>> ()"
    publish function: :GetAllNonDialUpInterfaces, type: "list <string> ()"
    publish function: :GetAllDialUpInterfaces, type: "list <string> ()"
    publish function: :GetListOfKnownInterfaces, type: "list <string> ()"
    publish function: :RemoveInterfaceFromZone, type: "void (string, string)"
    publish function: :AddInterfaceIntoZone, type: "void (string, string)"
    publish function: :GetInterfacesInZone, type: "list <string> (string)"
    publish function: :GetFirewallInterfaces, type: "list <string> ()"
    publish function: :InterfacesSupportedByAnyFeature, type: "list <string> (string)"
    publish function: :ArePortsOrServicesAllowed, type: "boolean (list <string>, string, string, boolean)", private: true
    publish function: :HaveService, type: "boolean (string, string, string)"
    publish function: :AddService, type: "boolean (string, string, string)"
    publish function: :RemoveService, type: "boolean (string, string, string)"
    publish function: :IsServiceDefinedByPackageSupportedInZone, type: "boolean (string, string)", private: true
    publish function: :GetServicesInZones, type: "map <string, map <string, boolean>> (list <string>)"
    publish function: :GetServices, type: "map <string, map <string, boolean>> (list <string>)"
    publish function: :SetServicesForZones, type: "boolean (list <string>, list <string>, boolean)"
    publish function: :SetServices, type: "boolean (list <string>, list <string>, boolean)"
    publish function: :ReadDefaultConfiguration, type: "void ()", private: true
    publish function: :ReadCurrentConfiguration, type: "void ()", private: true
    publish variable: :converted_to_services_dbp_file, type: "string", private: true
    publish variable: :already_converted, type: "boolean", private: true
    publish function: :ConvertToServicesDefinedByPackages, type: "void ()"
    publish function: :FillUpEmptyConfig, type: "void ()", private: true
    publish function: :Read, type: "boolean ()"
    publish function: :AnyRPCServiceInConfiguration, type: "boolean ()", private: true
    publish function: :ActivateConfiguration, type: "boolean ()"
    publish function: :WriteConfiguration, type: "boolean ()"
    publish function: :CheckKernelModules, type: "void ()", private: true
    publish function: :WriteOnly, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :SaveAndRestartService, type: "boolean ()"
    publish function: :GetAdditionalServices, type: "list <string> (string, string)"
    publish function: :SetAdditionalServices, type: "void (string, string, list <string>)"
    publish function: :IsOtherFirewallRunning, type: "boolean ()"
    publish function: :GetFirewallInterfacesMap, type: "map <string, list <string>> ()"
    publish function: :RemoveSpecialInterfaceFromZone, type: "void (string, string)"
    publish function: :GetMasquerade, type: "boolean ()"
    publish function: :SetMasquerade, type: "void (boolean)"
    publish function: :GetListOfForwardsIntoMasquerade, type: "list <map <string, string>> ()"
    publish function: :RemoveForwardIntoMasqueradeRule, type: "void (integer)"
    publish function: :AddForwardIntoMasqueradeRule, type: "void (string, string, string, string, string, string)"
    publish function: :GetLoggingSettings, type: "string (string)"
    publish function: :SetLoggingSettings, type: "void (string, string)"
    publish function: :GetIgnoreLoggingBroadcast, type: "string (string)"
    publish function: :SetIgnoreLoggingBroadcast, type: "void (string, string)"
    publish function: :AddXenSupport, type: "void ()"
    publish function: :GetAcceptExpertRules, type: "string (string)"
    publish function: :SetAcceptExpertRules, type: "boolean (string, string)"
    publish function: :GetFirewallKernelModules, type: "list <string> ()"
    publish function: :SetFirewallKernelModules, type: "void (list <string>)"
    publish variable: :protocol_translations, type: "map <string, string>", private: true
    publish function: :GetProtocolTranslatedName, type: "string (string)"
    publish function: :GetServicesAcceptRelated, type: "list <string> (string)"
    publish function: :SetServicesAcceptRelated, type: "void (string, list <string>)"
    publish function: :RemoveOldAllowedServiceFromZone, type: "void (map <string, any>, string)", private: true
    publish variable: :needed_packages_installed, type: "boolean"
    publish function: :full_init_on_boot, type: "boolean (boolean)"
  end
end
