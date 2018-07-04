require "yast"

require "yast2/service_widget"
require "yast2/service_configuration"
require "yast2/systemd_service"

def service
  @service ||= Yast2::Systemd::Service.find!("cups.service")
end

def service_configuration
  @service_configuration ||= Yast2::ServiceConfiguration.new(service)
end

def service_widget
  @service_widget ||= Yast2::ServiceWidget.new(service_configuration)
end

def read
  service_configuration.read
end

include Yast::UIShortcuts

def ui_loop
  Yast::UI.OpenDialog(Yast::HBox(service_widget.content))
  loop do
    input = Yast::UI.UserInput
    service_widget.handle_input(input)
    break if input == :cancel
  end
  service_widget.store
  Yast::UI.CloseDialog
end

def write
  # intentionally nothing
  true
end

read
ui_loop
write

nil
