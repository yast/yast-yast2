# Copyright (c) 2015 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact Novell about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "yast"
Yast.import "Service"
Yast.import "UI"

module UI
  # Component encapsulating the widgets for managing the status of services (both
  # currently and on system boot) and the behavior associated to those widgets
  #
  # As long as #handle_input is invoked in the event loop, the component will
  # handle interactive starting and stopping of the service on user demand. In
  # addition #reload can be used after saving the settings.
  #
  # To manage the status on boot, the component can be queried for the user
  # selection using #enabled?. In addition enabled_callback (in constructor)
  # can be used to observe the status of the corresponding field in the UI.
  class SrvStatusComponent
    include Yast::UIShortcuts
    include Yast::I18n
    include Yast::Logger

    # @param service_name [String] name of the service as expected by
    #   Yast::Service
    # @param reload [Boolean] initial value for the "reload" checkbox.
    #   Keep in mind it will always be displayed as unchecked if the service is
    #   not running, despite the real value.
    # @param enabled_callback [Proc] callback executed when the "enabled on
    #   boot" checkbox is changed. The only parameter of the callback is the new
    #   state of the checkbox (boolean).
    def initialize(service_name, reload: true, enabled_callback: nil)
      @service_name = service_name
      @reload = reload
      @enabled_callback = enabled_callback

      @enabled = service_enabled?
      @id_prefix = "_srv_status_#{@service_name}"
      textdomain "base"
    end

    # @return [YaST::Term]
    def widget
      Frame(
        _("Service Status"),
        VBox(
          ReplacePoint(Id("#{id_prefix}_status"), status_widget),
          reload_widget,
          VSpacing(),
          on_boot_widget
        )
      )
    end

    # Handles the input triggered by the widgets, this method must be called in
    # the event loop of the dialog using the component.
    def handle_input(input)
      case input
      when "#{id_prefix}_stop"
        stop_service
        refresh_widget
      when "#{id_prefix}_start"
        start_service
        refresh_widget
      when "#{id_prefix}_reload"
        @reload = Yast::UI.QueryWidget(Id(input), :Value)
      when "#{id_prefix}_enabled"
        @enabled = Yast::UI.QueryWidget(Id(input), :Value)
        @enabled_callback.call(@enabled) if @enabled_callback
      else
        log.info "Input not handled by SrvStatusComponent: #{input}"
      end
    end

    # Updates the widget to reflect the current status of the service and the
    # settings
    def refresh_widget
      Yast::UI.ChangeWidget(Id("#{id_prefix}_reload"), :Enabled, service_running?)
      Yast::UI.ChangeWidget(Id("#{id_prefix}_reload"), :Value, service_running? && @reload)
      Yast::UI.ChangeWidget(Id("#{id_prefix}_enabled"), :Value, @enabled)
      Yast::UI.ReplaceWidget(Id("#{id_prefix}_status"), status_widget)
    end

    # Reloads the service only if the user requested so. It should be called
    # after saving the settings.
    def reload
      reload_service if service_running? && @reload
    end

    # Checks if the user requested the service to be enabled on boot
    #
    # @return [Boolean]
    def enabled?
      @enabled
    end

    # Content for the help
    def help
      _(
        "<p><b><big>Current status</big></b><br>\n"\
        "Displays the current status of the service. The status will remain "\
        "the same after saving the settings, independently of the value of "\
        "'start service during boot'.</p>\n"\
        "<p><b><big>Reload After Saving Settings</big></b><br>\n"\
        "Only applicable if the service is currently running. "\
        "Ensures the running service reloads the new configuration after "\
        "saving it (via 'ok' or 'save' buttons).</p>\n"\
        "<p><b><big>Start During System Boot</big></b><br>\n"\
        "Check this field to enable the service at system boot. "\
        "Un-check it to disable the service. "\
        "This does not affect the current status of the service in the already "\
        "running system.</p>\n"
      )
    end

    protected

    attr_reader :id_prefix

    # Checks if the service is currently running
    #
    # Must be redefined for services not following standard procedures
    #
    # @return [Boolean]
    def service_running?
      Yast::Service.active?(@service_name)
    end

    # Checks if the service is currently enabled on boot
    #
    # Must be redefined for services not following standard procedures
    #
    # @return [Boolean]
    def service_enabled?
      Yast::Service.enabled?(@service_name)
    end

    # Starts the service inmediatly
    #
    # Must be redefined for services not following standard procedures
    def start_service
      log.info "Default implementation of SrvStatusComponent#start_service for #{@service_name}"
      Yast::Service.Start(@service_name)
    end

    # Stops the service inmediatly
    #
    # Must be redefined for services not following standard procedures
    def stop_service
      log.info "Default implementation of SrvStatusComponent#stop_service for #{@service_name}"
      Yast::Service.Stop(@service_name)
    end

    # Reloads the configuration of a running service
    #
    # Must be redefined for services not following standard procedures
    def reload_service
      log.info "Default implementation of SrvStatusComponent#reload_service for #{@service_name}"
      Yast::Service.Reload(@service_name)
    end

    # Widget displaying the status and associated buttons
    def status_widget
      Left(
        HBox(
          Label(_("Current status:")),
          Label(" "),
          *label_and_action_widgets
        )
      )
    end

    # Widget to configure the status on boot
    def on_boot_widget
      Left(
        CheckBox(
          Id("#{id_prefix}_enabled"),
          Opt(:notify),
          _("Start During System Boot"),
          @enabled
        )
      )
    end

    # Widget to configure reloading of the running service
    def reload_widget
      opts = [:notify]
      opts << :disabled unless service_running?
      Left(
        CheckBox(
          Id("#{id_prefix}_reload"),
          Opt(*opts),
          _("Reload After Saving Settings"),
          service_running? && @reload
        )
      )
    end

    def label_and_action_widgets
      if service_running?
        [
          # TRANSLATORS: status of a service
          Label(_("running")),
          Label(" "),
          PushButton(Id("#{id_prefix}_stop"), _("Stop now"))
        ]
      else
        [
          # TRANSLATORS: status of a service
          Label(_("stopped")),
          Label(" "),
          PushButton(Id("#{id_prefix}_start"), _("Start now"))
        ]
      end
    end
  end
end
