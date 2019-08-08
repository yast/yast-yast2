require "yast"

require "yast2/service_widget"
require "yast2/service_configuration"
require "yast2/systemd/service"
require "ui/service_status"

module Example
  extend Yast::UIShortcuts

  def self.service
    @service ||= Yast2::Systemd::Service.find!("cups.service")
  end

  def self.service_configuration
    @service_configuration ||= Yast2::ServiceConfiguration.new(service)
  end

  def self.service_widget
    @service_widget ||= Yast2::ServiceWidget.new(service_configuration)
  end

  def self.read
    service_configuration.read
  end

  def self.service_status
    @ss = UI::ServiceStatus.new(service)
  end

  def self.ui_loop
    Yast::UI.OpenDialog(
      HBox(
        service_widget.content,
        service_status.widget
      )
    )
    loop do
      input = Yast::UI.UserInput
      service_widget.handle_input(input)
      break if input == :cancel
    end
    service_widget.store
    Yast::UI.CloseDialog
  end

  def self.write
    # intentionally nothing
    true
  end
end

Example.read
Example.ui_loop
Example.write
