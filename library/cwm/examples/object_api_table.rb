# Simple example to demonstrate object API Table for CWM

require_relative "example_helper"

require "cwm/table"

Yast.import "CWM"
Yast.import "Directory"
Yast.import "Wizard"

class NiceTable < CWM::Table
  def header
    [
      Center("name"),
      Right("surname"),
      "icon"
    ]
  end

  def items
    [
      [1, "Joe", "Doe",
       cell(icon(Yast::Directory.icondir + "/22x22/apps/yast-partitioning"))],
      [2, "Billy", "Kid", nil],
      [3, "Benny", nil, nil]
    ]
  end

  def init
    self.value = 3
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
      Yast.y2milestone("Selected item: #{table_widget.value.inspect}")
      Yast::Wizard.CloseDialog
    end
  end
end

Yast::ExampleDialog.new.run
