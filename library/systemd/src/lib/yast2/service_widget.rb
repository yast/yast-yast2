module Yast2
  # Class that represents widget that allows configuration of services.
  # It uses to hold configuration {Yast2::ServiceConfiguration}.
  #
  # @example usage of widget with workflow with read + propose + show_dialog + write
  #   class Workflow
  #     def initialize
  #       service = Yast::SystemdService.find!("my_service")
  #       @service_configuration = Yast2::ServiceConfiguration.new(service)
  #     end
  #
  #     def read
  #       @service_configuration.read
  #     end
  #
  #     def propose
  #       service_configuration.action = :restart
  #       service_configuration.autostart = :on_demand
  #     end
  #
  #     def show_dialog
  #       service_widget = ServiceWidget.new(@service_configuration)
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
  #       service_configuration.write
  #     end
  #   end
  class ServiceWidget
    include Yast::I18n
    include Yast::Logger
    include Yast::UIShortcuts
    # creates new widget instance for given service configuration
    # @param service_configuration [Yast2::ServiceConfiguration] configuration holder
    def initialize(service_configuration)
      textdomain "base"
      @service_configuration = service_configuration
    end

    # gets widget term
    # @return <Yast::Term>
    def content
      # TODO: disabling invalid action and autostart or kick it out?
      Frame(
        _("Service Configuration"),
        VBox(
          Left(HBox(
            Label(_("Current status:")),
            Label(" "),
            Label(status)
          )),
          Left(action_widget),
          Left(autostart_widget)
        )
      )
    end

    # handles event to dynamically react on user configuration.
    # For events that does not happen inside widget it is ignored.
    # @param event_id [Object] id of UI element that cause event
    # @return [void]
    def handle_input(event_id)
      nil
    end

    # Stores current configuration. Should be called always even when going
    # back so configuration is persistent when going again forward.
    def store
      store_action
      store_autostart
    end

  private

    attr_reader :service_configuration

    def store_action
      action = Yast::UI.QueryWidget(Id(:service_widget_action), :CurrentItem)
      return unless action

      service_configuration.action = action.to_s.sub(/^service_widget_action_/, "").to_sym
    end

    def store_autostart
      autostart = Yast::UI.QueryWidget(Id(:service_widget_autostart), :CurrentItem)
      return unless autostart

      service_configuration.autostart = autostart.to_s.sub(/^service_widget_autostart_/, "").to_sym
    end

    def status
      case service_configuration.status
      # TRANSLATORS: Status of service
      when :active
        _("Active")
      when :inactive
      # TRANSLATORS: Status of service
        _("Inactive")
      when :inconsistent
      # TRANSLATORS: Status of service
        _("Partly Active")
      when :unknown
      # TRANSLATORS: Status of service
        _("Unknown")
      else
        raise "Unknown status #{service_configuration.status.inspect}"
      end
    end

    def action_widget
      ComboBox(
        Id(:service_widget_action),
        "After writting settings:",
        action_items
      )
    end

    def action_items
      mixed = [:inconsistent, :unknown].include?(service_configuration.status)
      restart_label = mixed ? _("Restart active and start inactive") : _("Restart")
      reload_label = mixed ? _("Reload active and start inactive") : _("Reload")
      current_action = service_configuration.action
      [
        Item(Id(:service_widget_action_start), _("Ensure it is running"), current_action == :start),
        Item(Id(:service_widget_action_stop), _("Ensure it is stopped"), current_action == :stop),
        Item(Id(:service_widget_action_restart), restart_label, current_action == :restart),
        Item(Id(:service_widget_action_reload), reload_label, current_action == :reload),
        Item(Id(:service_widget_action_nothing), _("Nothing"), current_action == :nothing)
      ]
    end

    def autostart_widget
      ComboBox(
        Id(:service_widget_autostart),
        "Start Service Automatically:",
        autostart_items
      )
    end

    def autostart_items
      current_autostart = service_configuration.autostart
      keep = [:inconsistent, :unknown].include?(current_autostart)
      [
        Item(Id(:service_widget_autostart_on_boot), _("During boot"), current_autostart == :on_boot),
        Item(Id(:service_widget_autostart_on_demand), _("On demand"), current_autostart == :on_demand),
        Item(Id(:service_widget_autostart_manual), _("Never"), current_autostart == :manual),
        Item(Id(:service_widget_autostart_inconsistent), _("Do not change"), keep),
      ]
    end
  end
end
