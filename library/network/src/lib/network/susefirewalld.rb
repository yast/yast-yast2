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
# Package: SuSEFirewall configuration
# Summary: Interface manipulation of /etc/sysconfig/SuSEFirewall
# Authors: Lukas Ocilka <locilka@suse.cz
#
# $Id$
#
# Module for handling SuSEfirewall2
require "yast"
require "network/firewalld"
require "network/susefirewall"

module Yast
  # ----------------------------------------------------------------------------
  # SuSEFirewalld Class. Trying to provide relevent pieces of SF2 functionality via
  # firewalld.
  class SuSEFirewalldClass < SuSEFirewallClass
    include Firewalld
    require "set"
    attr_reader :special_all_interface_zone

    # Valid attributes for firewalld zones
    # :interfaces = [Array<String>]
    # :masquerade = Boolean
    # :modified   = [Set<Symbols>]
    # :ports      = [Array<String>]
    # :protocols  = [Array<String>]
    # :services   = [Array<String>]
    ZONE_ATTRIBUTES = [:interfaces, :masquerade, :modified, :ports, :protocols, :services].freeze
    # {enable,start}_firewall are "inherited" from SF2 so we can't use symbols
    # there without having to change all the SF2 callers.
    KEY_SETTINGS = ["enable_firewall", "logging", "routing", "start_firewall"].freeze

    EMPTY_ZONE = {
      interfaces: [],
      masquerade: false,
      modified:   Set.new,
      ports:      [],
      protocols:  [],
      services:   []
    }.freeze

    # We need that for the tests. Nothing else should access the API
    # directly
    def api
      @fwd_api
    end

    def initialize
      # firewalld API interface.
      @fwd_api = FirewalldAPI.create
      # firewalld service
      @firewall_service = "firewalld"
      # firewalld package
      @FIREWALL_PACKAGE = "firewalld"
      # flag to indicate that FirewallD configuration has been read
      @configuration_has_been_read = false
      # firewall settings map
      @SETTINGS = {}
      # list of known firewall zones
      @known_firewall_zones = ["block", "dmz", "drop", "external", "home",
                               "internal", "public", "trusted", "work"]
      # map defines zone name for all known firewall zones
      @zone_names = {
        # TRANSLATORS: Firewall zone name - used in combo box or dialog title
        "block"    => _(
          "Block Zone"
        ),
        "dmz"      => _(
          "Demilitarized Zone"
        ),
        "drop"     => _(
          "Drop Zone"
        ),
        "external" => _(
          "External Zone"
        ),
        "home"     => _(
          "Home Zone"
        ),
        "internal" => _(
          "Internal Zone"
        ),
        "public"   => _(
          "Public Zone"
        ),
        "trusted"  => _(
          "Trusted Zone"
        ),
        "work"     => _(
          "Work Zone"
        )
      }

      # Zone which works with the special_all_interface_string string. In our case,
      # we don't want to deal with this just yet. FIXME
      @special_all_interface_zone = ""

      # Initialize the @SETTINGS hash
      KEY_SETTINGS.each { |x| @SETTINGS[x] = nil }
      GetKnownFirewallZones().each { |zone| @SETTINGS[zone] = deep_copy(EMPTY_ZONE) }

      # Are needed packages installed?
      @needed_packages_installed = nil

      # bnc #388773
      # By default needed packages are just checked, not installed
      @check_and_install_package = false

      # internal zone identification - useful for protect-from-internal
      @int_zone_shortname = "internal"

      # list of protocols supported in firewall, use only upper-cases
      @supported_protocols = ["TCP", "UDP", "IP"]
    end

    # Function which attempts to convert a sf2_service name to a firewalld
    # equivalent.
    def sf2_to_firewalld_service(service)
      # First, let's strip off 'service:' from service name if present.
      tmp_service = if service.include?("service:")
                      service.partition(":")[2]
      else
                      service
      end

      sf2_to_firewalld_map = {
        # netbios is covered in the samba service file
        "netbios-server"    => ["samba"],
        "nfs-client"        => ["nfs"],
        "nfs-kernel-server" => ["mountd", "nfs", "rpc-bind"],
        "samba-server"      => ["samba"],
        "sshd"              => ["ssh"]
      }

      if sf2_to_firewalld_map.key?(tmp_service)
        sf2_to_firewalld_map[tmp_service]
      else
        [tmp_service]
      end
    end

    # Function for getting exported SuSEFirewall configuration
    #
    # @return	[Hash{String => Object}] with configuration
    def Export
      deep_copy(@SETTINGS)
    end

    # Function for setting SuSEFirewall configuration from input
    #
    # @param	map <string, any> with configuration
    def Import(import_settings)
      Read()
      import_settings = deep_copy(import_settings)
      # Sanitize it
      import_settings.keys.each do |k|
        if !GetKnownFirewallZones().include?(k) && !KEY_SETTINGS.include?(k)
          Builtins.y2warning("Removing invalid key: %1 from imported settings", k)
          import_settings.delete(k)
        elsif import_settings[k].is_a?(Hash)
          import_settings[k].keys.each do |v|
            if !ZONE_ATTRIBUTES.include?(v)
              Builtins.y2warning("Removing invalid value: %1 from key %2", v, k)
              import_settings[k].delete(v)
            end
          end
        end
      end

      # Ruby's merge will probably not work since we have nested hashes
      @SETTINGS.keys.each do |key|
        next unless import_settings.include?(key)
        if import_settings[key].class == Hash
          # Merge them
          @SETTINGS[key].merge!(import_settings[key])
        else
          @SETTINGS[key] = import_settings[key]
        end
      end

      # Merge missing attributes
      @SETTINGS.keys.each do |key|
        next unless GetKnownFirewallZones().include?(key)
        # is this a zone?
        @SETTINGS[key] = EMPTY_ZONE.merge(@SETTINGS[key])
        # Everything may have been modified
        @SETTINGS[key][:modified] = [:interfaces, :masquerade, :ports, :protocols, :services]
      end

      # Tests mock the read method so read the NetworkInterface list again
      NetworkInterfaces.Read if !@configuration_has_been_read

      SetModified()

      nil
    end

    def sf2_to_firewalld_zone(zone)
      sf2_to_firewalld_map = {
        "INT" => "trusted",
        "EXT" => "external",
        "DMZ" => "dmz"
      }

      sf2_to_firewalld_map[zone] || zone
    end

    def Read
      # Do not read it again and again
      # to avoid overwritting live configuration.
      if @configuration_has_been_read
        Builtins.y2milestone(
          "FirewallD configuration has been read already."
        )
        return true
      end

      ReadCurrentConfiguration()

      Builtins.y2milestone(
        "Firewall configuration has been read: %1.",
        @SETTINGS
      )
      # to read configuration only once
      @configuration_has_been_read = true

      # Always call NI::Read, bnc #396646
      NetworkInterfaces.Read
    end

    def ReadCurrentConfiguration
      # We need to start the service before we query the firewalld rules
      StartServices() unless IsStarted()
      # Get all the information from zones and load them to @SETTINGS["zones"]
      # The following may seem somewhat complicated or fragile but it is more
      # efficient to only invoke a single firewall-cmd command instead of
      # iterating over the zones and then using all the different
      # firewall-cmd commands to get service, port, masquerade etc
      # information from them.
      all_zone_info = @fwd_api.list_all_zones
      # Drop empty lines
      all_zone_info.reject!(&:empty?)
      # And now build the hash
      zone = nil
      all_zone_info.each do |e|
        # is it a zone?
        z = e.split("\s")[0]
        if GetKnownFirewallZones().include?(z)
          zone = z
          next
        end
        if ZONE_ATTRIBUTES.any? { |w| e.include?(w.to_s) }
          attrs = e.split(":\s")
          attr = attrs[0].lstrip.to_sym
          # do not bother if empty
          next if attrs[1].nil?
          vals = attrs[1].split("\s")
          # Fix up for masquerade
          if attr == :masquerade
            set_to_zone_attr(zone, attr, (vals == "no" ? false : true))
          else
            vals.each { |x| add_to_zone_attr(zone, attr, x) }
          end
        end
      end

      @SETTINGS["enable_firewall"] = IsEnabled()
      @SETTINGS["start_firewall"] = IsStarted()
      @SETTINGS["logging"] = @fwd_api.log_denied_packets

      true
    end

    def WriteConfiguration
      # just disabled
      return true if !SuSEFirewallIsInstalled()

      # Can't do anything if service is not running
      return false if !IsStarted()

      return false if !GetModified()

      Builtins.y2milestone(
        "Firewall configuration has been changed. Writing: %1.",
        @SETTINGS
      )
      # FIXME: Need to improve that to not re-write everything
      begin
        # Set logging
        if !@SETTINGS["logging"].nil?
          @fwd_api.log_denied_packets(@SETTINGS["logging"]) if !@fwd_api.log_denied_packets?(@SETTINGS["logging"])
        end
        # Configure the zones
        GetKnownFirewallZones().each do |zone|
          if zone_attr_modified?(zone)
            Builtins.y2milestone("zone=#{zone} hasn't been modified. Skipping...")
            next
          end

          write_zone_masquerade(zone)
          write_zone_interfaces(zone)
          write_zone_services(zone)
          write_zone_ports(zone)
          write_zone_protocols(zone)

          # Configuration is now live. Move on
          ResetModified()
        end

      rescue FirewallCMDError
        Builtins.y2error("firewall-cmd failed")
        raise
      end

      # FIXME: perhaps "== true" can be dropped since this should
      # always be boolean?
      if !@SETTINGS["enable_firewall"].nil?
        if @SETTINGS["enable_firewall"] == true
          Builtins.y2milestone("Enabling firewall services")
          return false if !EnableServices()
        else
          Builtins.y2milestone("Disabling firewall services")
          return false if !DisableServices()
        end
      end

      true
    end

    # In SF2, it's used to write configuration, but not activate. For firewalld
    # this is simply here to satisfy callers, like modules/Nfs.rb.
    # @return true
    def WriteOnly
      # This does not check if firewalld is running
      return false if !WriteConfiguration()
    end

    # Function which starts/stops firewall. Then firewall is started immediately
    # when firewall is wanted to be started: SetStartService(boolean). FirewallD
    # needs to be reloaded instead of doing a full-blown restart to get the new
    # configuration up and running.
    #
    # @return	[Boolean] if successful
    def ActivateConfiguration
      # starting firewall during second stage can cause deadlock in systemd - bnc#798620
      # Moreover, it is not needed. Firewall gets started via dependency on multi-user.target
      # when second stage is over.
      if Mode.installation
        Builtins.y2milestone("Do not touch firewall services during installation")

        return true
      end

      if GetStartService()
        # Not started - start it
        if !IsStarted()
          Builtins.y2milestone("Starting firewall services")
          return StartServices()
          # Started - restart it
        else
          Builtins.y2milestone("Firewall has been started already")
          # Make it real
          @fwd_api.reload
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

    def Write
      # Make the firewall changes permanent.
      return false if !WriteConfiguration()
      return false if !ActivateConfiguration()

      true
    end

    # Function returns if the interface is in zone.
    #
    # @param [String] interface
    # @param	string firewall zone
    # @return	[Boolean] is in zone
    #
    # @example IsInterfaceInZone ("eth-id-01:11:DA:9C:8A:2F", "INT") -> false
    def IsInterfaceInZone(interface, zone)
      interfaces = get_zone_attr(zone, :interfaces)
      interfaces.include?(interface)
    end

    # Function returns the firewall zone of interface, nil if no zone includes
    # the interface. Firewalld does not allow an interface to be in more than
    # one zone, so no error detection for this case is needed.
    #
    # @param string interface
    # @return string zone, or nil
    def GetZoneOfInterface(interface)
      GetKnownFirewallZones().each do |zone|
        return zone if IsInterfaceInZone(interface, zone)
      end

      nil
    end

    # Function returns list of zones of requested interfaces.
    # Special string 'any' in 'EXT' zone is supported.
    #
    # @param [Array<String>] interfaces
    # @return	[Array<String>] firewall zones
    #
    # @example
    #	GetZonesOfInterfaces (["eth1","eth4"]) -> ["EXT"]
    def GetZonesOfInterfacesWithAnyFeatureSupported(interfaces)
      interfaces = deep_copy(interfaces)
      zones = []
      interfaces.each { |interface| zones << GetZoneOfInterface(interface) }
      zones
    end

    # Function returns whether the feature 'any' network interface is supported.
    # This is a SF2 specific construct. For firewalld, we simply return false.
    # We may decide to change this in the future.
    #
    # @return boolean false
    def IsAnyNetworkInterfaceSupported
      false
    end

    # Function returns true if service is supported (allowed) in zone. Service must be defined
    # already be defined.
    #
    # @see YCP Module SuSEFirewallServices
    # @param [String] service id
    # @param [String] zone
    # @return	[Boolean] if supported
    #
    # @example
    #	// All ports defined by dns-server service in SuSEFirewallServices module
    #	// are enabled in the respective zone
    #	IsServiceSupportedInZone ("dns-server", "external") -> true
    def IsServiceSupportedInZone(service, zone)
      return nil if !IsKnownZone(zone)

      # We may have more than one FirewallD service per SF2 service
      sf2_to_firewalld_service(service).each do |s|
        return false if !in_zone_attr?(zone, :services, s)
      end

      true
    end

    # Function returns if firewall is protected from internal zone. For
    # firewalld, we just return true since the internal zone is treated
    # like any other zone.
    #
    # @return	[Boolean] if protected from internal
    def GetProtectFromInternalZone
      true
    end

    # Function returns list of known interfaces in requested zone.
    # Special strings like 'any' or 'auto' and unknown interfaces are removed from list.
    #
    # @param [String] zone
    # @return	[Array<String>] of interfaces
    # @example GetInterfacesInZone ("external") -> ["eth4", "eth5"]
    def GetInterfacesInZone(zone)
      return [] unless IsKnownZone(zone)
      known_interfaces_now = GetListOfKnownInterfaces()
      get_zone_attr(zone, :interfaces).find_all { |i| known_interfaces_now.include?(i) }
    end

    # Function removes interface from defined zone.
    #
    # @param [String] interface
    # @param [String] zone
    # @example RemoveInterfaceFromZone ("modem0", "EXT")
    def RemoveInterfaceFromZone(interface, zone)
      return nil if !IsKnownZone(zone)

      SetModified()

      Builtins.y2milestone(
        "Removing interface '%1' from '%2' zone.",
        interface,
        zone
      )

      del_from_zone_attr(zone, :interfaces, interface)
      add_zone_modified(zone, :interfaces)

      nil
    end

    # Functions adds interface into defined zone.
    # All appearances of interface in other zones are removed.
    #
    # @param [String] interface
    # @param [String] zone
    # @example AddInterfaceIntoZone ("eth5", "DMZ")
    def AddInterfaceIntoZone(interface, zone)
      return nil if !IsKnownZone(zone)

      SetModified()

      current_zone = GetZoneOfInterface(interface)

      # removing all appearances of interface in zones, excepting current_zone==new_zone
      while !current_zone.nil? && current_zone != zone
        # interface is in any zone already, removing it at first
        RemoveInterfaceFromZone(interface, current_zone) if current_zone != zone
        current_zone = GetZoneOfInterface(interface)
      end

      Builtins.y2milestone(
        "Adding interface '%1' into '%2' zone.",
        interface,
        zone
      )

      add_to_zone_attr(zone, :interfaces, interface)
      add_zone_modified(zone, :interfaces)

      nil
    end

    # Function returns list of known interfaces in requested zone.
    # In the firewalld case, we don't support the special 'any' string.
    # Thus, interfaces not in a zone will not be included.
    #
    # @param [String] zone
    # @return	[Array<String>] of interfaces
    def GetInterfacesInZoneSupportingAnyFeature(zone)
      GetInterfacesInZone(zone)
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
      tmp_services = deep_copy(services)
      services = []
      Builtins.foreach(tmp_services) do |service|
        sf2_to_firewalld_service(service).each do |s|
          s = service.include?("service:") ? "service:" + s : s
          services << s
        end
      end
      super(services)
    end

    # Function sets status for several services in several firewall zones.
    #
    # @param	list <string> service ids
    # @param	list <string> firewall zones (EXT|INT|DMZ...)
    # @param	boolean new status of services
    # @return	nil
    #
    # @example
    #	SetServicesForZones (["samba-server", "service:irc-server"], ["DMZ", "EXT"], false);
    #	SetServicesForZones (["samba-server", "service:irc-server"], ["EXT", "DMZ"], true);
    #
    # @see #GetServicesInZones()
    # @see #GetServices()
    def SetServicesForZones(services_ids, firewall_zones, new_status)
      Yast.import "SuSEFirewallServices"

      services_ids = deep_copy(services_ids)
      zones = deep_copy(firewall_zones)

      tmp_services_ids = deep_copy(services_ids)
      services_ids = []
      tmp_services_ids.each do |service|
        sf2_to_firewalld_service(service).each do |s|
          services_ids << s
        end
      end

      # setting for each service
      services_ids.each do |service|
        # Service is not supported by firewalld.
        # We can only do such error checking if backend is running
        if IsStarted() && !@fwd_api.service_supported?(service)
          Builtins.y2error("Undefined service '#{service}'")
          raise(SuSEFirewalServiceNotFound, "Service with name '#{service}' does not exist")
        end
        zones.each do |zone|
          # Add/remove service to/from zone only if zone is not 'trusted',
          # 'blocked' or 'drop'. For these zones there is no need to
          # explicitly add/remove
          # services as all connections are by default accepted.
          next if ["block", "drop", "trusted"].include?(zone)

          # zone must be known one
          if !IsKnownZone(zone)
            Builtins.y2error(
              "Zone '%1' is unknown firewall zone, skipping...",
              zone
            )
            next
          end

          if new_status == true # enable
            Builtins.y2milestone(
              "Adding '%1' into '%2' zone",
              service, zone
            )
            # Only add it if it is not there
            if !in_zone_attr?(zone, :services, service)
              add_to_zone_attr(zone, :services, service)
              SetModified()
              add_zone_modified(zone, :services)
            end
          else # disable
            Builtins.y2milestone(
              "Removing '%1' from '%2' zone",
              service, zone
            )
            del_from_zone_attr(zone, :services, service)
            SetModified()
            add_zone_modified(zone, :services)
          end
        end
      end

      nil
    end

    # Function returns actual state of Masquerading support.
    # In FirewallD, masquerade is enabled per-zone so this
    # function treats the 'internal' zone as the default
    # zone if no zone is given as parameter.
    #
    # @param    zone [String] zone to get masqurade status from (default: internal)
    # @return	[Boolean] if supported
    def GetMasquerade(zone = "internal")
      if !IsKnownZone(zone)
        Builtins.y2error("zone %1 is not valid", zone)
        return nil
      end
      get_zone_attr(zone, :masquerade)
    end

    # Function sets Masquerade support.
    #
    # @param  enable [Boolean] Enable or Disable masquerade
    # @param  zone [String] Zone to enable masquerade on.
    # @return nil
    def SetMasquerade(enable, zone = "internal")
      if !IsKnownZone(zone)
        Builtins.y2error("zone %1 is not valid", zone)
        return nil
      end
      SetModified()
      set_to_zone_attr(zone, :masquerade, enable)
      add_zone_modified(zone, :masquerade)

      nil
    end

    # Function returns list of special strings like 'any' or 'auto' and unknown interfaces.
    # This function is only valid for SF2. For firewalld, we return an empty array.
    #
    # @param [String] zone
    # @return	[Array<String>] special strings or unknown interfaces
    #
    # @example
    #	GetSpecialInterfacesInZone("EXT") -> ["any", "unknown-1", "wrong-3"]
    def GetSpecialInterfacesInZone(zone)
      known_interfaces_now = GetListOfKnownInterfaces()
      get_zone_attr(zone, :interfaces).reject { |i| known_interfaces_now.include?(i) }
    end

    # Function removes special string from defined zone. For firewalld we
    # return nil.
    #
    # @param [String] interface
    # @param [String] zone
    def RemoveSpecialInterfaceFromZone(interface, zone)
      RemoveInterfaceFromZone(interface, zone)
    end

    # Functions adds special string into defined zone. For firewalld we
    # return nil.
    #
    # @param [String] interface
    # @param [String] zone
    def AddSpecialInterfaceIntoZone(interface, zone)
      AddInterfaceIntoZone(interface, zone)
    end

    # Function returns actual state of logging.
    # @ note There is no 1-1 matching between SF2 and FirewallD when
    # @ note it comes to logging. We need to be backwards compatible and
    # @ note so we use the following conventions:
    # @ note ACCEPT -> FirewallD can't log accepted packets so we always return
    # @ note false.
    # @ note DROP -> We map "all" to "ALL", "broadcast, multicast or unicast"
    # @ note to "CRIT" and "off" to "NONE".
    # @ note As a result of which, this method has little value in FirewallD
    # @param [String] rule definition 'ACCEPT' or 'DROP'
    # @return	[String] 'ALL' or 'NONE'
    #
    def GetLoggingSettings(rule)
      return false if rule == "ACCEPT"
      if rule == "DROP"
        drop_rule = @SETTINGS["logging"]
        case drop_rule
        when "off"
          return "NONE"
        when "broadcast", "multicast", "unicast"
          return "CRIT"
        when "all"
          return "ALL"
        end
      else
        Builtins.y2error("Possible rules are only 'ACCEPT' or 'DROP'")
      end
    end

    # Function sets state of logging.
    # @note Similar restrictions to GetLoggingSettings apply
    # @param [String] rule definition 'ACCEPT' or 'DROP'
    # @param	string new logging state 'ALL', 'CRIT', or 'NONE'
    def SetLoggingSettings(rule, state)
      return nil if rule == "ACCEPT"
      if rule == "DROP"
        drop_rule = state.downcase
        case drop_rule
        when "none"
          @SETTINGS["logging"] = "off"
        when "crit"
          # Choosing unicast since it's likely to be the most common case
          @SETTINGS["logging"] = "unicast"
        when "all"
          @SETTINGS["logging"] = "all"
        end
      else
        Builtins.y2error("Possible rules are only 'ACCEPT' or 'DROP'")
      end

      SetModified()

      nil
    end

    # Function returns yes/no - ingoring broadcast for zone
    #
    # @param [String] unused
    # @return	[String] "yes" or "no"
    #
    # @example
    #	// Does not log ignored broadcast packets
    #	GetIgnoreLoggingBroadcast () -> "yes"
    def GetIgnoreLoggingBroadcast(_zone)
      return "no" if @SETTINGS["logging"] == "broadcast"
      "yes"
    end

    # Function sets yes/no - ingoring broadcast for zone
    # @note Since Firewalld only accepts a single packet type to log,
    # @note we simply disable logging if broadcast logging is not desirable.
    # @note If you used SetIgnoreLoggingBroadcast is your code, make sure you
    # @note use SetLoggingSettings afterwards to enable the type of logging you
    # @note want.
    #
    # @param [String] unused
    # @param	string ignore 'yes' or 'no'
    #
    # @example
    #	// Do not log broadcast packetes from DMZ
    #	SetIgnoreLoggingBroadcast ("DMZ", "yes")
    def SetIgnoreLoggingBroadcast(_zone, bcast)
      bcast = bcast.casecmp("no").zero? ? "broadcast" : "off"

      return nil if @SETTINGS["logging"] == bcast

      SetModified()

      @SETTINGS["logging"] = bcast.downcase

      nil
    end

    # Function returns list of allowed ports for zone and protocol
    #
    # @param [String] zone
    # @param [String] protocol
    # @return	[Array<String>] of allowed ports
    def GetAllowedServicesForZoneProto(zone, protocol)
      Yast.import "SuSEFirewallServices"

      result = []
      protocol = protocol.downcase

      get_zone_attr(zone, :ports).each do |p|
        port_proto = p.split("/")
        result << port_proto[0] if port_proto[1] == protocol
      end
      result = get_zone_attr(zone, :protocols) if protocol == "ip"
      # We return the name of service instead of its ports
      get_zone_attr(zone, :services).each do |s| # to be SF2 compatible.
        if protocol == "tcp"
          result << s if !SuSEFirewallServices.GetNeededTCPPorts(s).empty?
        elsif protocol == "udp"
          result << s if !SuSEFirewallServices.GetNeededUDPPorts(s).empty?
        end
      end
      # FIXME: Is this really needed?
      result.flatten!

      deep_copy(result)
    end

    # This powerful function returns list of services/ports which are
    # not assigned to any fully-supported known-services.
    # This function doesn't check for services defined by packages.
    # They are listed by a different way.
    #
    # @return	[Array<String>] of additional (unassigned) services
    #
    # @example
    #	GetAdditionalServices("TCP", "EXT") -> ["53", "128"]
    def GetAdditionalServices(protocol, zone)
      protocol = protocol.upcase

      if !IsSupportedProtocol(protocol.upcase)
        Builtins.y2error("Unknown protocol '%1'", protocol)
        return nil
      end
      if !IsKnownZone(zone)
        Builtins.y2error("Unknown zone '%1'", zone)
        return nil
      end

      # all ports or services allowed in zone for protocol
      all_allowed_services = GetAllowedServicesForZoneProto(zone, protocol)

      # And now drop the known ones
      all_allowed_services -= SuSEFirewallServices.GetSupportedServices().keys

      # well, actually it returns list of services not-assigned to any well-known service
      deep_copy(all_allowed_services)
    end

    # Function sets list of services as allowed ports for zone and protocol
    #
    # @param	list <string> of allowed ports/services
    # @param [String] zone
    # @param [String] protocol
    def SetAllowedServicesForZoneProto(allowed_services, zone, protocol)
      allowed_services = deep_copy(allowed_services)

      SetModified()

      protocol = protocol.downcase

      # allowed_services can contain both services and port definitions so the
      # first step is to split them up
      services, ports = sanitize_services_and_ports(allowed_services, protocol)

      # First we drop existing services and ports.
      delete_ports_with_protocol_from_zone(protocol, zone)
      delete_services_with_protocol_from_zone(protocol, zone)

      # And now add the new ports and services
      set_ports_with_protocol_to_zone(ports, protocol, zone)
      set_services_to_zone(services, zone)

      nil
    end

    # Local function removes ports and their aliases (if check_for_aliases is true), for
    # requested protocol and zone.
    #
    # @param remove_ports [Array<String>] ports to be removed
    # @param protocol [String] Protocol
    # @param zone [String] Zone
    # @param _check_for_aliases [Boolean] unused
    # @param	boolean check for port-aliases
    def RemoveAllowedPortsOrServices(remove_ports, protocol, zone, _check_for_aliases)
      remove_ports = deep_copy(remove_ports)
      if Ops.less_than(Builtins.size(remove_ports), 1)
        Builtins.y2warning(
          "Undefined list of %1 services/ports for service",
          protocol
        )
        return
      end

      SetModified()

      allowed_services = GetAllowedServicesForZoneProto(zone, protocol)
      Builtins.y2debug("RemoveAdditionalServices: currently allowed services for %1_%2 -> %3",
        zone, protocol, allowed_services)
      # and this is what we keep
      allowed_services -= remove_ports
      Builtins.y2debug("RemoveAdditionalServices: new allowed services for %1_%2 -> %3",
        zone, protocol, allowed_services)
      SetAllowedServicesForZoneProto(allowed_services, zone, protocol)
    end

    # Function sets if firewall should support routing.
    #
    # @param	boolean set to support route or not
    # FirewallD does not have something similar to FW_ROUTE
    # so this API call is not applicable to FirewallD
    def SetSupportRoute(set_route)
      @SETTINGS[:routing] = set_route
    end

    # Function returns if firewall supports routing.
    #
    # @return	[Boolean] if route is supported
    # FirewallD does not have something similar to FW_ROUTE
    # so this API call is not applicable to FirewallD
    def GetSupportRoute
      @SETTINGS[:routing]
    end

    def ArePortsOrServicesAllowed(needed_ports, protocol, zone, _check_for_aliases)
      super(needed_ports, protocol, zone, false)
    end

    # Sets whether ports need to be open already during boot
    # bsc#916376. For FirewallD we simply return whatever it
    # was passed as argument since FirewallD always does a
    # full init on boot but we still need to be API compliant.
    #
    # @param [Boolean] new state
    # @return [Boolean] current state
    def full_init_on_boot(new_state)
      new_state
    end

    # Local function allows ports for requested protocol and zone.
    #
    # @param	list <string> ports to be added
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

      SetAllowedServicesForZoneProto(allowed_services, zone, protocol)

      nil
    end

  private

    def set_zone_modified(zone, zone_params)
      # Do nothing if the parameters are not valid
      return nil if zone_params.nil? || \
          !@known_firewall_zones.include?(zone) || \
          !zone_params.is_a?(Array)
      @SETTINGS[zone][:modified] = zone_params.to_set
    end

    def add_zone_modified(zone, zone_param)
      # Do nothing if the parameters are not valid
      return nil if zone_param.nil? || \
          !@known_firewall_zones.include?(zone)
      @SETTINGS[zone][:modified] << zone_param
    end

    def del_zone_modified(zone, zone_param)
      # Do nothing if the parameters are not valid
      return nil if zone_param.nil? || \
          !@known_firewall_zones.include?(zone)
      @SETTINGS[zone][:modified].delete(zone_param)
    end

    def zone_attr_modified?(zone, zone_param = nil)
      return !!@SETTINGS[zone].empty? if zone_param.nil?
      # Do nothing if the parameters are not valid
      return nil if !@known_firewall_zones.include?(zone)
      @SETTINGS[zone][:modified].include?(zone_param)
    end

    def add_to_zone_attr(zone, attr, val)
      return nil if !ZONE_ATTRIBUTES.include?(attr)
      # No sanity checking. callers must be careful
      @SETTINGS[zone][attr] << val
    end

    def set_to_zone_attr(zone, attr, val)
      return nil if !ZONE_ATTRIBUTES.include?(attr)
      # No sanity checking. callers must be careful
      @SETTINGS[zone][attr] = val
    end

    def get_zone_attr(zone, attr)
      @SETTINGS[zone][attr]
    end

    def del_from_zone_attr(zone, attr, val)
      return nil if !ZONE_ATTRIBUTES.include?(attr)
      # No sanity checking. callers must be careful
      @SETTINGS[zone][attr].delete(val)
    end

    def in_zone_attr?(zone, attr, val)
      @SETTINGS[zone][attr].include?(val)
    end

    def write_zone_masquerade(zone)
      return nil if !zone_attr_modified?(zone, :masquerade)

      if get_zone_attr(zone, :masquerade)
        @fwd_api.add_masquerade(zone)
      else
        @fwd_api.remove_masquerade(zone)
      end

      del_zone_modified(zone, :masquerade)
    end

    def write_zone_interfaces(zone)
      return nil if !zone_attr_modified?(zone, :interfaces)
      # These are the ones which should be enabled
      good_interfaces = get_zone_attr(zone, :interfaces)
      # These are the ones which are enabled
      current_interfaces = @fwd_api.list_interfaces(zone)
      # And these are the ones which should be dropped
      to_drop = current_interfaces - good_interfaces
      to_add = good_interfaces - current_interfaces
      Builtins.y2debug("Interfaces: drop -> #{to_drop} add -> #{to_add}")
      to_drop.each { |rmif| @fwd_api.remove_interface(zone, rmif) }
      to_add.each { |gif| @fwd_api.add_interface(zone, gif) }
      del_zone_modified(zone, :interfaces)
    end

    def write_zone_services(zone)
      return nil if !zone_attr_modified?(zone, :services)
      # These are the services which should be enabled
      good_services = get_zone_attr(zone, :services)
      # These are the ones which are enabled
      current_services = @fwd_api.list_services(zone)
      # And these are the ones which should be dropped
      to_drop = current_services - good_services
      to_add = good_services - current_services
      Builtins.y2debug("Services: drop -> #{to_drop} add -> #{to_add}")
      to_drop.each { |rms| @fwd_api.remove_service(zone, rms) }
      to_add.each { |gs| @fwd_api.add_service(zone, gs) }
      del_zone_modified(zone, :services)
    end

    def write_zone_ports(zone)
      return nil if !zone_attr_modified?(zone, :ports)
      # These are the ports which should be enabled
      good_ports = get_zone_attr(zone, :ports)
      # These are the ones which are enabled
      current_ports = @fwd_api.list_ports(zone)
      # And these are the ones which should be dropped
      to_drop = current_ports - good_ports
      to_add = good_ports - current_ports
      Builtins.y2debug("Ports: drop -> #{to_drop} add -> #{to_add}")
      to_drop.each { |rmp| @fwd_api.remove_port(zone, rmp) }
      to_add.each { |gp| @fwd_api.add_port(zone, gp) }
      del_zone_modified(zone, :ports)
    end

    def write_zone_protocols(zone)
      # These are the protocols which should be enabled
      good_protocols = get_zone_attr(zone, :protocols)
      # These are the ones which are enabled
      current_protocols = @fwd_api.list_protocols(zone)
      # And these are the ones which should be dropped
      to_drop = current_protocols - good_protocols
      to_add = good_protocols - current_protocols
      Builtins.y2debug("Protocols: drop -> #{to_drop} add -> #{to_add}")
      to_drop.each { |rmp| @fwd_api.remove_protocol(zone, rmp) }
      to_add.each { |gp| @fwd_api.add_protocol(zone, gp) }
      del_zone_modified(zone, :protocols)
    end

    # Sanitize array of intermixed services and ports and return them as
    # two separate arrays for further processing. Invalid entries will be
    # discarded.
    # @param allowed_services [Array<String>] list of services and ports
    # @param protocol [String] Network Protocol
    # @return [Array<String>][Array<String>] Array of services and Array of ports to add
    def sanitize_services_and_ports(allowed_services, protocol)
      services = []
      ports = []
      allowed_services.each do |s|
        Builtins.y2debug("Examining %1", s)
        # Is it a service?
        if SuSEFirewallServices.GetSupportedServices().keys.include?(s)
          if protocol == "tcp"
            if !SuSEFirewallServices.GetNeededTCPPorts(s).empty?
              Builtins.y2debug("Adding service %1", s)
              services << s
            end
          elsif protocol == "udp"
            if !SuSEFirewallServices.GetNeededUDPPorts(s).empty?
              Builtins.y2debug("Adding service %1", s)
              services << s
            end
          end
        # Is it a port?
        elsif s =~ /\d+((:|-)\d+)?/
          Builtins.y2debug("Adding port %1", s)
          ports << s
        # Is it something else?
        else
          Builtins.y2error("Ignoring unknown service: %1", s)
        end
      end

      # Return the two arrays
      [services, ports]
    end

    # Delete services for given protocol from zone
    # @param zone [String] Zone
    # @param protocol [String] Network Protocol
    # @return nil
    # @note This does not play well with FirewallD. Services may have TCP and UDP
    # @note ports and we can't simply remove part of them. So what we do here is
    # @note to remove the services which have a no other protocol dependecies
    # @note protocol.
    # FIXME: take IP and other protocols into consideration
    def delete_services_with_protocol_from_zone(protocol, zone)
      get_zone_attr(zone, :services).each do |s|
        Builtins.y2debug(
          "Examinining service %2_%1 for removal",
          protocol, s
        )
        if protocol == "udp" &&
            SuSEFirewallServices.GetNeededTCPPorts(s).empty? &&
            !SuSEFirewallServices.GetNeededUDPPorts(s).empty?
          Builtins.y2debug("Removing service %1", s)
          del_from_zone_attr(zone, :services, s)
        elsif protocol == "tcp" &&
            SuSEFirewallServices.GetNeededUDPPorts(s).empty? &&
            !SuSEFirewallServices.GetNeededTCPPorts(s).empty?
          del_from_zone_attr(zone, :services, s)
          Builtins.y2debug("Removing service %1", s)
        else
          Builtins.y2debug("Not removing %1 because it has protocol dependencies", s)
        end
      end
      nil
    end

    # Add services to zone
    # @param services [Array<String>] list of services to add
    # @param zone [String] Zone
    # @return nil
    def set_services_to_zone(services, zone)
      return nil if services.empty?
      # Add the new services! We do not assign since that will override
      # services depending on other protocols!ugh!
      services.each do |s|
        next unless !in_zone_attr?(zone, :services, s)
        Builtins.y2debug("Service %1 will be added to the %2 zone", s, zone)
        add_to_zone_attr(zone, :services, s)
        add_zone_modified(zone, :services)
      end
    end

    # Delete ports for given protocol from zone
    # @param protocol [String] Network Protocol
    # @param zone [String] Zone
    # @return nil
    def delete_ports_with_protocol_from_zone(protocol, zone)
      get_zone_attr(zone, :ports).each do |p|
        port_proto = p.split("/")
        del_from_zone_attr(zone, :ports, p) if port_proto[1] == protocol
        add_zone_modified(zone, :ports)
      end
    end

    # Add ports for given protocol to zone
    # @param ports [Array<String>] list of ports to add
    # @param zone [String] Zone
    # @return nil
    def set_ports_with_protocol_to_zone(ports, protocol, zone)
      return nil if ports.empty?
      ports.each do |p|
        # Convert SF2 port range to FirewallD
        p.sub!(":", "-")
        port_proto = "#{p}/#{protocol}"
        next unless !@SETTINGS[zone][:ports].include?(port_proto)
        # Remove old services and set the new ones.
        Builtins.y2debug(
          "Port %1 will be added to the %2 zone",
          port_proto, zone
        )
        add_to_zone_attr(zone, :ports, port_proto)
        add_zone_modified(zone, :ports)
      end
    end

    publish variable: :firewall_service, type: "string", private: true
    publish variable: :FIREWALL_PACKAGE, type: "const string"
    publish variable: :SETTINGS, type: "map <string, any>", private: true
    publish variable: :known_firewall_zones, type: "list <string>", private: true
    publish variable: :special_all_interface_zone, type: "string"
    publish variable: :zone_names, type: "map <string, string>", private: true
    publish variable: :needed_packages_installed, type: "boolean"
    publish variable: :check_and_install_package, type: "boolean", private: true
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
    publish function: :GetKnownFirewallZones, type: "list <string> ()"
    publish function: :Read, type: "boolean ()"
    publish function: :ActivateConfiguration, type: "boolean ()"
    publish function: :WriteConfiguration, type: "boolean ()"
    publish function: :WriteOnly, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :Export, type: "map <string, any> ()"
    publish function: :Import, type: "void (map <string, any>)"
    publish function: :GetAllKnownInterfaces, type: "list <map <string, string>> ()"
    publish function: :GetZoneOfInterface, type: "string (string)"
    publish function: :IsInterfaceInZone, type: "boolean (string, string)"
    publish function: :GetZonesOfInterfaces, type: "list <string> (list <string>)"
    publish function: :GetZoneFullName, type: "string (string)"
    publish function: :IsAnyNetworkInterfaceSupported, type: "boolean ()"
    publish function: :GetInterfacesInZone, type: "list <string> (string)"
    publish function: :GetInterfacesInZoneSupportingAnyFeature, type: "list <string> (string)"
    publish function: :IsServiceSupportedInZone, type: "boolean (string, string)"
    publish function: :GetServices, type: "map <string, map <string, boolean>> (list <string>)"
    publish function: :GetListOfKnownInterfaces, type: "list <string> ()"
    publish function: :GetServicesInZones, type: "map <string, map <string, boolean>> (list <string>)"
    publish function: :IsKnownZone, type: "boolean (string)", private: true
    publish function: :SetModified, type: "void ()"
    publish function: :ResetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :GetZonesOfInterfacesWithAnyFeatureSupported, type: "list <string> (list <string>)"
    publish function: :SetServices, type: "boolean (list <string>, list <string>, boolean)"
    publish function: :SetServicesForZones, type: "boolean (list <string>, list <string>, boolean)"
    publish function: :SuSEFirewallIsInstalled, type: "boolean ()"
    publish function: :SetInstallPackagesIfMissing, type: "void (boolean)"
    publish function: :SaveAndRestartService, type: "boolean ()"
    publish function: :GetProtectFromInternalZone, type: "boolean ()"
    publish function: :GetMasquerade, type: "boolean (string)"
    publish function: :SetMasquerade, type: "void (boolean, string)"
    publish function: :GetSpecialInterfacesInZone, type: "list <string> (string)"
    publish function: :RemoveSpecialInterfaceFromZone, type: "void (string, string)"
    publish function: :AddSpecialInterfaceIntoZone, type: "void (string, string)"
    publish function: :RemoveInterfaceFromZone, type: "void (string, string)"
    publish function: :AddInterfaceIntoZone, type: "void (string, string)"
    publish function: :GetLoggingSettings, type: "string (string)"
    publish function: :SetLoggingSettings, type: "void (string, string)"
    publish function: :GetIgnoreLoggingBroadcast, type: "string (string)"
    publish function: :SetIgnoreLoggingBroadcast, type: "void (string, string)"
    publish variable: :supported_protocols, type: "list <string>", private: true
    publish function: :IsSupportedProtocol, type: "boolean (string)", private: true
    publish function: :GetAdditionalServices, type: "list <string> (string, string)"
    publish function: :GetAllowedServicesForZoneProto, type: "list <string> (string, string)", private: true
    publish function: :SetAdditionalServices, type: "void (string, string, list <string>)"
    publish function: :RemoveAllowedPortsOrServices, type: "void (list <string>, string, string, boolean)", private: true
    publish function: :AddAllowedPortsOrServices, type: "void (list <string>, string, string)", private: true
    publish function: :IsOtherFirewallRunning, type: "boolean ()"
    publish function: :SetSupportRoute, type: "void (boolean)"
    publish function: :GetSupportRoute, type: "boolean ()"
    publish function: :ArePortsOrServicesAllowed, type: "boolean (list <string>, string, string, boolean)", private: true
    publish function: :HaveService, type: "boolean (string, string, string)"
    publish function: :AddService, type: "boolean (string, string, string)"
    publish function: :RemoveService, type: "boolean (string, string, string)"
    publish function: :AddXenSupport, type: "void ()"
    publish function: :full_init_on_boot, type: "boolean (boolean)"
  end
end
