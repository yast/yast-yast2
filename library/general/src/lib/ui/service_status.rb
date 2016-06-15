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
Yast.import "UI"

module UI
  # Widgets for managing the status of services (both currently and on system
  # boot) and the behavior associated to those widgets
  #
  # As long as #handle_input is invoked in the event loop, the widget will
  # handle interactive starting and stopping of the service on user demand.
  #
  # It also provides checkboxes (reload_flag and enabled_flag) for the user
  # to specify whether the service must be reloaded/restarted after
  # configuration changes and whether it must be enabled at boot time.
  class ServiceStatus
    include Yast::UIShortcuts
    include Yast::I18n
    include Yast::Logger

    # @param service [Object] An object providing the following methods:
    #   #name, #start, #stop, #enabled?, #running?
    #   For systemd compliant services, just do
    #   Yast::SystemdService.find("name_of_the_service")
    #   Note that this widget will #start and #stop the service by itself but
    #   the actions referenced by the flags (reloading and enabling/disabling)
    #   are expected to be done by the caller, when the whole configuration is
    #   written.
    # @param reload_flag [Boolean] Initial value for the "reload" checkbox.
    #   Keep in mind it will always be displayed as unchecked if the service
    #   is not running, despite the real value.
    # @param reload_flag_label [Symbol] Type of label for the "reload" checkbox.
    #   :reload means the service will be reloaded.
    #   :restart means the service will be restarted.
    def initialize(service, reload_flag: true, reload_flag_label: :reload)
      @service = service
      @reload_flag = reload_flag

      @enabled_flag = @service.enabled?
      @id_prefix = "_srv_status_#{@service.name}"
      textdomain "base"
      @reload_label = if reload_flag_label == :restart
        _("Restart After Saving Settings")
                      else
        _("Reload After Saving Settings")
      end
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
    #
    # @return [Symbol] Label for the managed event
    def handle_input(input)
      case input
      when "#{id_prefix}_stop"
        @service.stop
        refresh
        :stop
      when "#{id_prefix}_start"
        @service.start
        refresh
        :start
      when "#{id_prefix}_reload"
        @reload_flag = Yast::UI.QueryWidget(Id(input), :Value)
        :reload_flag
      when "#{id_prefix}_enabled"
        @enabled_flag = Yast::UI.QueryWidget(Id(input), :Value)
        :enabled_flag
      else
        log.info "Input not handled by ServiceStatus: #{input}"
        :ignored
      end
    end

    # Updates the widget to reflect the current status of the service and the
    # settings
    def refresh
      Yast::UI.ChangeWidget(Id("#{id_prefix}_reload"), :Enabled, @service.running?)
      Yast::UI.ChangeWidget(Id("#{id_prefix}_reload"), :Value, @service.running? && @reload_flag)
      Yast::UI.ChangeWidget(Id("#{id_prefix}_enabled"), :Value, @enabled_flag)
      Yast::UI.ReplaceWidget(Id("#{id_prefix}_status"), status_widget)
    end

    # rubocop:disable Style/TrivialAccessors

    # Checks if the user requested the service to be enabled on boot
    #
    # @return [Boolean]
    def enabled_flag?
      @enabled_flag
    end

    # Checks if the user requested the service to be reloaded when saving
    #
    # @return [Boolean]
    def reload_flag?
      @reload_flag
    end

    # rubocop:enable Style/TrivialAccessors

    # Content for the help
    def help
      _(
        "<p><b><big>Current status</big></b><br>\n"\
        "Displays the current status of the service. The status will remain "\
        "the same after saving the settings, independently of the value of "\
        "'start service during boot'.</p>\n"\
        "<p><b><big>%{reload_label}</big></b><br>\n"\
        "Only applicable if the service is currently running. "\
        "Ensures the running service reloads the new configuration after "\
        "saving it (either finishing the dialog or pressing the apply "\
        "button).</p>\n"\
        "<p><b><big>Start During System Boot</big></b><br>\n"\
        "Check this field to enable the service at system boot. "\
        "Un-check it to disable the service. "\
        "This does not affect the current status of the service in the already "\
        "running system.</p>\n"
      ) % { reload_label: @reload_label }
    end

  protected

    attr_reader :id_prefix

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
          @enabled_flag
        )
      )
    end

    # Widget to configure reloading of the running service
    def reload_widget
      opts = [:notify]
      opts << :disabled unless @service.running?
      Left(
        CheckBox(
          Id("#{id_prefix}_reload"),
          Opt(*opts),
          @reload_label,
          @service.running? && @reload_flag
        )
      )
    end

    def label_and_action_widgets
      if @service.running?
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
