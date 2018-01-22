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

# File:	modules/CWMFirewallInterfaces.ycp
# Package:	Common widget manipulation, firewall interfaces widget
# Summary:	Routines for selecting interfaces opened in firewall
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# WARNING: If you want to use this functionality of this module
#          you should allways call 'firewalld.read' in the
#          Read() function of you module
#          and you should call 'firewalld.write' in the
#          Write() function.
#
#	    Functionality of this module only changes the firewalld
#          settings in memory, it never Reads or Writes the settings.

require "yast"
require "y2firewall/firewalld"

module Yast
  class CWMFirewallInterfacesClass < Module
    include Yast::Logger

    # [Array<String>] List of all interfaces relevant for firewall settings
    attr_reader :allowed_interfaces
    # [Array<String>] List of all the system network interfaces
    attr_reader :all_interfaces

    # [Boolean] Information if configuration was changed by user
    attr_reader :configuration_changed

    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "NetworkInterfaces"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Stage"
      Yast.import "String"

      # private variables

      # List of all items of interfaces to the selection box
      @interface_items = nil

      @configuration_changed = false

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
      enabled = false if enabled.nil? || all_interfaces.empty?

      UI.ChangeWidget(Id("_cwm_firewall_details"), :Enabled, enabled)

      nil
    end

    # Set the firewall status label
    # @param [Symbol] status symbol one of `off, `closed, `open_all, `custom, `not_installed
    def SetFirewallLabel(status)
      label =
        case status
        when :not_installed
          # bnc #429861
          if Stage.initial
            # label
            _(
              "Firewall cannot be adjusted during first stage installation."
            )
          else
            # label
            _("Firewall package is not installed.")
          end
        when :off
          # label
          _("Firewall is disabled")
        when :closed
          # label
          _("Firewall port is closed")
        when :open_all
          # label
          _("Firewall port is open on all interfaces")
        when :custom
          # label
          _("Firewall port is open on selected interfaces")
        when :no_ifaces
          # label
          _("No network interfaces are configured")
        end

      UI.ReplaceWidget(Id(:_cwm_firewall_status_rp), Label(label))

      nil
    end

    # Initialize the list of all known interfaces
    def InitAllInterfacesList
      # Do not read NetworkInterfaces when they are already read
      if !Mode.config && !Mode.installation && !Mode.update
        log.info("Reading NetworkInterfaces...")
        NetworkInterfaces.Read
      end

      @all_interfaces = NetworkInterfaces.List("").reject { |i| i == "lo" }
      @interface_items = all_interfaces.map { |i| Item(Id(i), interface_label(i)) }

      nil
    end

    # Update the firewall status label according to the current status
    def UpdateFirewallStatus
      InitAllInterfacesList() if all_interfaces.nil?

      status = current_firewall_status
      log.info("Status: #{status}, All: #{all_interfaces}, Allowed: #{allowed_interfaces}")

      SetFirewallLabel(status)
      open = status == :open_all || status == :custom
      UI.ChangeWidget(Id("_cwm_open_firewall"), :Value, open)

      nil
    end

    # Get the list of all interfaces that will be selected
    #
    # @param [Array<String>] ifaces a list of interfaces selected by the user
    # @param [Boolean] _nm_ifaces_have_to_be_selected defines whether also NetworkManager have to be selected too
    # @return a list of interfaces that will be opened
    def Selected2Opened(ifaces, _nm_ifaces_have_to_be_selected)
      log.info("Selected ifaces: #{ifaces}")
      zone_names = ifaces.map { |i| interface_zone(i) || default_zone.name }.uniq
      log.info("Ifaces zone names: #{zone_names}")

      zone_ifaces =
        zone_names.map do |zone_name|
          zone = firewalld.find_zone(zone_name)
          next [] unless zone
          interfaces = zone.interfaces

          next(interfaces) unless zone_name == default_zone.name
          interfaces += default_interfaces

          left_explicitly = interfaces.select { |i| ifaces.include?(i) }.uniq
          log.info("Ifaces left in zone: #{left_explicitly}")

          next [] if left_explicitly.empty?

          interfaces
        end

      zone_ifaces.flatten.uniq
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
      service_status = {}

      services.each { |s| firewalld.find_service(s) }

      zone_services(services).each do |_s, status|
        status.each do |iface, en|
          service_status[iface] = service_status.fetch(iface, true) && en
        end
      end

      service_status.select! { |_iface, en| en == true }
      log.info("Status: #{service_status}")
      @allowed_interfaces = service_status.keys

      log.info "Default interfaces: #{default_interfaces}"
      log.info "Default_zone services: #{default_zone.services}"

      if !default_interfaces.empty?
        services.each do |service|
          service_status[firewalld.default_zone] =
            default_zone && default_zone.services.include?(service)
        end
        if service_status[firewalld.default_zone]
          @allowed_interfaces = (allowed_interfaces + default_interfaces).uniq
        end
      end

      log.info "Allowed interfaces: #{allowed_interfaces}"

      @configuration_changed = false

      nil
    end

    # Store the list of allowed interfaces
    # Users the internal variables
    # @param [Array<String>] services a list of services
    def StoreAllowedInterfaces(services)
      services = deep_copy(services)
      # do not save anything if configuration didn't change
      return if !configuration_changed

      zones =
        known_interfaces.each_with_object([]) do |known_interface, a|
          if allowed_interfaces.include?(known_interface["id"])
            a << known_interface["zone"] || default_zone.name
          end
        end

      firewalld.zones.map do |zone|
        if zones.include?(zone.name)
          services.map do |service|
            zone.add_service(service) unless zone.services.include?(service)
          end
        else
          services.map do |service|
            zone.remove_service(service) if zone.services.include?(service)
          end
        end
      end

      nil
    end

    # Init function of the widget
    # @param [Hash<String, Object>] _widget a widget description map
    # @param [String] _key strnig the widget key
    def InterfacesInit(_widget, _key)
      # set the list of ifaces
      InitAllInterfacesList() if all_interfaces.nil?
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
        allowed_interfaces
      )

      nil
    end

    # Handle function of the widget
    # @param [Hash<String, Object>] _widget a widget description map
    # @param [String] _key strnig the widget key
    # @param [Hash] event map event to be handled
    # @return [Symbol] for wizard sequencer or nil
    def InterfacesHandle(_widget, _key, event)
      event_id = Ops.get(event, "ID")
      if event_id == "_cwm_interface_select_all"
        UI.ChangeWidget(
          Id("_cwm_interface_list"),
          :SelectedItems,
          all_interfaces
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
    # @param [Hash<String, Object>] _widget a widget description map
    # @param [String] _key strnig the widget key
    # @param [Hash] _event map that caused widget data storing
    def InterfacesStore(_widget, _key, _event)
      allowed_interfaces = Convert.convert(
        UI.QueryWidget(Id("_cwm_interface_list"), :SelectedItems),
        from: "any",
        to:   "list <string>"
      )
      @allowed_interfaces = Selected2Opened(allowed_interfaces, false)
      @configuration_changed = true

      nil
    end

    # Validate function of the widget
    # @param [Hash<String, Object>] _widget a widget description map
    # @param [String] _key strnig the widget key
    # @param [Hash] _event map event that caused the validation
    # @return true if validation succeeded, false otherwise
    def InterfacesValidate(_widget, _key, _event)
      trusted_zone = firewalld.find_zone("trusted")

      ifaces = Convert.convert(
        UI.QueryWidget(Id("_cwm_interface_list"), :SelectedItems),
        from: "any",
        to:   "list <string>"
      ) || []

      log.info("Selected ifaces: #{ifaces}")

      trusted_interfaces = trusted_zone ? trusted_zone.interfaces : []

      if !trusted_interfaces.empty?
        int_not_selected = []
        trusted_interfaces.each do |interface|
          int_not_selected << interface unless ifaces.include?(interface)
        end

        if !int_not_selected.empty?
          log.warn("Unprotected internal interfaces not selected: #{int_not_selected}")

          Report.Message(
            Builtins.sformat(
              _(
                "These network interfaces assigned to internal network cannot be deselected:\n%1\n"
              ),
              int_not_selected.join("\n")
            )
          )

          ifaces = Convert.convert(
            Builtins.union(ifaces, int_not_selected),
            from: "list",
            to:   "list <string>"
          )
          log.info("Selected interfaces: #{ifaces}")
          UI.ChangeWidget(Id("_cwm_interface_list"), :SelectedItems, ifaces)
          return false
        end
      end

      if ifaces.empty?
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

      firewall_ifaces = Selected2Opened(ifaces, false)
      log.info("firewall_ifaces: #{firewall_ifaces}")
      added_ifaces = firewall_ifaces.select { |i| !ifaces.include?(i) }
      log.info("added_ifaces: #{added_ifaces}")
      removed_ifaces = ifaces.select { |i| !firewall_ifaces.include?(i) }
      log.info("removed_ifaces: #{removed_ifaces}")

      # to hide that special string
      if !added_ifaces.empty?
        if !Popup.YesNo(
          Builtins.sformat(
            # yes-no popup
            _(
              "Because of firewalld settings, the port\n" \
                "on the following interfaces will additionally be open:\n" \
                "%1\n" \
                "\n" \
                "Continue?"
            ),
            added_ifaces.join("\n")
          )
        )
          return false
        end
      end

      # to hide that special string
      if !removed_ifaces.empty?
        if !Popup.YesNo(
          Builtins.sformat(
            # yes-no popup
            _(
              "Because of firewalld settings, the port\n" \
                "on the following interfaces cannot be opened:\n" \
                "%1\n" \
                "\n" \
                "Continue?"
            ),
            removed_ifaces.join("\n")
          )
        )
          return false
        end
      end
      true
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
      return unless open_firewall_widget?

      services = widget.fetch("services", [])

      InitAllInterfacesList()
      InitAllowedInterfaces(services)

      open_firewall = !allowed_interfaces.empty?
      firewall_enabled = firewalld.enabled? && !all_interfaces.empty?
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
    # @param [Hash] widget widget description
    # @param [String] _key strnig the widget key
    # @param [Hash] _event map that caused widget data storing
    def OpenFirewallStore(widget, _key, _event)
      return unless open_firewall_widget?
      services = widget.fetch("services", [])
      StoreAllowedInterfaces(services)
      nil
    end

    # Handle the immediate start and stop of the service
    # @param [Hash<String, Object>] widget a map describing the widget
    # @param [String] _key strnig the widget key
    # @param [Hash<String, Object>] event event to handle
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
        @allowed_interfaces = value ? deep_copy(all_interfaces) : []

        @buggy_ifaces = []

        # Filtering out buggy ifaces
        Builtins.foreach(@buggy_ifaces) do |one_iface|
          @allowed_interfaces = Builtins.filter(allowed_interfaces) do |one_allowed|
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
    # @param [Hash<String, Object>] event to handle
    # @return always nil
    def OpenFirewallHandleWrapper(key, event)
      event = deep_copy(event)
      OpenFirewallHandle(CWM.GetProcessedWidget, key, event)
    end

    # Check if the widget was modified
    # @param [String] _key the widget key
    # @return [Boolean] true if widget was modified
    def OpenFirewallModified(_key)
      @configuration_changed
    end

    # Enable the whole firewal widget
    def EnableOpenFirewallWidget
      return if !UI.WidgetExists(Id("_cwm_open_firewall"))
      return if !UI.WidgetExists(Id("_cwm_firewall_details"))
      UI.ChangeWidget(Id("_cwm_open_firewall"), :Enabled, true)
      EnableOrDisableFirewallDetails()

      nil
    end

    # Disable the whole firewal widget
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
      services = settings.fetch("services", []) || []

      if services.empty?
        log.error("Firewall services not specified")
        return { "widget" => :custom, "custom_widget" => VBox() }
      end

      if services.any? { |s| !firewalld.api.service_supported?(s) }
        return { "widget" => :custom, "custom_widget" => services_not_defined_widget(services) }
      end

      open_firewall_checkbox =
        settings.fetch("open_firewall_checkbox", _("Open Port in &Firewall"))
      firewall_details_button =
        settings.fetch("firewall_details_button", _("Firewall &Details..."))
      display_firewall_details =
        settings.fetch("firewall_details_handler", settings.fetch("display_details", false))

      help = settings.fetch("help", OpenFirewallHelp(display_firewall_details))

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
          _("Firewall Settings for %{firewall}") % { firewall: Y2Firewall::Firewalld::SERVICE },
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
      }.merge(settings)
    end

    # Check if settings were modified by the user
    # @return [Boolean] true if settings were modified
    def Modified
      firewalld.modified?
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

  private

    # Return whether the '_cwm_open_firewall' widget exists or not logging the
    # error in case of non-existence.
    #
    # @return [Boolean] true if the open firewall widget exists
    def open_firewall_widget?
      unless UI.WidgetExists(Id("_cwm_open_firewall"))
        log.error("Widget _cwm_open_firewall does not exist")
        return false
      end

      true
    end

    # Return an instance of Y2Firewall::Firewalld
    #
    # @return [Y2Firewall::Firewalld] a firewalld instance
    def firewalld
      Y2Firewall::Firewalld.instance
    end

    # Return the current status of the firewall related to the interfaces
    # opened or available
    #
    # @return [Symbol] current firewall status
    def current_firewall_status
      # bnc #429861
      return :not_installed if Stage.initial || !firewalld.installed?
      return :off unless firewalld.enabled?
      return :no_ifaces if all_interfaces.empty?
      return :open_all if all_interfaces.size == allowed_interfaces.size
      return :closed if allowed_interfaces.empty?

      :custom
    end

    # Convenience method to return the default zone object
    #
    # @return [Y2Firewall::Firewalld::Zone] default zone
    def default_zone
      @default_zone ||= firewalld.find_zone(firewalld.default_zone)
    end

    # Return a hash of all the known interfaces with their "id", "name" and
    # "zone".
    #
    # @example
    #   CWMFirewallInterfaces.known_interfaces #=>
    #     [
    #       { "id" => "eth0", "name" => "Intel Ethernet Connection I217-LM", "zone" => "external"},
    #       { "id" => "eth1", "name" => "Intel Ethernet Connection I217-LM", "zone" => "public"},
    #       { "id" => "eth2", "name" => "Intel Ethernet Connection I217-LM", "zone" => nil},
    #       { "id" => "eth3", "name" => "Intel Ethernet Connection I217-LM", "zone" => nil},
    #     ]
    #
    # @return [Array<Hash<String,String>>] known interfaces "id", "name" and "zone"
    def known_interfaces
      return @known_interfaces if @known_interfaces

      interfaces = NetworkInterfaces.List("").reject { |i| i == "lo" }

      @known_interfaces = interfaces.map do |interface|
        {
          "id"   => interface,
          "name" => NetworkInterfaces.GetValue(interface, "NAME"),
          "zone" => interface_zone(interface)
        }
      end
    end

    # Return the name of interfaces which belongs to the default zone
    #
    # @return [Array<String>] default zone interface names
    def default_interfaces
      known_interfaces.select { |i| i["zone"].to_s.empty? }.map { |i| i["id"] }
    end

    # Return the zone name for a given interface from the firewalld instance
    # instead of from the API.
    #
    # @param name [String] interface name
    # @return [String, nil] zone name whether belongs to some or nil if not
    def interface_zone(name)
      zone = firewalld.zones.find { |z| z.interfaces.include?(name) }

      zone ? zone.name : nil
    end

    def zone_services(services)
      services_status = {}

      services.each do |service|
        service_supported = firewalld.api.service_supported?(service)
        services_status[service] = {}

        firewalld.zones.each do |zone|
          next if (zone.interfaces || []).empty?

          zone.interfaces.each do |interface|
            services_status[service][interface] =
              service_supported ? zone.services.include?(service) : nil
          end
        end
      end

      services_status
    end

    # Return the label to show for the given interface name
    #
    # @param name [String] interface name
    # @return [String] label for given interface name
    def interface_label(name)
      return name if Mode.config

      label = NetworkInterfaces.GetValue(name, "BOOTPROTO")
      ipaddr = NetworkInterfaces.GetValue(name, "IPADDR")
      # BNC #483455: Interface zone name
      zone = firewalld.zones.find { |z| z.interfaces.include?(name) }
      zone_full_name = zone ? zone.full_name : _("Interface is not assigned to any zone")
      if label == "static" || label == "" || label.nil?
        label = ipaddr
      else
        label.upcase!
        label << "/#{ipaddr}" if !ipaddr.nil? && ipaddr != ""
      end
      if label.nil? || label == ""
        name
      else
        "#{name} (#{label} / #{zone_full_name})"
      end
    end

    # Return a firewall widget with a list of the supported and unsupported
    # firewalld services.
    #
    # @return [Yast::Term] widget with a summary of services support
    def services_not_defined_widget(services)
      services_list =
        services.map do |service|
          if !firewalld.api.service_supported?(service)
            HBox(HSpacing(2), Left(Label(_("* %{service} (Not available)") % { service: service })))
          else
            HBox(HSpacing(2), Left(Label(_("* %{service}") % { service: service })))
          end
        end

      VBox(
        Frame(
          _("Firewall not configurable (missing services)"),
          VBox(
            Left(Label(_("Some firewalld services are not available:"))),
            *services_list,
            Left(Label(_("You need to defined them to be able to configure the firewall.")))
          )
        )
      )
    end
  end

  CWMFirewallInterfaces = CWMFirewallInterfacesClass.new
  CWMFirewallInterfaces.main
end
