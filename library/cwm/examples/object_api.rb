# Simple example to demonstrate object API for CWM

require_relative "example_helper"

require "cwm/widget"

Yast.import "CWM"
Yast.import "Wizard"

class LuckyNumberWidget < CWM::IntField
  attr_reader :result, :minimum, :maximum

  def initialize
    @minimum = 0
    @maximum = 1000
    self.widget_id = "lucky_number"
  end

  def label
    _("Lucky number")
  end

  def store(_widget, _event)
    @result = value
  end
end

class GenerateButton < CWM::PushButtonWidget
  def initialize(lucky_number_widget)
    self.widget_id = "generate"
    @lucky_number_widget = lucky_number_widget
  end

  def label
    _("Generate Lucky Number")
  end

  def handle(widget, event)
    Yast::Builtins.y2milestone("handle called")
    @lucky_number_widget.value = rand(1000)

    nil
  end
end

module Yast
  class ExampleDialog
    include Yast::I18n
    include Yast::UIShortcuts
    def run
      textdomain "example"

      lucky_number_widget = LuckyNumberWidget.new
      button_widget = GenerateButton.new(lucky_number_widget)

      widgets = [lucky_number_widget, button_widget]

      contents = HBox(
        button_widget.widget_id,
        lucky_number_widget.widget_id
      )

      Yast::Wizard.CreateDialog
      CWM.ShowAndRun(
        "contents" => contents,
        "caption"  => _("Lucky number"),
        "widgets"  => widgets
      )
      Yast::Wizard.CloseDialog

      lucky_number_widget.result
    end
  end
end

Yast::ExampleDialog.new.run
