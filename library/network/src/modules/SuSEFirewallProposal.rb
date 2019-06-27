# ***************************************************************************
#
# Copyright (c) 2002 - 2012 Novell, Inc.
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
# File:  modules/SuSEFirewallProposal.ycp
# Package:  SuSEFirewall configuration
# Summary:  Functional interface for SuSEFirewall installation proposal
# Authors:  Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
# This module provides a functional API for Installation proposal of SuSEfirewall2
require "yast"

module Yast
  class SuSEFirewallProposalClass < Module
    include Yast::Logger

    def main
      textdomain "base"

      Yast.import "SuSEFirewall"
      Yast.import "ProductFeatures"
      Yast.import "Linuxrc"
      Yast.import "Package"
      Yast.import "SuSEFirewallServices"

      # <!-- SuSEFirewall LOCAL VARIABLES //-->

      # proposal was changed by user
      @proposal_changed_by_user = false

      # proposal was initialized yet
      @proposal_initialized = false

      # known interfaces
      @known_interfaces = []

      # warnings for this "turn"
      @warnings_now = []

      @vnc_fallback_ports = ["5801", "5901"]

      # bnc #427708, yet another name of service
      @vnc_service = "service:xorg-x11-server"

      @ssh_service = "service:sshd"
    end

    # <!-- SuSEFirewall LOCAL VARIABLES //-->

    # <!-- SuSEFirewall LOCAL FUNCTIONS //-->

    # Local function adds another warning string into warnings for user
    #
    # @param [String] warning
    def AddWarning(warning)
      @warnings_now = Builtins.add(@warnings_now, warning)

      nil
    end

    # Local function clears all warnings for user from memory
    def ClearWarnings
      @warnings_now = []

      nil
    end

    # Function returns list of warnings for user
    #
    # @return  [Array<String>] of warnings
    def GetWarnings
      deep_copy(@warnings_now)
    end

    # Local function sets currently known interfaces.
    #
    # @param [Array<String>] interfaces list of known interfaces
    def SetKnownInterfaces(interfaces)
      interfaces = deep_copy(interfaces)
      @known_interfaces = deep_copy(interfaces)

      nil
    end

    # Local function returns list [string] of known interfaces.
    # They must have been set using SetKnownInterfaces(list [string] interfaces)
    # function.
    #
    # @return  [Array<String>] of known interfaces
    def GetKnownInterfaces
      deep_copy(@known_interfaces)
    end

    # Function returns if interface is a dial-up type.
    #
    # @return  [Boolean] if is dial-up interface
    def IsDialUpInterface(interface)
      all_interfaces = SuSEFirewall.GetAllKnownInterfaces

      interface_type = nil
      Builtins.foreach(all_interfaces) do |one|
        next if Ops.get(one, "id") != interface

        # this is THE interface
        interface_type = Ops.get(one, "type")
      end

      interface_type == "dialup"
    end

    # Local function adds list of interfaces into zone.
    #
    # @param [Array<String>] interfaces
    # @param [String] zone
    def SetInterfacesToZone(interfaces, zone)
      interfaces = deep_copy(interfaces)
      Builtins.foreach(interfaces) do |interface|
        SuSEFirewall.AddInterfaceIntoZone(interface, zone)
      end

      nil
    end

    # Local function for updating user-changed proposal.
    def UpdateProposal
      last_known_interfaces = GetKnownInterfaces()
      currently_known_interfaces = SuSEFirewall.GetListOfKnownInterfaces

      had_dialup_interfaces = false
      Builtins.foreach(last_known_interfaces) do |this_interface|
        if IsDialUpInterface(this_interface)
          had_dialup_interfaces = true
          raise Break
        end
      end

      Builtins.foreach(currently_known_interfaces) do |interface|
        # already known but not assigned
        next if Builtins.contains(last_known_interfaces, interface)
        # already configured in some zone
        next if !SuSEFirewall.GetZoneOfInterface(interface).nil?

        # any dial-up interfaces presented and the new one isn't dial-up
        if had_dialup_interfaces && !IsDialUpInterface(interface)
          AddWarning(
            Builtins.sformat(
              # TRANSLATORS: Warning in installation proposal, %1 is a device name (eth0, sl0, ...)
              _(
                "New network device '%1' found; added as an internal firewall interface"
              ),
              interface
            )
          )
          SetInterfacesToZone([interface], "INT")
        else
          AddWarning(
            Builtins.sformat(
              # TRANSLATORS: Warning in installation proposal, %1 is a device name (eth0, sl0, ...)
              _(
                "New network device '%1' found; added as an external firewall interface"
              ),
              interface
            )
          )
          SetInterfacesToZone([interface], "EXT")
        end
      end

      SetKnownInterfaces(currently_known_interfaces)

      nil
    end

    # Returns whether service is enabled in zones.
    #
    # @param [String] service
    # @param [Array<String>] zones
    # @return [Boolean] if enabled
    def ServiceEnabled(service, zones)
      zones = deep_copy(zones)
      if service.nil? || service == ""
        Builtins.y2error("Ups, service: %1?", service)
        return false
      end

      if zones.nil? || zones == []
        Builtins.y2error("Ups, zones: %1?", zones)
        return false
      end

      serenabled = true

      serstat = SuSEFirewall.GetServices([service])
      Builtins.foreach(zones) do |one_zone|
        if Ops.get(serstat, [service, one_zone]) == false
          Builtins.y2milestone(
            "Service %1 is not enabled in %2",
            service,
            one_zone
          )
          serenabled = false
          raise Break
        end
      end

      serenabled
    end

    # Enables ports in zones.
    #
    # @param [Array<String>] fallback_ports fallback TCP ports
    # @param [Array<String>] zones
    def EnableFallbackPorts(fallback_ports, zones)
      known_zones = SuSEFirewall.GetKnownFirewallZones()
      unknown_zones = zones - known_zones
      raise "Unknown firewall zones #{unknown_zones}" unless unknown_zones.empty?

      log.info "Enabling fallback ports: #{fallback_ports} in zones: #{zones}"
      zones.each do |one_zone|
        fallback_ports.each do |one_port|
          SuSEFirewall.AddService(one_port, "TCP", one_zone)
        end
      end

      nil
    end

    # Function opens service for network interfaces given as the third parameter.
    # Fallback ports are used if the given service is uknown.
    # If interfaces are not assigned to any firewall zone, all zones will be used.
    #
    # @see OpenServiceOnNonDialUpInterfaces for more info.
    #
    # @param [String] service e.g., "service:http-server"
    # @param [Array<String>] fallback_ports e.g., ["80"]
    # @param [Array<String>] interfaces e.g., ["eth3"]
    def OpenServiceInInterfaces(service, fallback_ports, interfaces)
      fallback_ports = deep_copy(fallback_ports)
      interfaces = deep_copy(interfaces)
      zones = SuSEFirewall.GetZonesOfInterfaces(interfaces)

      # Interfaces might not be assigned to any zone yet, use all zones
      zones = SuSEFirewall.GetKnownFirewallZones() if zones.empty?

      if SuSEFirewallServices.IsKnownService(service)
        log.info "Opening service #{service} on interfaces #{interfaces} (zones #{zones})"
        SuSEFirewall.SetServicesForZones([service], zones, true)
      else
        log.warn "Unknown service #{service}, enabling fallback ports"
        EnableFallbackPorts(fallback_ports, zones)
      end

      nil
    end

    # Checks whether the given service or (TCP) ports are open at least in
    # one FW zone.
    #
    # @param [String] service e.g., "service:http-server"
    # @param [Array<String>] fallback_ports e.g., ["80"]
    def IsServiceOrPortsOpen(service, fallback_ports)
      fallback_ports = deep_copy(fallback_ports)
      ret = false

      Builtins.foreach(SuSEFirewall.GetKnownFirewallZones) do |zone|
        # either service is supported
        if SuSEFirewall.IsServiceSupportedInZone(service, zone)
          ret = true
          # or check for ports
        else
          all_ports = true

          # all ports have to be open
          Builtins.foreach(fallback_ports) do |port|
            if !SuSEFirewall.HaveService(port, "TCP", zone)
              all_ports = false
              raise Break
            end
          end

          ret = true if all_ports
        end
        raise Break if ret == true
      end

      ret
    end

    # Function opens up the service on all non-dial-up network interfaces.
    # If there are no network interfaces known and the 'any' feature is supported,
    # function opens the service for the zone supporting that feature. If there
    # are only dial-up interfaces, function opens the service for them.
    #
    # @param [String] service such as "service:koo" or "serice:boo"
    # @param [Array<String>] fallback_ports list of ports used as a fallback if the given service doesn't exist
    def OpenServiceOnNonDialUpInterfaces(service, fallback_ports)
      fallback_ports = deep_copy(fallback_ports)
      non_dial_up_interfaces = SuSEFirewall.GetAllNonDialUpInterfaces
      dial_up_interfaces = SuSEFirewall.GetAllDialUpInterfaces

      # Opening the service for non-dial-up interfaces
      if Ops.greater_than(Builtins.size(non_dial_up_interfaces), 0)
        OpenServiceInInterfaces(service, fallback_ports, non_dial_up_interfaces)
        # Only dial-up network interfaces, there mustn't be any non-dial-up one
      elsif Ops.greater_than(Builtins.size(dial_up_interfaces), 0)
        OpenServiceInInterfaces(service, fallback_ports, dial_up_interfaces)
        # No network interfaces are known
      elsif Builtins.size(@known_interfaces) == 0
        if SuSEFirewall.IsAnyNetworkInterfaceSupported == true
          Builtins.y2warning(
            "WARNING: Opening %1 for the External zone without any known interface!",
            Builtins.toupper(service)
          )
          OpenServiceInInterfaces(
            service,
            fallback_ports,
            [SuSEFirewall.special_all_interface_string]
          )
        end
      end

      nil
    end

    # Local function returns whether the Xen kernel is installed
    #
    # @return [Boolean] whether xen-capable kernel is installed.
    def IsXenInstalled
      # bug #154133
      return true if Package.Installed("kernel-xen")
      return true if Package.Installed("kernel-xenpae")

      false
    end

    # Local function for proposing firewall configuration.
    def ProposeFunctions
      known_interfaces = SuSEFirewall.GetAllKnownInterfaces

      dial_up_interfaces = []
      non_dup_interfaces = []
      Builtins.foreach(known_interfaces) do |interface|
        if Ops.get(interface, "type") == "dial_up"
          dial_up_interfaces = Builtins.add(
            dial_up_interfaces,
            Ops.get(interface, "id", "")
          )
        else
          non_dup_interfaces = Builtins.add(
            non_dup_interfaces,
            Ops.get(interface, "id", "")
          )
        end
      end

      Builtins.y2milestone(
        "Proposal based on configuration: Dial-up interfaces: %1, Other: %2",
        dial_up_interfaces,
        non_dup_interfaces
      )

      # has any network interface
      if Builtins.size(non_dup_interfaces) == 0 ||
          Builtins.size(dial_up_interfaces) == 0
        SuSEFirewall.SetEnableService(
          ProductFeatures.GetBooleanFeature("globals", "enable_firewall")
        )
        SuSEFirewall.SetStartService(
          ProductFeatures.GetBooleanFeature("globals", "enable_firewall")
        )
      end

      # has non-dial-up and also dial-up interfaces
      if Ops.greater_than(Builtins.size(non_dup_interfaces), 0) &&
          Ops.greater_than(Builtins.size(dial_up_interfaces), 0)
        SetInterfacesToZone(non_dup_interfaces, "INT")
        SetInterfacesToZone(dial_up_interfaces, "EXT")
        SuSEFirewall.SetServicesForZones([@ssh_service], ["INT", "EXT"], true) if ProductFeatures.GetBooleanFeature("globals", "firewall_enable_ssh")

        # has non-dial-up and doesn't have dial-up interfaces
      elsif Ops.greater_than(Builtins.size(non_dup_interfaces), 0) &&
          Builtins.size(dial_up_interfaces) == 0
        SetInterfacesToZone(non_dup_interfaces, "EXT")
        SuSEFirewall.SetServicesForZones([@ssh_service], ["EXT"], true) if ProductFeatures.GetBooleanFeature("globals", "firewall_enable_ssh")

        # doesn't have non-dial-up and has dial-up interfaces
      elsif Builtins.size(non_dup_interfaces) == 0 &&
          Ops.greater_than(Builtins.size(dial_up_interfaces), 0)
        SetInterfacesToZone(dial_up_interfaces, "EXT")
        SuSEFirewall.SetServicesForZones([@ssh_service], ["EXT"], true) if ProductFeatures.GetBooleanFeature("globals", "firewall_enable_ssh")
      end

      # Dial-up interfaces are considered to be internal,
      # Non-dial-up are considered to be external.
      # If there are only Non-dial-up interfaces, they are all considered as external.
      #
      # VNC Installation proposes to open VNC Access up on the Non-dial-up interfaces only.
      # SSH Installation is the same case...
      if Linuxrc.vnc
        Builtins.y2milestone(
          "This is an installation over VNC, opening VNC on all non-dial-up interfaces..."
        )
        # Try the service first, then ports
        # bnc #398855
        OpenServiceOnNonDialUpInterfaces(@vnc_service, @vnc_fallback_ports)
      end
      if Linuxrc.usessh
        Builtins.y2milestone(
          "This is an installation over SSH, opening SSH on all non-dial-up interfaces..."
        )
        # Try the service first, then ports
        # bnc #398855
        OpenServiceOnNonDialUpInterfaces(@ssh_service, ["ssh"])
      end

      # Firewall support for XEN domain0
      if IsXenInstalled()
        Builtins.y2milestone(
          "Adding Xen support into the firewall configuration"
        )
        SuSEFirewall.AddXenSupport
      end

      propose_iscsi if Linuxrc.useiscsi

      SetKnownInterfaces(SuSEFirewall.GetListOfKnownInterfaces)

      nil
    end

    # <!-- SuSEFirewall LOCAL FUNCTIONS //-->

    # <!-- SuSEFirewall GLOBAL FUNCTIONS //-->

    # Function sets that proposal was changed by user
    #
    # @param changed [true, false] if changed by user
    def SetChangedByUser(changed)
      Builtins.y2milestone("Proposal was changed by user")
      @proposal_changed_by_user = changed

      nil
    end

    # Local function returns if proposal was changed by user
    #
    # @return  [Boolean] if proposal was changed by user
    def GetChangedByUser
      @proposal_changed_by_user
    end

    # Function sets that proposal was initialized
    #
    # @param initialized [true, false] if initialized
    def SetProposalInitialized(initialized)
      @proposal_initialized = initialized

      nil
    end

    # Local function returns if proposal was initialized already
    #
    # @return  [Boolean] if proposal was initialized
    def GetProposalInitialized
      @proposal_initialized
    end

    # Function fills up default configuration into internal values
    #
    # @return [void]
    def Reset
      SuSEFirewall.ResetReadFlag
      SuSEFirewall.Read

      nil
    end

    # Function proposes the SuSEfirewall2 configuration
    #
    # @return [void]
    def Propose
      # No proposal when SuSEfirewall2 is not installed
      if !SuSEFirewall.SuSEFirewallIsInstalled
        SuSEFirewall.SetEnableService(false)
        SuSEFirewall.SetStartService(false)
        return nil
      end

      # Not changed by user - Propose from scratch
      if !GetChangedByUser()
        Builtins.y2milestone("Calling firewall configuration proposal")
        Reset()
        ProposeFunctions()
        # Changed - don't break user's configuration
      else
        Builtins.y2milestone("Calling firewall configuration update proposal")
        UpdateProposal()
      end

      nil
    end

    # Function returns the proposal summary
    #
    # @return [Hash{String => String}] proposal
    #
    # **Structure:**
    #
    #     map $[
    #       "output" : "HTML Proposal Summary",
    #       "warning" : "HTML Warning Summary",
    #      ]
    def ProposalSummary
      # output: $[ "output" : "HTML Proposal", "warning" : "HTML Warning" ];
      output = ""
      warning = ""

      # SuSEfirewall2 package needn't be installed
      if !SuSEFirewall.SuSEFirewallIsInstalled
        # TRANSLATORS: Proposal informative text
        output = "<ul>" +
          _(
            "SuSEfirewall2 package is not installed, firewall will be disabled."
          ) + "</ul>"

        return { "output" => output, "warning" => warning }
      end

      # SuSEfirewall2 is installed...

      firewall_is_enabled = SuSEFirewall.GetEnableService == true

      output = Ops.add(output, "<ul>\n")
      output = Ops.add(
        Ops.add(
          Ops.add(output, "<li>"),
          if firewall_is_enabled
            # TRANSLATORS: Proposal informative text "Firewall is enabled (disable)" with link around
            # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
            _(
              "Firewall is enabled (<a href=\"firewall--disable_firewall_in_proposal\">disable</a>)"
            )
          else
            # TRANSLATORS: Proposal informative text "Firewall is disabled (enable)" with link around
            # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
            _(
              "Firewall is disabled (<a href=\"firewall--enable_firewall_in_proposal\">enable</a>)"
            )
          end
        ),
        "</li>\n"
      )

      if firewall_is_enabled
        # Any enabled SSH means SSH-is-enabled
        is_ssh_enabled = false

        # Any known interfaces
        if Ops.greater_than(Builtins.size(@known_interfaces), 0)
          Builtins.y2milestone("Interfaces: %1", @known_interfaces)

          # all known interfaces for testing
          used_zones = SuSEFirewall.GetZonesOfInterfacesWithAnyFeatureSupported(
            @known_interfaces
          )
          Builtins.y2milestone("Zones used by firewall: %1", used_zones)

          Builtins.foreach(used_zones) do |zone|
            if SuSEFirewall.IsServiceSupportedInZone(@ssh_service, zone) ||
                SuSEFirewall.HaveService("ssh", "TCP", zone)
              is_ssh_enabled = true
            end
          end

          output = Ops.add(
            Ops.add(
              Ops.add(output, "<li>"),
              if is_ssh_enabled
                # TRANSLATORS: Network proposal informative text with link around
                # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
                _(
                  "SSH port is open (<a href=\"firewall--disable_ssh_in_proposal\">close</a>)"
                )
              else
                # TRANSLATORS: Network proposal informative text with link around
                # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
                _(
                  "SSH port is blocked (<a href=\"firewall--enable_ssh_in_proposal\">open</a>)"
                )
              end
            ),
            "</li>\n"
          )

          # No known interfaces, but 'any' is supported
          # and ssh is enabled there
        elsif SuSEFirewall.IsAnyNetworkInterfaceSupported &&
            SuSEFirewall.IsServiceSupportedInZone(
              @ssh_service,
              SuSEFirewall.special_all_interface_zone
            )
          is_ssh_enabled = true
          # TRANSLATORS: Network proposal informative text with link around
          # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
          output = Ops.add(
            Ops.add(
              Ops.add(output, "<li>"),
              _(
                "SSH port is open (<a href=\"firewall--disable_ssh_in_proposal\">close</a>), but\nthere are no network interfaces configured"
              )
            ),
            "</li>"
          )
        end
        Builtins.y2milestone(
          "SSH is " + (is_ssh_enabled ? "" : "not ") + "enabled"
        )

        if Linuxrc.usessh
          if !is_ssh_enabled
            # TRANSLATORS: This is a warning message. Installation over SSH without SSH allowed on firewall
            AddWarning(
              _(
                "You are installing a system over SSH, but you have not opened the SSH port on the firewall."
              )
            )
          end
        end

        # when the firewall is enabled and we are installing the system over VNC
        if Linuxrc.vnc
          # Any enabled VNC means VNC-is-enabled
          is_vnc_enabled = false
          if Ops.greater_than(Builtins.size(@known_interfaces), 0)
            Builtins.foreach(
              SuSEFirewall.GetZonesOfInterfacesWithAnyFeatureSupported(
                @known_interfaces
              )
            ) do |zone|
              if SuSEFirewall.IsServiceSupportedInZone(@vnc_service, zone) == true
                is_vnc_enabled = true
                # checking also fallback ports
              else
                set_vnc_enabled_to = true
                Builtins.foreach(@vnc_fallback_ports) do |one_port|
                  if SuSEFirewall.HaveService(one_port, "TCP", zone) != true
                    set_vnc_enabled_to = false
                    raise Break
                  end
                  is_vnc_enabled = true if set_vnc_enabled_to == true
                end
              end
            end
          end
          Builtins.y2milestone(
            "VNC port is " + (is_vnc_enabled ? "open" : "blocked") + " in the firewall"
          )

          output = Ops.add(
            Ops.add(
              Ops.add(output, "<li>"),
              if is_vnc_enabled
                # TRANSLATORS: Network proposal informative text "Remote Administration (VNC) is enabled" with link around
                # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
                _(
                  "Remote Administration (VNC) ports are open (<a href=\"firewall--disable_vnc_in_proposal\">close</a>)"
                )
              else
                # TRANSLATORS: Network proposal informative text "Remote Administration (VNC) is disabled" with link around
                # IMPORTANT: Please, do not change the HTML link <a href="...">...</a>, only visible text
                _(
                  "Remote Administration (VNC) ports are blocked (<a href=\"firewall--enable_vnc_in_proposal\">open</a>)"
                )
              end
            ),
            "</li>\n"
          )

          if !is_vnc_enabled
            # TRANSLATORS: This is a warning message. Installation over VNC without VNC allowed on firewall
            AddWarning(
              _(
                "You are installing a system using remote administration (VNC), but you have not opened the VNC ports on the firewall."
              )
            )
          end
        end

        if Linuxrc.useiscsi
          is_iscsi_enabled = IsServiceOrPortsOpen(
            @iscsi_target_service,
            @iscsi_target_fallback_ports
          )

          output = Ops.add(
            Ops.add(
              Ops.add(output, "<li>"),
              if is_iscsi_enabled
                # TRANSLATORS: Network proposal informative text
                _("iSCSI Target ports are open")
              else
                # TRANSLATORS: Network proposal informative text
                _("iSCSI Target ports are blocked")
              end
            ),
            "</li>\n"
          )

          if !is_iscsi_enabled
            # TRANSLATORS: This is a warning message. Installation to iSCSI without iSCSI allowed on firewall
            AddWarning(
              _(
                "You are installing a system using iSCSI Target, but you have not opened the needed ports on the firewall."
              )
            )
          end
        end

        warnings_strings = GetWarnings()
        if Ops.greater_than(Builtins.size(warnings_strings), 0)
          ClearWarnings()
          Builtins.foreach(warnings_strings) do |single_warning|
            warning = Ops.add(
              Ops.add(Ops.add(warning, "<li>"), single_warning),
              "</li>\n"
            )
          end
          warning = Ops.add(Ops.add("<ul>\n", warning), "</ul>\n")
        end
      end

      output = Ops.add(output, "</ul>\n")

      { "output" => output, "warning" => warning }
    end

    # Proposes firewall settings for iSCSI
    def propose_iscsi
      log.info "iSCSI has been used during installation, proposing FW full_init_on_boot"

      # bsc#916376: ports need to be open already during boot
      SuSEFirewall.full_init_on_boot(true)

      nil
    end

    publish function: :OpenServiceOnNonDialUpInterfaces, type: "void (string, list <string>)"
    publish function: :SetChangedByUser, type: "void (boolean)"
    publish function: :GetChangedByUser, type: "boolean ()"
    publish function: :SetProposalInitialized, type: "void (boolean)"
    publish function: :GetProposalInitialized, type: "boolean ()"
    publish function: :Reset, type: "void ()"
    publish function: :Propose, type: "void ()"
    publish function: :ProposalSummary, type: "map <string, string> ()"
    publish function: :propose_iscsi, type: "void ()"
  end

  SuSEFirewallProposal = SuSEFirewallProposalClass.new
  SuSEFirewallProposal.main
end
