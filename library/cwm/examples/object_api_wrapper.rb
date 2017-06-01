# Simple example to demonstrate using wrapper for CWM

require_relative "example_helper"

require "cwm/widget"

Yast.import "CWM"
Yast.import "Wizard"
Yast.import "CWMFirewallInterfaces"

module Yast
  class ExampleDialog
    include Yast::I18n
    include Yast::UIShortcuts
    def run
      textdomain "example"

      contents = HBox(
        ::CWM::WrapperWidget.new(
          CWMFirewallInterfaces.CreateOpenFirewallWidget("services" => ["service:sshd", "service:ntp"]),
          id: "firewall"
        )
      )

      Yast::Wizard.CreateDialog
      CWM.show(contents, caption: _("Wrapper"))
      Yast::Wizard.CloseDialog
    end
  end
end

Yast::ExampleDialog.new.run
