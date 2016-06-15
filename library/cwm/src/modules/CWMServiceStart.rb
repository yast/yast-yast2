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
# File:	modules/CWMServiceStart.ycp
# Package:	Common widget manipulation, service start widget
# Summary:	Routines for service start widget handling
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
require "yast"

module Yast
  class CWMServiceStartClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "CWM"
      Yast.import "Mode"
      Yast.import "ProductFeatures"
      Yast.import "Service"

      # private variables

      # Label saying that service is running
      @service_is_running = ""

      # Label saying that service is stopped
      @service_is_stopped = ""

      # Last status of the service
      @last_status = nil
    end

    # private functions

    # Update the displayed status of the service
    # @param [Hash{String => Object}] widget a map describing the widget
    def UpdateServiceStatusWidget(widget)
      widget = deep_copy(widget)
      return if !UI.WidgetExists(Id("_cwm_service_status_rp"))
      if Mode.config
        UI.ChangeWidget(Id("_cwm_start_service_now"), :Enabled, false)
        UI.ChangeWidget(Id("_cwm_stop_service_now"), :Enabled, false)
        # service status - label
        UI.ReplaceWidget(Id("_cwm_service_status_rp"), Label(_("Unavailable")))
      else
        status = 0 == Service.Status(Ops.get_string(widget, "service_id", ""))
        if status != @last_status
          UI.ChangeWidget(Id("_cwm_start_service_now"), :Enabled, !status)
          UI.ChangeWidget(Id("_cwm_stop_service_now"), :Enabled, status)
          UI.ReplaceWidget(
            Id("_cwm_service_status_rp"),
            Label(status ? @service_is_running : @service_is_stopped)
          )
          @last_status = status
        end
      end

      nil
    end

    # Update the widget displaying if LDAP support is active
    # @param [Hash{String => Object}] widget a map describing the widget
    def UpdateLdapWidget(widget)
      widget = deep_copy(widget)
      return if !UI.WidgetExists(Id("_cwm_use_ldap"))
      get_use_ldap = Convert.convert(
        Ops.get(widget, "get_use_ldap"),
        from: "any",
        to:   "boolean ()"
      )
      use_ldap = get_use_ldap.call
      UI.ChangeWidget(Id("_cwm_use_ldap"), :Value, use_ldap)

      nil
    end

    # Handle the "Use LDAP" check box
    # @param [Hash{String => Object}] widget a map describing the widget
    # param event_id any the ID of the occurred event
    def HandleLdap(widget, event_id)
      widget = deep_copy(widget)
      event_id = deep_copy(event_id)
      if event_id == "_cwm_use_ldap"
        set_use_ldap = Convert.convert(
          Ops.get(widget, "set_use_ldap"),
          from: "any",
          to:   "void (boolean)"
        )
        use_ldap = Convert.to_boolean(
          UI.QueryWidget(Id("_cwm_use_ldap"), :Value)
        )
        set_use_ldap.call(use_ldap)
        UpdateLdapWidget(widget)
      end

      nil
    end

    # public functions

    # automatic service start-up related functions

    # Init function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    def AutoStartInit(widget, _key)
      widget = deep_copy(widget)
      if !UI.WidgetExists(Id("_cwm_service_startup"))
        Builtins.y2error("Widget _cwm_service_startup does not exist")
        return
      end
      get_auto_start = Convert.convert(
        Ops.get(widget, "get_service_auto_start"),
        from: "any",
        to:   "boolean ()"
      )
      auto_start = get_auto_start.call
      UI.ChangeWidget(
        Id("_cwm_service_startup"),
        :CurrentButton,
        auto_start ? "_cwm_startup_auto" : "_cwm_startup_manual"
      )
      if Builtins.haskey(widget, "get_service_start_via_xinetd")
        start_via_xinetd = Convert.convert(
          Ops.get(widget, "get_service_start_via_xinetd"),
          from: "any",
          to:   "boolean ()"
        )
        if start_via_xinetd.call
          UI.ChangeWidget(
            Id("_cwm_service_startup"),
            :CurrentButton,
            "_cwm_startup_xinetd"
          )
        end
      end

      nil
    end

    # Store function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    # @param [Hash] event map that caused widget data storing
    def AutoStartStore(widget, _key, _event)
      widget = deep_copy(widget)
      if !UI.WidgetExists(Id("_cwm_service_startup"))
        Builtins.y2error("Widget _cwm_service_startup does not exist")
        return
      end

      auto_start = UI.QueryWidget(Id("_cwm_service_startup"), :CurrentButton) ==
        "_cwm_startup_auto"

      set_auto_start = Convert.convert(
        Ops.get(widget, "set_service_auto_start"),
        from: "any",
        to:   "void (boolean)"
      )
      set_auto_start.call(auto_start)
      if !auto_start && Builtins.haskey(widget, "set_service_start_via_xinetd")
        start_via_xinetd = Convert.convert(
          Ops.get(widget, "set_service_start_via_xinetd"),
          from: "any",
          to:   "void (boolean)"
        )
        start_via_xinetd.call(
          UI.QueryWidget(Id("_cwm_service_startup"), :CurrentButton) ==
            "_cwm_startup_xinetd"
        )
      end

      nil
    end

    # Init function of the widget
    # @param [String] key strnig the widget key
    def AutoStartInitWrapper(key)
      AutoStartInit(CWM.GetProcessedWidget, key)

      nil
    end

    # Store function of the widget
    # @param [String] key strnig the widget key
    # @param [Hash] event map that caused widget data storing
    def AutoStartStoreWrapper(key, event)
      event = deep_copy(event)
      AutoStartStore(CWM.GetProcessedWidget, key, event)

      nil
    end

    # Get the template for the help text to the auto start widget
    # @return [String] help text template with %1 and %2 placeholders
    def AutoStartHelpTemplate
      # help text for service auto start widget
      # %1 and %2 are button labels
      # %1 is eg. "On -- Start Service when Booting"
      # %2 is eg. "Off -- Start Service Manually"
      # (both without quotes)
      _(
        "<p><b><big>Service Start</big></b><br>\n" \
          "To start the service every time your computer is booted, set\n" \
          "<b>%1</b>. Otherwise set <b>%2</b>.</p>"
      )
    end

    # Get the template for the help text to the auto start widget
    # @return [String] help text template with %1 and %2 placeholders
    def AutoStartHelpXinetdTemplate
      # help text for service auto start widget
      # %1, %2 and %3 are button labels
      # %1 is eg. "On -- Start Service when Booting"
      # %2 is eg. "Off -- Start Service Manually"
      # %3 is eg. "Start Service via xinetd"
      # (both without quotes)
      _(
        "<p><b><big>Service Start</big></b><br>\n" \
          "To start the service every time your computer is booted, set\n" \
          "<b>%1</b>. To start the service via the xinetd daemon, set <b>%3</b>.\n" \
          "Otherwise set <b>%2</b>.</p>"
      )
    end

    # Get the help text to the auto start widget
    # @return [String] help text
    def AutoStartHelp
      Builtins.sformat(
        AutoStartHelpTemplate(),
        # part of help text - radio button label, NO SHORTCUT!!!
        _("During Boot"),
        # part of help text - radio button label, NO SHORTCUT!!!
        _("Manually")
      )
    end

    # Get the help text to the auto start widget
    # @return [String] help text
    def AutoStartXinetdHelp
      Builtins.sformat(
        AutoStartHelpTemplate(),
        # part of help text - radio button label, NO SHORTCUT!!!
        _("During Boot"),
        # part of help text - radio button label, NO SHORTCUT!!!
        _("Manually"),
        # part of help text - radio button label, NO SHORTCUT!!!
        _("Via xinetd")
      )
    end

    # Get the widget description map of the widget for service auto starting
    # settings
    # @param [Hash{String => Object}] settings a map of all parameters needed to create the widget properly
    # <pre>
    #
    # - "get_service_auto_start" : boolean () -- function that returns if the
    #          service is set for automatical start-up
    # - "set_service_auto_start" : void (boolean) -- function that takes as
    #          an argument boolean value saying if the service is started
    #          automatically during booting
    # - "get_service_start_via_xinetd" : boolean () -- function that returns if
    #          the service is to be started via xinetd. At most one of this
    #          function and "get_service_auto_start" returns true (if started
    #          via xinetd, not starting automatically
    # - "set_service_start_via_xinetd" : void (boolean) - function that takes
    #          as an argument boolean value saying if the service is started
    #          via xinetd
    # - "start_auto_button" : string -- label of the radio button to start
    #          the service automatically when booting
    # - "start_xinetd_button" : string -- label of the radio button to start
    #          the service via xinetd
    # - "start_manual_button" : string -- label of the radio button to start
    #          the service only manually
    # - "help" : string -- custom help for the widget. If not specified, generic
    #          help is used
    #
    # </pre>
    # Additional settings:
    # - "help" : string -- help to the whole widget. If not specified, generic help
    #          is used (button labels are patched correctly)
    # </pre>
    # @return [Hash] the widget description map
    def CreateAutoStartWidget(settings)
      settings = deep_copy(settings)
      help = ""
      # radio button

      start_auto_button = Ops.get_locale(
        settings,
        "start_auto_button",
        _("During Boot")
      )
      # radio button

      start_manual_button = Ops.get_locale(
        settings,
        "start_manual_button",
        _("Manually")
      )
      # radio button

      start_xinetd_button = Ops.get_locale(
        settings,
        "start_xinetd_button",
        _("Via &xinetd")
      )
      xinetd_available = Builtins.haskey(
        settings,
        "get_service_start_via_xinetd"
      )
      help = if Builtins.haskey(settings, "help")
               Ops.get_string(settings, "help", "")
             else
               xinetd_available ? AutoStartXinetdHelp() : AutoStartHelp()
      end

      items = VBox(
        VSpacing(0.4),
        Left(
          RadioButton(Id("_cwm_startup_auto"), Opt(:notify), start_auto_button)
        )
      )
      if xinetd_available
        items = Builtins.add(
          items,
          Left(
            RadioButton(
              Id("_cwm_startup_xinetd"),
              Opt(:notify),
              start_xinetd_button
            )
          )
        )
      end
      items = Builtins.add(
        items,
        Left(
          RadioButton(
            Id("_cwm_startup_manual"),
            Opt(:notify),
            start_manual_button
          )
        )
      )
      items = Builtins.add(items, VSpacing(0.4))
      # Frame label (service starting)
      booting = VBox(
        # frame
        Frame(
          _("Service Start"),
          Left(RadioButtonGroup(Id("_cwm_service_startup"), items))
        )
      )

      if !(Builtins.haskey(settings, "set_service_auto_start") &&
          Builtins.haskey(settings, "get_service_auto_start"))
        booting = VBox()
        help = ""
      end

      ret = Convert.convert(
        Builtins.union(
          settings,

          "widget"        => :custom,
          "custom_widget" => booting,
          "help"          => help,
          "init"          => fun_ref(
            method(:AutoStartInitWrapper),
            "void (string)"
          ),
          "store"         => fun_ref(
            method(:AutoStartStoreWrapper),
            "void (string, map)"
          )

        ),
        from: "map",
        to:   "map <string, any>"
      )

      deep_copy(ret)
    end

    # service status and immediate actions related functions

    # Handle the immediate start and stop of the service
    # @param [Hash{String => Object}] widget a map describing the widget
    # @param [String] key strnig the widget key
    # @param event_id any the ID of the occurred event
    # @return always nil
    def StartStopHandle(widget, _key, event)
      widget = deep_copy(widget)
      event = deep_copy(event)
      event_id = Ops.get(event, "ID")
      if event_id == "_cwm_start_service_now"
        if Builtins.haskey(widget, "start_now_action")
          start_now_func = Convert.convert(
            Ops.get(widget, "start_now_action"),
            from: "any",
            to:   "void ()"
          )
          start_now_func.call
        else
          Service.Restart(Ops.get_string(widget, "service_id", ""))
        end
        Builtins.sleep(500)
      elsif event_id == "_cwm_stop_service_now"
        if Builtins.haskey(widget, "stop_now_action")
          stop_now_func = Convert.convert(
            Ops.get(widget, "stop_now_action"),
            from: "any",
            to:   "void ()"
          )
          stop_now_func.call
        else
          Service.Stop(Ops.get_string(widget, "service_id", ""))
        end
        Builtins.sleep(500)
      elsif event_id == "_cwm_save_settings_now"
        func = Convert.convert(
          Ops.get(widget, "save_now_action"),
          from: "any",
          to:   "void ()"
        )
        func.call
        Builtins.sleep(500)
      end
      UpdateServiceStatusWidget(widget)
      nil
    end

    # Init function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    def StartStopInit(widget, _key)
      widget = deep_copy(widget)
      @last_status = nil
      @service_is_running =
        # service status - label
        Ops.get_locale(widget, "service_running_label", _("Service is running"))
      @service_is_stopped =
        # service status - label
        Ops.get_locale(
          widget,
          "service_not_running_label",
          _("Service is not running")
        )
      UpdateServiceStatusWidget(widget)

      nil
    end

    # Handle the immediate start and stop of the service
    # @param [String] key strnig the widget key
    # @param event_id any the ID of the occurred event
    # @return always nil
    def StartStopHandleWrapper(key, event)
      event = deep_copy(event)
      StartStopHandle(CWM.GetProcessedWidget, key, event)
    end

    # Init function of the widget
    # @param [String] key strnig the widget key
    def StartStopInitWrapper(key)
      StartStopInit(CWM.GetProcessedWidget, key)

      nil
    end

    # Get the template for the help text to the start/stop widget
    # @param [Boolean] restart_displayed shold be true if "Save and restart" is displayed
    # @return [String] help text template with %1 and %2 placeholders
    def StartStopHelpTemplate(restart_displayed)
      # help text for service status displaying and switching  widget 1/2
      # %1 and %2 are push button labels
      # %1 is eg. "Start the Service Now"
      # %2 is eg. "Stop the Service Now"
      # (both without quotes)
      help = _(
        "<p><b><big>Switch On or Off</big></b><br>\n" \
          "To start or stop the service immediately, use \n" \
          "<b>%1</b> or <b>%2</b>.</p>"
      )
      if restart_displayed
        # help text for service start widget 2/2, optional
        # %3 is push button label, eg. "Save Changes and Restart Service Now"
        # (without quotes)
        # note: %3 is correct, do not replace with %1!!!
        help = Ops.add(
          help,
          _(
            "<p>To save all changes and restart the\nservice immediately, use <b>%3</b>.</p>\n"
          )
        )
      end
      help
    end

    # Get the help text to the start/stop widget
    # @param [Boolean] restart_displayed shold be true if "Save and restart" is displayed
    # @return [String] help text
    def StartStopHelp(restart_displayed)
      Builtins.sformat(
        StartStopHelpTemplate(restart_displayed),
        # part of help text - push button label, NO SHORTCUT!!!
        _("Start the Service Now"),
        # part of help text - push button label, NO SHORTCUT!!!
        _("Stop the Service Now"),
        # part of help text - push button label, NO SHORTCUT!!!
        _("Save Changes and Restart Service Now")
      )
    end

    # Get the widget description map for immediate service start/stop
    # and appropriate actions
    # @param [Hash{String => Object}] settings a map of all parameters needed to create the widget properly
    # <pre>
    #
    # - "service_id" : string -- service identifier for Service:: functions.
    #          If not specified, immediate actions buttons are not displayed.
    # - "save_now_action" : void () -- function that causes saving of all settings
    #          and restarting the service. If key is missing, the button
    #          is not displayed
    # - "start_now_action" : void () -- function that causes starting the service
    #          If not specified, generic function using "service_id" is used
    #          instead
    # - "stop_now_action" : void () -- function that causes stopping the service
    #          If not specified, generic function using "service_id" is used
    #          instead
    # - "service_running_label" : string -- label to be displayed if the service
    #          is running.
    # - "service_not_running_label" : string -- label to be displayed if the
    #          service is stopped.
    # - "start_now_button" : string -- label for the push button for immediate
    #          service start
    # - "stop_now_button" : string -- label for the push button for immediate
    #          service stop
    # - "save_now_button" : string -- label for the push button for immediate
    #          settings saving and service restarting
    # - "help" : string -- help to the widget. If not specified, generic help
    #          is used (button labels are patched correctly)
    # </pre>
    # @return [Hash] the widget description map
    def CreateStartStopWidget(settings)
      settings = deep_copy(settings)
      help = ""
      # push button for immediate service starting

      start_now_button = Ops.get_locale(
        settings,
        "start_now_button",
        _("&Start the Service Now")
      )
      # push button for immediate service stopping

      stop_now_button = Ops.get_locale(
        settings,
        "stop_now_button",
        _("S&top the Service Now")
      )

      save_now_button = Ops.get_locale(
        settings,
        "save_now_button",
        # push button for immediate saving of the settings and service starting
        _("S&ave Changes and Restart Service Now")
      )
      display_save_now = Builtins.haskey(settings, "save_now_action")

      help = if Builtins.haskey(settings, "help")
               Ops.get_string(settings, "help", "")
             else
               StartStopHelp(display_save_now)
      end

      save_now_button_term = if display_save_now
                               PushButton(
                                 Id("_cwm_save_settings_now"),
                                 Opt(:hstretch),
                                 save_now_button
                               )
                             else
                               VBox()
                             end

      immediate_actions = VBox(
        # Frame label (stoping starting service)
        Frame(
          _("Switch On and Off"),
          Left(
            HSquash(
              VBox(
                HBox(
                  # Current status
                  Label(_("Current Status: ")),
                  ReplacePoint(Id("_cwm_service_status_rp"), Label("")),
                  HStretch()
                ),
                PushButton(
                  Id("_cwm_start_service_now"),
                  Opt(:hstretch),
                  start_now_button
                ),
                PushButton(
                  Id("_cwm_stop_service_now"),
                  Opt(:hstretch),
                  stop_now_button
                ),
                save_now_button_term
              )
            )
          )
        )
      )

      if !Builtins.haskey(settings, "service_id")
        immediate_actions = VBox()
        help = ""
      end

      ret = Convert.convert(
        Builtins.union(
          settings,

          "widget"        => :custom,
          "custom_widget" => immediate_actions,
          "help"          => help,
          "init"          => fun_ref(
            method(:StartStopInitWrapper),
            "void (string)"
          ),
          "handle"        => fun_ref(
            method(:StartStopHandleWrapper),
            "symbol (string, map)"
          ),
          "handle_events" => [
            :timeout,
            "_cwm_start_service_now",
            "_cwm_stop_service_now",
            "_cwm_save_settings_now"
          ]

        ),
        from: "map",
        to:   "map <string, any>"
      )

      if Builtins.haskey(settings, "service_id")
        Ops.set(ret, "ui_timeout", 5000)
      end
      deep_copy(ret)
    end

    # ldap enablement widget

    # Init function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    def LdapInit(widget, _key)
      widget = deep_copy(widget)
      UpdateLdapWidget(widget)

      nil
    end

    # Handle function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    # @param [Hash] event map event to be handled
    # @return [Symbol] for wizard sequencer or nil
    def LdapHandle(widget, _key, event)
      widget = deep_copy(widget)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      if ret == "_cwm_use_ldap"
        HandleLdap(widget, ret)
        return nil
      end
      nil
    end

    # Init function of the widget
    # @param [String] key strnig the widget key
    def LdapInitWrapper(key)
      LdapInit(CWM.GetProcessedWidget, key)

      nil
    end

    # Handle function of the widget
    # @param map widget a widget description map
    # @param [String] key strnig the widget key
    # @param [Hash] event map event to be handled
    # @return [Symbol] for wizard sequencer or nil
    def LdapHandleWrapper(key, event)
      event = deep_copy(event)
      LdapHandle(CWM.GetProcessedWidget, key, event)
    end

    # Get the template for the help text to the LDAP enablement widget
    # @return [String] help text template with %1 and %2 placeholders
    def EnableLdapHelpTemplate
      # help text for LDAP enablement widget
      # %1 is button label, eg. "LDAP Support Active" (without quotes)
      _(
        "<p><b><big>LDAP Support</big></b><br>\n" \
          "To store the settings in LDAP instead of native configuration files,\n" \
          "set <b>%1</b>.</p>"
      )
    end

    # Get the help text to the LDAP enablement widget
    # @return [String] help text
    def EnableLdapHelp
      Builtins.sformat(
        EnableLdapHelpTemplate(),
        # part of help text - check box label, NO SHORTCUT!!!
        _("LDAP Support Active")
      )
    end

    # Get the widget description map of the LDAP enablement widget
    # TODO: Find a file to move to
    # @param [Hash{String => Object}] settings a map of all parameters needed to create the widget properly
    # <pre>
    #
    # LDAP support:
    # - "get_use_ldap" : boolean () -- function to return current status
    #          of the LDAP support. If not set, LDAP check-box is not shown.
    # - "set_use_ldap" : void (boolean) -- function to set the LDAP usage
    #          and report errors in case of fails. Status will be rechecked
    #          via "get_use_ldap". If not set, LDAP check-box is not shown.
    # - "use_ldap_checkbox" : string -- label of the chcek box to set if LDAP
    #          support is active.
    # - "help" : string -- help to the widget. If not specified, generic help
    #          is used (button labels are patched correctly)
    # </pre>
    # @return [Hash] the widget description map
    def CreateLdapWidget(settings)
      settings = deep_copy(settings)
      help = ""
      # check box

      use_ldap_checkbox = Ops.get_locale(
        settings,
        "use_ldap_checkbox",
        _("&LDAP Support Active")
      )
      help = if Builtins.haskey(settings, "help")
               Ops.get_string(settings, "help", "")
             else
               EnableLdapHelp()
      end

      # check box
      ldap_settings = VBox(
        VSpacing(1),
        Left(CheckBox(Id("_cwm_use_ldap"), Opt(:notify), use_ldap_checkbox))
      )

      if !(Builtins.haskey(settings, "get_use_ldap") &&
          Builtins.haskey(settings, "set_use_ldap"))
        ldap_settings = VBox()
        help = ""
      end

      ret = Convert.convert(
        Builtins.union(
          settings,

          "widget"        => :custom,
          "custom_widget" => ldap_settings,
          "help"          => help,
          "init"          => fun_ref(
            method(:LdapInitWrapper),
            "void (string)"
          ),
          "handle"        => fun_ref(
            method(:LdapHandleWrapper),
            "symbol (string, map)"
          ),
          "handle_events" => ["_cwm_use_ldap"]

        ),
        from: "map",
        to:   "map <string, any>"
      )

      deep_copy(ret)
    end

    publish function: :AutoStartInit, type: "void (map <string, any>, string)"
    publish function: :AutoStartStore, type: "void (map <string, any>, string, map)"
    publish function: :AutoStartInitWrapper, type: "void (string)"
    publish function: :AutoStartStoreWrapper, type: "void (string, map)"
    publish function: :AutoStartHelpTemplate, type: "string ()"
    publish function: :AutoStartHelpXinetdTemplate, type: "string ()"
    publish function: :AutoStartHelp, type: "string ()"
    publish function: :AutoStartXinetdHelp, type: "string ()"
    publish function: :CreateAutoStartWidget, type: "map <string, any> (map <string, any>)"
    publish function: :StartStopHandle, type: "symbol (map <string, any>, string, map)"
    publish function: :StartStopInit, type: "void (map <string, any>, string)"
    publish function: :StartStopHandleWrapper, type: "symbol (string, map)"
    publish function: :StartStopInitWrapper, type: "void (string)"
    publish function: :StartStopHelpTemplate, type: "string (boolean)"
    publish function: :StartStopHelp, type: "string (boolean)"
    publish function: :CreateStartStopWidget, type: "map <string, any> (map <string, any>)"
    publish function: :LdapInit, type: "void (map <string, any>, string)"
    publish function: :LdapHandle, type: "symbol (map <string, any>, string, map)"
    publish function: :LdapInitWrapper, type: "void (string)"
    publish function: :LdapHandleWrapper, type: "symbol (string, map)"
    publish function: :EnableLdapHelpTemplate, type: "string ()"
    publish function: :EnableLdapHelp, type: "string ()"
    publish function: :CreateLdapWidget, type: "map <string, any> (map <string, any>)"
  end

  CWMServiceStart = CWMServiceStartClass.new
  CWMServiceStart.main
end
