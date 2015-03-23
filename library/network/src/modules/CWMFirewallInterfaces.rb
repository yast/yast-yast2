# encoding: utf-8

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
# File:	modules/CWMFirewallInterfaces.ycp
# Package:	Common widget manipulation, firewall interfaces widget
# Summary:	Routines for selecting interfaces opened in firewall
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# WARNING: If you want to use this functionality of this module
#          you should allways call 'SuSEFirewall::Read()' in the
#          Read() function of you module
#          and you should call 'SuSEFirewall::Write()' in the
#          Write() function.
#
#	    Functionality of this module only changes the SuSEFirewall
#          settings in memory, it never Reads or Writes the settings.
#
#	    Additionally you may need to call Progress::set(false)
#	    before SuSEFirewall::Read() or SuSEFirewall::Write().
require "yast"

module Yast
  class CWMFirewallInterfacesClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "NetworkInterfaces"
      Yast.import "Popup"
      Yast.import "SuSEFirewall"
      Yast.import "Report"
      Yast.import "Stage"
      Yast.import "String"

      # used only for (Mode::installation() || Mode::update())
      Yast.import "SuSEFirewallProposal"

      # private variables

      # List of all interfaces relevant for firewall settings
      @all_interfaces = nil

      # List of all items of interfaces to the selection box
      @interface_items = nil

      # List of interfaces that are allowed
      @allowed_interfaces = nil

      # Information if configuration was changed by user
      @configuration_changed = false

      # `Any`-feature is supported in the firewall configuration
      @any_iface_supported = nil

      @buggy_ifaces = []
    end

    # private functions

    # Enable or disable the firewall details widget according to the status
    # of "open firewall" checkbox
    def EnableOrDisableFirewallDetails
      return if !UI.WidgetExists(Id("_cwm_open_firewall"))
      return if !UI.WidgetExists(Id("_cwm_firewall_details"))
      enabled = Convert.to_boolean(
        UI.QueryWidget(Id("_cwm_open_firewall"), :Value)
      )
      enabled = false if enabled.nil?
      enabled = false if Builtins.size(@all_interfaces) == 0

      UI.ChangeWidget(Id("_cwm_firewall_details"), :Enabled, enabled)

      nil
    end

    # Set the firewall status label
    # @param [Symbol] status symbol one of `off, `closed, `open_all, `custom, `not_installed
    def SetFirewallLabel(status)
      label = ""
      if status == :not_installed
        # bnc #429861
        if Stage.initial
          # label
          label = _(
            "Firewall cannot be adjusted during first stage installation."
          )
        else
          # label
          label = _("Firewall package is not installed.")
        end
      elsif status == :off
        # label
        label = _("Firewall is disabled")
      elsif status == :closed
        # label
        label = _("Firewall port is closed")
      elsif status == :open_all
        # label
        label = _("Firewall port is open on all interfaces")
      elsif status == :custom
        # label
        label = _("Firewall port is open on selected interfaces")
      elsif status == :no_ifaces
        # label
        label = _("No network interfaces are configured")
      end
      UI.ReplaceWidget(Id(:_cwm_firewall_status_rp), Label(label))

      nil
    end

    # Initialize the list of all known interfaces
    def InitAllInterfacesList
      # Do not read NetworkInterfaces when they are already read
      if !Mode.config && !Mode.installation && !Mode.update
        Builtins.y2milestone("Reading NetworkInterfaces...")
        NetworkInterfaces.Read
      end
      @all_interfaces = String.NonEmpty(NetworkInterfaces.List(""))
      @all_interfaces = Builtins.filter(@all_interfaces) { |i| i != "lo" }
      if !Mode.config
        @interface_items = Builtins.maplist(@all_interfaces) do |i|
          label = NetworkInterfaces.GetValue(i, "BOOTPROTO")
          ipaddr = NetworkInterfaces.GetValue(i, "IPADDR")
          # BNC #483455: Interface zone name
          zone = SuSEFirewall.GetZoneOfInterface(i)
          if !zone.nil? && zone != ""
            zone = SuSEFirewall.GetZoneFullName(zone)
          else
            zone = _("Interface is not assigned to any zone")
          end
          if label == "static" || label == "" || label.nil?
            label = ipaddr
          else
            label = Builtins.toupper(label)
            if !ipaddr.nil? && ipaddr != ""
              label = Builtins.sformat("%1/%2", label, ipaddr)
            end
          end
          if label.nil? || label == ""
            label = i
          else
            label = Builtins.sformat("%1 (%2 / %3)", i, label, zone)
          end
          Item(Id(i), label)
        end
      else
        @interface_items = Builtins.maplist(@all_interfaces) do |i|
          Item(Id(i), i)
        end
      end

      @any_iface_supported = SuSEFirewall.IsAnyNetworkInterfaceSupported

      nil
    end

    # Update the firewall status label according to the current status
    def UpdateFirewallStatus
      InitAllInterfacesList() if @all_interfaces.nil?
      status = :custom

      # bnc #429861
      if Stage.initial || !SuSEFirewall.SuSEFirewallIsInstalled
        status = :not_installed
      elsif !SuSEFirewall.GetEnableService
        status = :off
      elsif Builtins.size(@all_interfaces) == 0
        status = :no_ifaces
      elsif Builtins.size(@all_interfaces) == Builtins.size(@allowed_interfaces)
        status = :open_all
      elsif Builtins.size(@allowed_interfaces) == 0
        status = :closed
      end

      Builtins.y2milestone(
        "Status: %1, All: %2, Allowed: %3",
        status,
        @all_interfaces,
        @allowed_interfaces
      )
      SetFirewallLabel(status)
      open = status == :open_all || status == :custom
      UI.ChangeWidget(Id("_cwm_open_firewall"), :Value, open)

      nil
    end

    # Get the list of all interfaces that will be selected
    # @param [Array<String>] ifaces a list of interfaces selected by the user
    # @param [Boolean] nm_ifaces_have_to_be_selected defines whether also NetworkManager have to be selected too
    # @return a list of interfaces that will be opened
    def Selected2Opened(ifaces, _nm_ifaces_have_to_be_selected)
      ifaces = deep_copy(ifaces)
      Builtins.y2milestone("Selected ifaces: %1", ifaces)
      groups = Builtins.maplist(ifaces) do |i|
        SuSEFirewall.GetZoneOfInterface(i)
      end

      # string 'any' is in the EXT zone
      # all interfaces without zone assigned are covered by this case
      # so, check also the EXT zone
      if SuSEFirewall.IsAnyNetworkInterfaceSupported
        groups = Builtins.add(groups, SuSEFirewall.special_all_interface_zone)
      end

      groups = String.NonEmpty(Builtins.toset(groups))
      groups = Builtins.filter(groups) { |g| !g.nil? }
      iface_groups = Builtins.maplist(groups) do |g|
        ifaces_also_supported_by_any = SuSEFirewall.GetInterfacesInZoneSupportingAnyFeature(
          g
        )
        # If all interfaces in EXT zone are covered by the special 'any' string
        # and none of these interfaces are selected to be open, we can remove all of them
        # disable the service in whole EXT zone
        if g == SuSEFirewall.special_all_interface_zone
          ifaces_left_explicitely = Builtins.filter(
            ifaces_also_supported_by_any
          ) do |iface|
            Builtins.contains(ifaces, iface)
          end
          Builtins.y2milestone(
            "Ifaces left in zone: %1",
            ifaces_left_explicitely
          )
          # there are no interfaces left that would be explicitely mentioned in the EXT zone
          if ifaces_left_explicitely == []
            next []
            # Hmm, some interfaces left
          else
            next deep_copy(ifaces_also_supported_by_any)
          end
          # Just report all interfaces mentioned in zone
        else
          next deep_copy(ifaces_also_supported_by_any)
        end
      end
      Builtins.y2milestone("Ifaces touched: %1", iface_groups)
      new_ifaces = Builtins.toset(Builtins.flatten(iface_groups))
      new_ifaces = Builtins.filter(new_ifaces) { |i| !i.nil? }

      Builtins.toset(new_ifaces)
    end

    # Display popup with firewall settings details
    def DisplayFirewallDetailsPopupHandler(widget)
      widget = deep_copy(widget)
      common_details_handler = Convert.convert(
        Ops.get(widget, "common_details_handler"),
        from: "any",
        to:   "void (map <string, any>)"
      )
      common_details_handler.call(widget) if !common_details_handler.nil?

      nil
    end

    # public functions

    # general functions

    # Initialize the list of allowed interfaces
    # Changes the internal variables
    # @param [Array<String>] services a list of services
    def InitAllowedInterfaces(services)
      services = deep_copy(services)
      service_status = {}

      ifaces_info = SuSEFirewall.GetServicesInZones(services)
      Builtins.foreach(ifaces_info) do |_s, status|
        Builtins.foreach(status) do |iface, en|
          Ops.set(
            service_status,
            iface,
            Ops.get(service_status, iface, true) && en
          )
        end
      end
      service_status = Builtins.filter(service_status) { |_iface, en| en == true }
      Builtins.y2milestone("Status: %1", service_status)
      @allowed_interfaces = Builtins.maplist(service_status) do |iface, _en|
        iface
      end

      # Checking whether the string 'any' is in the 'EXT' zone
      # If it is, checking the status of services for this zone
      # If it is enabled, adding it these interfaces into the list of allowed interfaces
      #                   and setting this zone to enabled
      if SuSEFirewall.IsAnyNetworkInterfaceSupported
        interfaces_supported_by_any = SuSEFirewall.InterfacesSupportedByAnyFeature(
          SuSEFirewall.special_all_interface_zone
        )
        if Ops.greater_than(Builtins.size(interfaces_supported_by_any), 0)
          Builtins.foreach(services) do |service|
            Ops.set(
              service_status,
              SuSEFirewall.special_all_interface_zone,
              SuSEFirewall.IsServiceSupportedInZone(
                service,
                SuSEFirewall.special_all_interface_zone
              ) &&
                Ops.get(
                  service_status,
                  SuSEFirewall.special_all_interface_zone,
                  true
                )
            )
          end
          if Ops.get(
            service_status,
            SuSEFirewall.special_all_interface_zone,
            false
            )
            @allowed_interfaces = Convert.convert(
              Builtins.union(@allowed_interfaces, interfaces_supported_by_any),
              from: "list",
              to:   "list <string>"
            )
          end
        end
      end

      # Check the INT zone, it's not protected by default
      # See bnc #382686
      internal_interfaces = SuSEFirewall.GetInterfacesInZone("INT")
      if Ops.greater_than(Builtins.size(internal_interfaces), 0) &&
          SuSEFirewall.GetProtectFromInternalZone == false
        Builtins.y2milestone(
          "Unprotected internal interfaces: %1",
          internal_interfaces
        )
        @allowed_interfaces = Convert.convert(
          Builtins.union(@allowed_interfaces, internal_interfaces),
          from: "list",
          to:   "list <string>"
        )
      else
        Builtins.y2milestone(
          "Internal zone is protected or there are no interfaces in it"
        )
      end

      @configuration_changed = false

      nil
    end

    # Store the list of allowed interfaces
    # Users the internal variables
    # @param [Array<String>] services a list of services
    def StoreAllowedInterfaces(services)
      services = deep_copy(services)
      # do not save anything if configuration didn't change
      return if !@configuration_changed
      forbidden_interfaces = Builtins.filter(@all_interfaces) do |i|
        !Builtins.contains(@allowed_interfaces, i)
      end

      # If configuring firewall in any type of installation
      # proposal must be set to 'modified'
      if Mode.installation || Mode.update
        Builtins.y2milestone("Firewall proposal modified by user")
        SuSEFirewallProposal.SetChangedByUser(true)
      end

      if Ops.greater_than(Builtins.size(forbidden_interfaces), 0)
        SuSEFirewall.SetServices(services, forbidden_interfaces, false)
      end
      if Ops.greater_than(Builtins.size(@allowed_interfaces), 0)
        SuSEFirewall.SetServices(services, @allowed_interfaces, true)
      end

      nil
    end

    # Init function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    def InterfacesInit(_widget, _key)
      # set the list of ifaces
      InitAllInterfacesList() if @all_interfaces.nil?
      UI.ReplaceWidget(
        Id("_cwm_interface_list_rp"),
        MultiSelectionBox(
          Id("_cwm_interface_list"),
          # transaltors: selection box title
          _("&Network Interfaces with Open Port in Firewall"),
          @interface_items
        )
      )
      # mark open ifaces as open
      UI.ChangeWidget(
        Id("_cwm_interface_list"),
        :SelectedItems,
        @allowed_interfaces
      )

      nil
    end

    # Handle function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    # @param [Hash] event map event to be handled
    # @return [Symbol] for wizard sequencer or nil
    def InterfacesHandle(_widget, _key, event)
      event_id = Ops.get(event, "ID")
      if event_id == "_cwm_interface_select_all"
        UI.ChangeWidget(
          Id("_cwm_interface_list"),
          :SelectedItems,
          @all_interfaces
        )
        return nil
      end
      if event_id == "_cwm_interface_select_none"
        UI.ChangeWidget(Id("_cwm_interface_list"), :SelectedItems, [])
        return nil
      end
      nil
    end

    # Store function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    # @param [Hash] event map that caused widget data storing
    def InterfacesStore(_widget, _key, _event)
      @allowed_interfaces = Convert.convert(
        UI.QueryWidget(Id("_cwm_interface_list"), :SelectedItems),
        from: "any",
        to:   "list <string>"
      )
      @allowed_interfaces = Selected2Opened(@allowed_interfaces, false)
      @configuration_changed = true

      nil
    end

    # Validate function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    # @param [Hash] event map event that caused the validation
    # @return true if validation succeeded, false otherwise
    def InterfacesValidate(_widget, _key, _event)
      ifaces = Convert.convert(
        UI.QueryWidget(Id("_cwm_interface_list"), :SelectedItems),
        from: "any",
        to:   "list <string>"
      )
      ifaces = Builtins.toset(ifaces)
      Builtins.y2milestone("Selected ifaces: %1", ifaces)

      # Check the INT zone, it's not protected by default
      # See bnc #382686
      internal_interfaces = SuSEFirewall.GetInterfacesInZone("INT")

      if Ops.greater_than(Builtins.size(internal_interfaces), 0) &&
          SuSEFirewall.GetProtectFromInternalZone == false
        int_not_selected = []
        Builtins.foreach(internal_interfaces) do |one_internal|
          if !Builtins.contains(ifaces, one_internal)
            int_not_selected = Builtins.add(int_not_selected, one_internal)
          end
        end

        if Ops.greater_than(Builtins.size(int_not_selected), 0)
          Builtins.y2warning(
            "Unprotected internal interfaces not selected: %1",
            int_not_selected
          )

          Report.Message(
            Builtins.sformat(
              _(
                "These network interfaces assigned to internal network cannot be deselected:\n%1\n"
              ),
              Builtins.mergestring(int_not_selected, "\n")
            )
          )

          ifaces = Convert.convert(
            Builtins.union(ifaces, int_not_selected),
            from: "list",
            to:   "list <string>"
          )
          Builtins.y2milestone("Selected interfaces: %1", ifaces)
          UI.ChangeWidget(Id("_cwm_interface_list"), :SelectedItems, ifaces)
          return false
        end
      end

      if Builtins.size(ifaces) == 0
        # question popup
        if !Popup.YesNo(
          _(
            "No interface is selected. Service will not\n" \
              "be available for other computers.\n" \
              "\n" \
              "Continue?"
          )
          )
          return false
        end
      end

      firewall_ifaces = Builtins.toset(Selected2Opened(ifaces, false))
      Builtins.y2milestone("firewall_ifaces: %1", firewall_ifaces)

      added_ifaces = Builtins.filter(firewall_ifaces) do |i|
        !Builtins.contains(ifaces, i)
      end
      Builtins.y2milestone("added_ifaces: %1", added_ifaces)

      removed_ifaces = Builtins.filter(ifaces) do |i|
        !Builtins.contains(firewall_ifaces, i)
      end
      Builtins.y2milestone("removed_ifaces: %1", removed_ifaces)

      # to hide that special string
      if Ops.greater_than(Builtins.size(added_ifaces), 0)
        ifaces_list = Builtins.mergestring(added_ifaces, "\n")
        if !Popup.YesNo(
          Builtins.sformat(
            # yes-no popup
            _(
              "Because of SuSE Firewall settings, the port\n" \
                "on the following interfaces will additionally be open:\n" \
                "%1\n" \
                "\n" \
                "Continue?"
            ),
            ifaces_list
          )
          )
          return false
        end
      end
      # to hide that special string
      if Ops.greater_than(Builtins.size(removed_ifaces), 0)
        ifaces_list = Builtins.mergestring(removed_ifaces, "\n")
        if !Popup.YesNo(
          Builtins.sformat(
            # yes-no popup
            _(
              "Because of SuSE Firewall settings, the port\n" \
                "on the following interfaces cannot be opened:\n" \
                "%1\n" \
                "\n" \
                "Continue?"
            ),
            ifaces_list
          )
          )
          return false
        end
      end
      true
    end

    # Checks whether it is possible to change the firewall status
    def CheckPossbilityToChangeFirewall(new_status)
      # Reset buggy ifaces
      @buggy_ifaces = []

      # User want's to disable the service in firewall
      # that works always
      return true if new_status == false

      # 'any' in 'EXT'
      # interfaces are mentioned in some zone or they are covered by the special string
      # enable-on-all or disable-on-all will work
      return true if SuSEFirewall.IsAnyNetworkInterfaceSupported

      # every network interface must have its zone assigned
      all_ok = true
      all_ifaces = SuSEFirewall.GetAllKnownInterfaces
      Builtins.foreach(SuSEFirewall.GetAllKnownInterfaces) do |one_interface|
        if Ops.get(one_interface, "zone").nil? ||
            Ops.get(one_interface, "zone", "") == ""
          Builtins.y2warning(
            "Cannot enable service because interface %1 is not mentioned anywhere...",
            Ops.get(one_interface, "id", "ID")
          )
          @buggy_ifaces = Builtins.add(
            @buggy_ifaces,
            Ops.get(one_interface, "id", "interface")
          )
          all_ok = false
        end
      end
      if all_ok
        return true
      else
        ifaces_list = Builtins.mergestring(@buggy_ifaces, "\n")
        # yes-no popup
        if Popup.YesNo(
          Builtins.sformat(
            _(
              "Because of SuSE Firewall settings, the port\n" \
                "on the following interfaces cannot be opened:\n" \
                "%1\n" \
                "\n" \
                "Continue?"
            ),
            ifaces_list
          )
          )
          # all known ifaces are buggy
          if Builtins.size(@buggy_ifaces) == Builtins.size(all_ifaces)
            return false
          else
            # at least one iface isn't buggy
            return true
          end
        else
          # cancel
          @buggy_ifaces = deep_copy(@all_interfaces)
          return false
        end
      end

      false
    end

    # Init function of the widget
    # @param [String] key strnig the widget key
    def InterfacesInitWrapper(key)
      InterfacesInit(CWM.GetProcessedWidget, key)

      nil
    end

    # Handle function of the widget
    # @param [String] key strnig the widget key
    # @param [Hash] event map event to be handled
    # @return [Symbol] for wizard sequencer or nil
    def InterfacesHandleWrapper(key, event)
      event = deep_copy(event)
      InterfacesHandle(CWM.GetProcessedWidget, key, event)
    end

    # Store function of the widget
    # @param [String] key strnig the widget key
    # @param [Hash] event map that caused widget data storing
    def InterfacesStoreWrapper(key, event)
      event = deep_copy(event)
      InterfacesStore(CWM.GetProcessedWidget, key, event)

      nil
    end

    # Validate function of the widget
    # @param [String] key strnig the widget key
    # @param [Hash] event map event that caused the validation
    # @return true if validation succeeded, false otherwise
    def InterfacesValidateWrapper(key, event)
      event = deep_copy(event)
      InterfacesValidate(CWM.GetProcessedWidget, key, event)
    end

    # Get the widget description map
    # @param [Hash{String => Object}] settings a map of all parameters needed to create the widget properly
    # <pre>
    #
    # Behavior manipulating functions (mandatory)
    # - "get_allowed_interfaces" : list<string>() -- function that returns
    #          the list of allowed network interfaces
    # - "set_allowed_interfaces" : void (list<string>) -- function that sets
    #          the list of allowed interfaces
    #
    # Additional settings:
    # - "help" : string -- help to the whole widget. If not specified, generic help
    #          is used (button labels are patched correctly)
    # </pre>
    # @return [Hash] the widget description map
    def CreateInterfacesWidget(settings)
      settings = deep_copy(settings)
      widget = HBox(
        HSpacing(1),
        VBox(
          HSpacing(48),
          VSpacing(1),
          ReplacePoint(
            Id("_cwm_interface_list_rp"),
            MultiSelectionBox(
              Id("_cwm_interface_list"),
              # translators: selection box title
              _("Network &Interfaces with Open Port in Firewall"),
              []
            )
          ),
          VSpacing(1),
          HBox(
            HStretch(),
            HWeight(
              1,
              PushButton(
                Id("_cwm_interface_select_all"),
                # push button to select all network intefaces for firewall
                _("Select &All")
              )
            ),
            HWeight(
              1,
              PushButton(
                Id("_cwm_interface_select_none"),
                # push button to deselect all network intefaces for firewall
                _("Select &None")
              )
            ),
            HStretch()
          ),
          VSpacing(1)
        ),
        HSpacing(1)
      )

      help = "" # TODO

      if Builtins.haskey(settings, "help")
        help = Ops.get_string(settings, "help", "")
      end

      ret = Convert.convert(
        Builtins.union(
          settings,

          "widget"            => :custom,
          "custom_widget"     => widget,
          "help"              => help,
          "init"              => fun_ref(
            method(:InterfacesInitWrapper),
            "void (string)"
          ),
          "store"             => fun_ref(
            method(:InterfacesStoreWrapper),
            "void (string, map)"
          ),
          "handle"            => fun_ref(
            method(:InterfacesHandleWrapper),
            "symbol (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:InterfacesValidateWrapper),
            "boolean (string, map)"
          )

        ),
        from: "map",
        to:   "map <string, any>"
      )

      deep_copy(ret)
    end

    # Display the firewall interfaces selection as a popup
    # @return [Symbol] return value of the dialog
    def DisplayDetailsPopup(settings)
      settings = deep_copy(settings)
      # FIXME: breaks help if run in dialog with Tab!!!!!!
      # settings stack must be created in CWM::Run
      w = CWM.CreateWidgets(
        ["firewall_ifaces"],
        "firewall_ifaces" => CreateInterfacesWidget(settings)
      )
      contents = VBox(
        "firewall_ifaces",
        ButtonBox(
          PushButton(Id(:ok), Opt(:okButton, :key_F10), Label.OKButton),
          PushButton(
            Id(:cancel),
            Opt(:cancelButton, :key_F9),
            Label.CancelButton
          )
        )
      )
      contents = CWM.PrepareDialog(contents, w)
      UI.OpenDialog(contents)
      ret = CWM.Run(w, {})
      UI.CloseDialog
      ret
    end

    # firewall openning widget

    # Initialize the open firewall widget
    # @param [Hash{String => Object}] widget a map describing the whole widget
    def OpenFirewallInit(widget, _key)
      widget = deep_copy(widget)
      if !UI.WidgetExists(Id("_cwm_open_firewall"))
        Builtins.y2error("Firewall widget doesn't exist")
        return
      end
      services = Ops.get_list(widget, "services", [])
      InitAllInterfacesList()

      begin
        InitAllowedInterfaces(services)
      rescue SuSEFirewalServiceNotFound => e
        Report.Error(
          # TRANSLATORS: Error message, do not translate %{details}
          _("Error checking service status:\n%{details}") % { details: e.message }
        )
      end

      open_firewall = Ops.greater_than(Builtins.size(@allowed_interfaces), 0)
      firewall_enabled = SuSEFirewall.GetEnableService &&
        Ops.greater_than(Builtins.size(@all_interfaces), 0)
      if !firewall_enabled
        open_firewall = false
        UI.ChangeWidget(Id("_cwm_open_firewall"), :Enabled, false)
      end
      UI.ChangeWidget(Id("_cwm_open_firewall"), :Value, open_firewall)
      UpdateFirewallStatus()
      EnableOrDisableFirewallDetails()

      nil
    end

    # Store function of the widget
    # @param [String] key strnig the widget key
    # @param [Hash] event map that caused widget data storing
    def OpenFirewallStore(widget, _key, _event)
      widget = deep_copy(widget)
      if !UI.WidgetExists(Id("_cwm_open_firewall"))
        Builtins.y2error("Widget _cwm_open_firewall does not exist")
        return
      end
      services = Ops.get_list(widget, "services", [])

      begin
        StoreAllowedInterfaces(services)
      rescue SuSEFirewalServiceNotFound => e
        Report.Error(
          # TRANSLATORS: Error message, do not translate %{details}
          _("Error setting service status:\n%{details}") % { details: e.message }
        )
      end

      nil
    end

    # Handle the immediate start and stop of the service
    # @param [Hash{String => Object}] widget a map describing the widget
    # @param [String] key strnig the widget key
    # @param event_id any the ID of the occurred event
    # @return always nil
    def OpenFirewallHandle(widget, _key, event)
      widget = deep_copy(widget)
      event = deep_copy(event)
      event_id = Ops.get(event, "ID")
      if event_id == "_cwm_firewall_details"
        handle_firewall_details = Convert.convert(
          Ops.get(widget, "firewall_details_handler"),
          from: "any",
          to:   "symbol ()"
        )
        Builtins.y2milestone("FD: %1", handle_firewall_details)
        ret = nil
        Builtins.y2milestone("RT: %1", ret)
        if !handle_firewall_details.nil?
          ret = handle_firewall_details.call
        else
          w = Builtins.filter(widget) { |k, _v| "services" == k }
          DisplayDetailsPopup(w)
        end
        UpdateFirewallStatus()
        EnableOrDisableFirewallDetails()
        return ret
      end
      if event_id == "_cwm_open_firewall"
        value = Convert.to_boolean(
          UI.QueryWidget(Id("_cwm_open_firewall"), :Value)
        )
        Builtins.y2milestone("OF: %1", value)
        if value
          @allowed_interfaces = deep_copy(@all_interfaces)
        else
          @allowed_interfaces = []
        end

        @buggy_ifaces = []
        # Checks whether it's possible to enable or disable the service for all interfaces
        # opens a popup message when needed
        if !CheckPossbilityToChangeFirewall(value)
          # change the checkbox state back
          UI.ChangeWidget(Id("_cwm_open_firewall"), :Value, !value)
        end
        # Filtering out buggy ifaces
        Builtins.foreach(@buggy_ifaces) do |one_iface|
          @allowed_interfaces = Builtins.filter(@allowed_interfaces) do |one_allowed|
            one_allowed != one_iface
          end
        end

        UpdateFirewallStatus()
        EnableOrDisableFirewallDetails()
        @configuration_changed = true
      end
      nil
    end

    # Init function of the widget
    # @param [String] key strnig the widget key
    def OpenFirewallInitWrapper(key)
      OpenFirewallInit(CWM.GetProcessedWidget, key)

      nil
    end

    # Store function of the widget
    # @param [String] key strnig the widget key
    # @param [Hash] event map that caused widget data storing
    def OpenFirewallStoreWrapper(key, event)
      event = deep_copy(event)
      OpenFirewallStore(CWM.GetProcessedWidget, key, event)

      nil
    end

    # Handle the immediate start and stop of the service
    # @param [String] key strnig the widget key
    # @param event_id any the ID of the occurred event
    # @return always nil
    def OpenFirewallHandleWrapper(key, event)
      event = deep_copy(event)
      OpenFirewallHandle(CWM.GetProcessedWidget, key, event)
    end

    # Check if the widget was modified
    # @param [String] key strnig the widget key
    # @return [Boolean] true if widget was modified
    def OpenFirewallModified(_key)
      @configuration_changed
    end

    # Enable the whole firewal widget
    # @param key strnig the widget key
    def EnableOpenFirewallWidget
      return if !UI.WidgetExists(Id("_cwm_open_firewall"))
      return if !UI.WidgetExists(Id("_cwm_firewall_details"))
      UI.ChangeWidget(Id("_cwm_open_firewall"), :Enabled, true)
      EnableOrDisableFirewallDetails()

      nil
    end

    # Disable the whole firewal widget
    # @param key strnig the widget key
    def DisableOpenFirewallWidget
      return if !UI.WidgetExists(Id("_cwm_open_firewall"))
      return if !UI.WidgetExists(Id("_cwm_firewall_details"))
      UI.ChangeWidget(Id("_cwm_open_firewall"), :Enabled, false)
      UI.ChangeWidget(Id("_cwm_firewall_details"), :Enabled, false)

      nil
    end

    # Check whether the whole firewall widget ( open port checkbox
    # and fw details button) exists
    # @return [Boolean] true if both widgets exist
    def OpenFirewallWidgetExists
      UI.WidgetExists(Id("_cwm_open_firewall")) &&
        UI.WidgetExists(Id("_cwm_firewall_details"))
    end
    # Get the template for the help text to the firewall opening widget
    # @param [Boolean] restart_displayed shold be true if "Save and restart" is displayed
    # @return [String] help text template with %1 and %2 placeholders
    def OpenFirewallHelpTemplate(restart_displayed)
      # help text for firewall settings widget 1/3,
      # %1 is check box label, eg. "Open Port in Firewall" (without quotes)
      help = _(
        "<p><b><big>Firewall Settings</big></b><br>\n" \
          "To open the firewall to allow access to the service from remote computers,\n" \
          "set <b>%1</b>.<br>"
      )
      if restart_displayed
        # help text for firewall port openning widget 2/3, optional
        # %1 is push button label, eg. "Firewall &Details" (without quotes)
        # note: %2 is correct, do not replace with %1!!!
        help = Ops.add(
          help,
          _(
            "To select interfaces on which to open the port,\nclick <b>%2</b>.<br>"
          )
        )
      end
      # help text for firewall settings widget 3/3,
      help = Ops.add(
        help,
        _("This option is available only if the firewall\nis enabled.</p>")
      )
      help
    end

    # Get the help text to the firewall opening widget
    # @param [Boolean] restart_displayed shold be true if "Save and restart" is displayed
    # @return [String] help text
    def OpenFirewallHelp(restart_displayed)
      Builtins.sformat(
        OpenFirewallHelpTemplate(restart_displayed),
        # part of help text - check box label, NO SHORTCUT!!!
        _("Open Port in Firewall"),
        # part of help text - push button label, NO SHORTCUT!!!
        _("Firewall Details")
      )
    end

    # Get the widget description map of the firewall enablement widget
    # @param [Hash{String => Object}] settings a map of all parameters needed to create the widget properly
    # <pre>
    #
    # - "services" : list<string> -- services identifications for the Firewall.ycp
    #          module
    # - "display_details" : boolean -- true if the details button should be
    #          displayed
    # - "firewall_details_handler" : symbol () -- function to handle the firewall
    #          details button. If returns something else than nil, dialog is
    #          exited with the returned symbol as value for wizard sequencer.
    #          If not specified, but "display_details" is true, common popup
    #          is used.
    # - "open_firewall_checkbox" : string -- label of the check box
    # - "firewall_details_button" : string -- label of the push button for
    #          changing firewall details
    # - "help" : string -- help to the widget. If not specified, generic help
    #          is used
    # </pre>
    # @return [Hash] the widget description map
    def CreateOpenFirewallWidget(settings)
      settings = deep_copy(settings)
      help = ""
      # check box

      open_firewall_checkbox = Ops.get_locale(
        settings,
        "open_firewall_checkbox",
        _("Open Port in &Firewall")
      )
      # push button

      firewall_details_button = Ops.get_locale(
        settings,
        "firewall_details_button",
        _("Firewall &Details...")
      )

      display_firewall_details = Builtins.haskey(
        settings,
        "firewall_details_handler"
      ) ||
        Ops.get_boolean(settings, "display_details", false)
      if Builtins.haskey(settings, "help")
        help = Ops.get_string(settings, "help", "")
      else
        help = OpenFirewallHelp(display_firewall_details)
      end

      firewall_settings = CheckBox(
        Id("_cwm_open_firewall"),
        Opt(:notify),
        open_firewall_checkbox
      )
      if display_firewall_details
        firewall_settings = HBox(
          firewall_settings,
          HSpacing(2),
          PushButton(Id("_cwm_firewall_details"), firewall_details_button)
        )
      end
      firewall_settings = VBox(
        Frame(
          _("Firewall Settings for %{firewall}") % { firewall: SuSEFirewall.firewall_service },
          VBox(
            Left(firewall_settings),
            Left(
              ReplacePoint(
                Id(:_cwm_firewall_status_rp),
                # label text
                Label(_("Firewall is open"))
              )
            )
          )
        )
      )

      if !Builtins.haskey(settings, "services")
        firewall_settings = VBox()
        help = ""
        Builtins.y2error("Firewall services not specified")
      end

      ret = Convert.convert(
        Builtins.union(
          {
            "widget"        => :custom,
            "custom_widget" => firewall_settings,
            "help"          => help,
            "init"          => fun_ref(
              method(:OpenFirewallInitWrapper),
              "void (string)"
            ),
            "store"         => fun_ref(
              method(:OpenFirewallStoreWrapper),
              "void (string, map)"
            ),
            "handle"        => fun_ref(
              method(:OpenFirewallHandleWrapper),
              "symbol (string, map)"
            ),
            "handle_events" => ["_cwm_firewall_details", "_cwm_open_firewall"]
          },
          settings
        ),
        from: "map",
        to:   "map <string, any>"
      )

      deep_copy(ret)
    end

    # Check if settings were modified by the user
    # @return [Boolean] true if settings were modified
    def Modified
      SuSEFirewall.GetModified
    end

    publish function: :InitAllowedInterfaces, type: "void (list <string>)"
    publish function: :StoreAllowedInterfaces, type: "void (list <string>)"
    publish function: :InterfacesInit, type: "void (map <string, any>, string)"
    publish function: :InterfacesHandle, type: "symbol (map <string, any>, string, map)"
    publish function: :InterfacesStore, type: "void (map <string, any>, string, map)"
    publish function: :InterfacesValidate, type: "boolean (map <string, any>, string, map)"
    publish function: :InterfacesInitWrapper, type: "void (string)"
    publish function: :InterfacesHandleWrapper, type: "symbol (string, map)"
    publish function: :InterfacesStoreWrapper, type: "void (string, map)"
    publish function: :InterfacesValidateWrapper, type: "boolean (string, map)"
    publish function: :CreateInterfacesWidget, type: "map <string, any> (map <string, any>)"
    publish function: :DisplayDetailsPopup, type: "symbol (map <string, any>)"
    publish function: :OpenFirewallInit, type: "void (map <string, any>, string)"
    publish function: :OpenFirewallStore, type: "void (map <string, any>, string, map)"
    publish function: :OpenFirewallHandle, type: "symbol (map <string, any>, string, map)"
    publish function: :OpenFirewallInitWrapper, type: "void (string)"
    publish function: :OpenFirewallStoreWrapper, type: "void (string, map)"
    publish function: :OpenFirewallHandleWrapper, type: "symbol (string, map)"
    publish function: :OpenFirewallModified, type: "boolean (string)"
    publish function: :EnableOpenFirewallWidget, type: "void ()"
    publish function: :DisableOpenFirewallWidget, type: "void ()"
    publish function: :OpenFirewallWidgetExists, type: "boolean ()"
    publish function: :OpenFirewallHelpTemplate, type: "string (boolean)"
    publish function: :OpenFirewallHelp, type: "string (boolean)"
    publish function: :CreateOpenFirewallWidget, type: "map <string, any> (map <string, any>)"
    publish function: :Modified, type: "boolean ()"
  end

  CWMFirewallInterfaces = CWMFirewallInterfacesClass.new
  CWMFirewallInterfaces.main
end
