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
  #       service_configuration.target_action = :restart
  #       service_configuration.target_autostart = :on_demand
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
    # creates new widget instance for given service configuration
    # @param services<Yast2::ServiceConfiguration> configuration holder
    def initialize(service_configuratin)
    end

    # gets widget term
    # @return <Yast::Term>
    def content
    end

    # handles event to dynamically react on user configuration.
    # For events that does not happen inside widget it is ignored.
    # @param event_id [Object] id of UI element that cause event
    def handle_input(event_id)
    end

    # Stores current configuration. Should be called always even when going
    # back so configuration is persistent when going again forward.
    def store
    end
  end
end
