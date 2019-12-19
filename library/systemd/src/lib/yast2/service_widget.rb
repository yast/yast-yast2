# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"

Yast.import "UI"

module Yast2
  # Class that represents widget that allows configuration of services.
  # It uses to hold configuration {Yast2::SystemService} or {Yast2::CompoundService}.
  # It can work with both and for usage it really depends if it should configure single
  # or multiple services
  #
  # @example usage of widget with workflow with read + propose + show_dialog + write
  #   class Workflow
  #     def initialize
  #       @service = Yast2::SystemService.find("my_service")
  #     end
  #
  #     def propose
  #       # The default service widget action can be proposed by the current
  #       # service action
  #       @service.restart
  #       @service.start_mode = :on_demand
  #     end
  #
  #     def show_dialog
  #       service_widget = ServiceWidget.new(@service)
  #       # Or can be set by the service_widget
  #       service_widget.default_action = :reload if service.running?
  #
  #       content = VBox(
  #         ...,
  #         service_widget.content
  #       )
  #       loop do
  #         input = UI.UserInput
  #         service_widget.handle_input(input)
  #         ...
  #       end
  #       service_widget.store
  #     end
  #
  #     def write
  #       @service.save
  #     end
  #   end
  #
  # @todo Allow to specify the widget ID. Currently, it uses always the same, so you can not use
  #   more than one instance of this class at the same time.
  class ServiceWidget
    extend Yast::I18n
    include Yast::I18n
    include Yast::Logger
    include Yast::UIShortcuts

    # It stores the selected service action
    #
    # @return [Symbol] service action (:nothing for no action)
    # @see Yast2::SystemService#action
    attr_reader :current_action

    # creates new widget instance for given service
    # @param service [Yast2::SystemService,Yast2::CompoundService] service
    def initialize(service)
      textdomain "base"
      @service = service
      # When the service is active, by default, propose to reload or restart
      # it after writting the configuration (bsc#1158946)
      init_default_action
    end

    # Set the given action as the current action selected by the widget, when
    # no action is given it will not touch the service unless modified in the
    # selection list
    #
    # @param value [Symbol, nil] uses :nothing in case of no action given
    # @see Yast2::SystemService#action
    def default_action=(value)
      @current_action = value || :nothing
    end

    # gets widget term
    # @return <Yast::Term>
    def content
      Frame(
        _("Service Configuration"),
        VBox(
          Left(
            HBox(
              Label(_("Current status:")),
              HSpacing(1),
              Label(Id(:service_widget_status), Opt(:hstretch), status)
            )
          ),
          Left(action_widget),
          Left(autostart_widget)
        )
      )
    end

    # Updates the widget with current values of service
    #
    # Useful to update the information after certain actions like "Apply changes"
    #
    # @return [nil]
    def refresh
      Yast::UI.ChangeWidget(Id(:service_widget_status), :Value, status)
      Yast::UI.ChangeWidget(Id(:service_widget_action), :Items, action_items)
      Yast::UI.ChangeWidget(Id(:service_widget_autostart), :Items, autostart_items)
      nil
    end

    # handles event to dynamically react on user configuration.
    # For events that does not happen inside widget it is ignored.
    # @param event_id [Object] id of UI element that cause event
    # @return [nil] it returns nil as it should allow to continue dialog loop
    def handle_input(event_id)
      log.info "handle event #{event_id}"

      nil
    end

    # Stores current configuration. Should be called always before dialog close, even when going
    # back so configuration is persistent when going again forward.
    # @note it requires content of dialog to query, so cannot be called after DialogClose or if
    # another dialog is displayed instead of the one with {#content}
    def store
      service.reset # so we start from scratch
      store_action
      store_autostart
    end

    # Returns the service widget help text
    #
    # @return [String]
    def help
      # TRANSLATORS: helptext for the service current status, the header
      helptext = _("<h2>Service configuration</h2>")
      # TRANSLATORS: helptext for the service current status
      helptext += _(
        "<h3>Current status</h3>" \
        "Displays the curren status of the service."
      )

      # TRANSLATORS: helptext for the "After writting configuration" service widget option
      helptext += _(
        "<h3>After writing configuration</h3>" \
        "Allow to change the service status immediately after accepting the changes. Available
        options depend on the current state. The <b>Keep current state</b> special action leaves the
        service state untouched."
      )

      # TRANSLATORS: helptext for the "After reboot" service widget option
      helptext + _(
        "<h3>After reboot</h3>" \
        "Let choose if service should be started automatically on boot. Some services could be
        configured <b>on demand</b>, which means that the associated socket will be running and
        start the service if needed."
      )
    end

  private

    attr_reader :service

    # Initialize the default option for the service widget. It tries to use the
    # action from the service if set, if not, will propose :reload or :restart
    # when the service is active or do nothing in case of inactive.
    def init_default_action
      # For being compatible with the default action proposed by the service
      return self.default_action = service.action if service.action
      return self.default_action = :nothing unless service.currently_active?

      self.default_action = service.support_reload? ? :reload : :restart
    end

    def store_action
      action = Yast::UI.QueryWidget(Id(:service_widget_action), :Value)
      return unless action

      action = action.to_s.sub(/^service_widget_action_/, "").to_sym
      # Remember the selected option in case of refresh, specially if the
      # option was :reload or :restart it will be the same after applying the
      # changes and refreshing
      @current_action = action
      # We can return safely without modifying the service action as the
      # service should be reset before calling this method
      return if action == :nothing

      service.public_send(action)
    end

    def store_autostart
      autostart = Yast::UI.QueryWidget(Id(:service_widget_autostart), :Value)
      return unless autostart

      autostart = autostart.to_s.sub(/^service_widget_autostart_/, "").to_sym
      return if autostart == :inconsistent

      service.start_mode = autostart
    end

    def status
      case service.currently_active?
      # TRANSLATORS: Status of service
      when true
        _("Active")
      when false
        # TRANSLATORS: Status of service
        _("Inactive")
      when :inconsistent
        # TRANSLATORS: Status of service
        _("Partly Active")
      else
        raise "Unknown status #{service.currently_active?.inspect}"
      end
    end

    def action_widget
      ComboBox(
        Id(:service_widget_action),
        _("After writing configuration:"),
        action_items
      )
    end

    ACTION_LABEL =
      {
        start:   N_("Start"),
        stop:    N_("Stop"),
        reload:  N_("Reload"),
        restart: N_("Restart"),
        nothing: N_("Keep current state")
      }.freeze

    # Return whether the option given is supported and a valid one according
    # to the service status.
    #
    # @param value [Symbol] the current_action selected
    def valid_action?(value)
      actions.include?(value)
    end

    # Return the list of actions permitted and supported depending on the
    # current service status.
    def actions
      actions = service.currently_active? ? [:stop, :restart] : [:start]
      actions << :reload if service.currently_active? && service.support_reload?
      actions << :nothing
    end

    # @param value [Symbol]
    def action_item_id(value)
      Id("service_widget_action_#{value}".to_sym)
    end

    # @param value [Symbol]
    def action_label(value)
      _(ACTION_LABEL[value])
    end

    # When the cached action is valid, it returns if the current action is the
    # given action. If the cached option is invalid, then return true only if
    # the given action is for not touching the service
    #
    # @see valid_action?
    # @param value [Symbol]
    def selected_item?(value)
      if !valid_action?(current_action)
        value == :nothing
      else
        current_action == value
      end
    end

    # @param value [Symbol]
    # @return [Yast::Term] action Item
    def action_item(value)
      Item(action_item_id(value), action_label(value), selected_item?(value))
    end

    # @return [Array<Yast::Term>] list of action items
    def action_items
      actions.map { |a| action_item(a) }
    end

    def autostart_widget
      ComboBox(
        Id(:service_widget_autostart),
        _("After reboot:"),
        autostart_items
      )
    end

    def autostart_items
      current_start_mode = service.start_mode
      system_start_mode = service.current_start_mode
      res = []

      res << Item(Id(:service_widget_autostart_on_boot), _("Start on boot"), current_start_mode == :on_boot) if service.support_start_on_boot?
      res << Item(Id(:service_widget_autostart_on_demand), _("Start on demand"), current_start_mode == :on_demand) if service.support_start_on_demand?
      res << Item(Id(:service_widget_autostart_manual), _("Do not start"), current_start_mode == :manual)
      res << Item(Id(:service_widget_autostart_inconsistent), _("Keep current settings"), current_start_mode == :inconsistent) if system_start_mode == :inconsistent

      res
    end
  end
end
