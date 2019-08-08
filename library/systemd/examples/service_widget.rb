require "yast"

require "yast2/service_widget"
require "yast2/system_service"
require "yast2/compound_service"

module Example
  extend Yast::UIShortcuts

  def self.service
    return @service if @service

    service1 = Yast2::SystemService.find!("cups.service")
    service2 = Yast2::SystemService.find!("dbus.service")

    # Yast2::ServiceWidget can be used with both, a Yast2::SystemService or
    # a Yast2::CompoundService
    @service = Yast2::CompoundService.new(service1, service2)
  end

  def self.service_widget
    @service_widget ||= Yast2::ServiceWidget.new(service)
  end

  def self.ui_loop
    Yast::UI.OpenDialog(HBox(service_widget.content))
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

Example.ui_loop
Example.write
