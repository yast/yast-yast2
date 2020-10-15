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
       cell(icon("yast-partitioning"))],
      [2, "Billy", "Kid", nil],
      [3, "Benny", nil, nil]
    ]
  end

  def init
    self.value = 3
  end
end

class NestedTable < CWM::Table
  def header
    [
      "Device",
      "Size",
      "Type"
    ]
  end

  def items
    [
      CWM::TableItem.new(:sda, ["/dev/sda", "931.5G", "Disk"], children: sda_items),
      CWM::TableItem.new(:sdb, ["/dev/sdb", "900.0G", "Disk"]),
      [:sdc, "/dev/sdc", "521.5G", "Disk"],
      item(:sdd, ["/dev/sdd", "0.89T", "Disk"], children: sdd_items, open: false)
    ]
  end

private

  def sda_items
    [
      [:sda1, "sda1",  "97.7G", "Ntfs Partition"],
      [:sda2, "sda2",  "833.9G", "Ext4 Partition"]
    ]
  end

  def sdd_items
    [
      CWM::TableItem.new(:sdd1, ["sdd1", "0.89T", "BtrFS Partition"], children: sdd1_items)
    ]
  end

  def sdd1_items
    [
      item(:home, ["@/home", "", "BtrFS Subvolume"]),
      item(:opt, ["@/opt", "", "BtrFS Subvolume"])
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
      nested_table_widget = NestedTable.new

      contents = VBox(
        table_widget,
        nested_table_widget
      )

      Yast::Wizard.CreateDialog
      CWM.show(contents, caption: _("Table Example"))
      Yast.y2milestone("Selected item: #{table_widget.value.inspect}")
      Yast::Wizard.CloseDialog
    end
  end
end

Yast::ExampleDialog.new.run
