module Yast2
  # Class that represents widget that allows configuration of services.
  # It uses to hold configuration {Yast2::SystemService} or {Yast2::CompoundService}.
  # It can work with both and for usage it really depends if it should configure single
  # or multiple services
  #
  # @example usage of widget with workflow with read + propose + show_dialog + write
  #   class Workflow
  #     def initialize
  #       @service = Yast::SystemService.find("my_service")
  #     end
  #
  #     def propose
  #       @service.action = :restart
  #       @service.start_mode = :on_demand
  #     end
  #
  #     def show_dialog
  #       service_widget = ServiceWidget.new(@service)
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
  class ServiceWidget
    include Yast::I18n
    include Yast::Logger
    include Yast::UIShortcuts

    # creates new widget instance for given service
    # @param service_configuration [Yast2::SystemService,Yast2::CompoundService] service
    def initialize(service)
      textdomain "base"
      @service = service
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
              Label(" "),
              Label(status)
            )
          ),
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
      log.info "handle event #{event_id}"

      nil
    end

    # Stores current configuration. Should be called always even when going
    # back so configuration is persistent when going again forward.
    def store
      service.reset # so we start from scratch
      store_action
      store_autostart
    end

  private

    attr_reader :service

    def store_action
      action = Yast::UI.QueryWidget(Id(:service_widget_action), :CurrentItem)
      return unless action

      action = action.to_s.sub(/^service_widget_action_/, "").to_sym
      return if action == :nothing

      service.public_send(action)
    end

    def store_autostart
      autostart = Yast::UI.QueryWidget(Id(:service_widget_autostart), :CurrentItem)
      return unless autostart

      autostart = autostart.to_s.sub(/^service_widget_autostart_/, "").to_sym
      return if autostart == :inconsistent

      service.start_mode = autostart
    end

    def status
      case service.current_active?
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
        raise "Unknown status #{service.current_active?.inspect}"
      end
    end

    def action_widget
      ComboBox(
        Id(:service_widget_action),
        "After writting configuration:",
        action_items
      )
    end

    def action_items
      current_action = service.action
      res = []
      res << Item(Id(:service_widget_action_start), _("Start"), current_action == :start) if service.current_active? != true
      res << Item(Id(:service_widget_action_stop), _("Stop"), current_action == :stop) if service.current_active? != false
      res << Item(Id(:service_widget_action_restart), _("Restart"), current_action == :restart) if service.current_active? != true
      res << Item(Id(:service_widget_action_restart), _("Reload"), current_action == :reload) if service.current_active? != true && service.support_reload?
      res << Item(Id(:service_widget_action_nothing), _("Keep current state"), current_action.nil?)

      res
    end

    def autostart_widget
      ComboBox(
        Id(:service_widget_autostart),
        "After reboot:",
        autostart_items
      )
    end

    def autostart_items
      current_start_mode = service.start_mode
      system_start_mode = service.current_start_mode
      res = []

      res << Item(Id(:service_widget_autostart_on_boot), _("Start on boot"), current_start_mode == :on_boot)
      res << Item(Id(:service_widget_autostart_on_demand), _("Start on demand"), current_start_mode == :on_demand) if service.support_start_on_demand?
      res << Item(Id(:service_widget_autostart_manual), _("Do not start"), current_start_mode == :manual)
      res << Item(Id(:service_widget_autostart_inconsistent), _("Keep current settings"), current_start_mode == :inconsistent) if system_start_mode == :inconsistent

      res
    end
  end
end
