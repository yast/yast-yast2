# typed: true
# Simple example to demonstrate service widget API for CWM

require_relative "example_helper"

require "cwm"
require "cwm/service_widget"
require "yast2/system_service"

Yast.import "CWM"
Yast.import "Wizard"
Yast.import "Popup"

module Yast
  class ExampleDialog
    include Yast::I18n
    include Yast::UIShortcuts
    def run
      textdomain "example"

      service = ::Yast2::SystemService.find("cups.service")
      service_widget = ::CWM::ServiceWidget.new(service)
      widgets = {
        "lucky_number_widget"    => {
          "widget" => :textentry,
          "label"  => _("Lucky Number")
        },
        "button_widget"          => {
          "widget" => :push_button,
          "label"  => "Generate Lucky Number"
        },
        service_widget.widget_id => service_widget.cwm_definition
      }

      contents = HBox(
        "button_widget",
        "lucky_number_widget",
        service_widget.widget_id
      )

      Yast::Wizard.CreateDialog
      CWM.ShowAndRun(
        "widget_names" => widgets.keys,
        "widget_descr" => widgets,
        "contents"     => contents,
        "caption"      => _("Lucky number")
      )
      Yast::Wizard.CloseDialog

      # service.save # do not call to avoid real system modification
    end
  end
end

Yast::ExampleDialog.new.run
