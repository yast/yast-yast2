# Simple example to demonstrate object API Table for CWM

require_relative "example_helper"

require "cwm/table"

Yast.import "CWM"
Yast.import "Wizard"

class NiceTable < CWM::Table
  def header
    [ "name", "surname" ]
  end

  def items
    [
      [1, "Joe", "Doe"],
      [2, "Billy", "Kid"],
      [3, "Benny", nil]
    ]
  end
end

module Yast
  class ExampleDialog
    include Yast::I18n
    include Yast::UIShortcuts
    def run
      textdomain "example"

      table_widget = NiceTable.new

      contents = HBox(
        table_widget
      )

      Yast::Wizard.CreateDialog
      CWM.show(contents, caption: _("Table Example"))
      Yast::Wizard.CloseDialog
    end
  end
end

Yast::ExampleDialog.new.run
