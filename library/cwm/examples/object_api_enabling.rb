# This example is here to demonstrate how can be widgets easily enabled/disabled from other widgets

require_relative "example_helper"

require "cwm/widget"

Yast.import "CWM"
Yast.import "Wizard"

class LuckyNumberWidget < CWM::IntField
  attr_reader :result, :minimum, :maximum

  def initialize
    @minimum = 0
    @maximum = 1000
    self.widget_id = "lucky_number_widget"
  end

  def label
    _("Lucky number")
  end

  def store(_widget, _event)
    @result = value
  end

  def handle(widget, event)
    return unless my_event?(widget, event)

    Yast::Builtins.y2milestone("int handle called")

    nil
  end
end

class EnableButton < CWM::PushButtonWidget
  def initialize(lucky_number_widget)
    self.widget_id = "enable"
    @lucky_number_widget = lucky_number_widget
  end

  def disable_button=(val)
    @disable_button = val
  end

  def label
    _("Enable")
  end

  def init(_widget)
    disable
  end

  def handle(widget, event)
    return unless my_event?(widget, event)

    Yast::Builtins.y2milestone("enable handle called")
    @lucky_number_widget.enable
    @disable_button.enable
    disable

    nil
  end
end

class DisableButton < CWM::PushButtonWidget
  def initialize(lucky_number_widget)
    self.widget_id = "disable"
    @lucky_number_widget = lucky_number_widget
  end

  def enable_button=(val)
    @enable_button = val
  end

  def label
    _("Disable")
  end

  def handle(widget, event)
    return unless my_event?(widget, event)

    Yast::Builtins.y2milestone("disable handle called")
    @lucky_number_widget.disable
    @enable_button.enable
    disable

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
      disable_button_widget = DisableButton.new(lucky_number_widget)
      enable_button_widget = EnableButton.new(lucky_number_widget)
      disable_button_widget.enable_button = enable_button_widget
      enable_button_widget.disable_button = disable_button_widget

      widgets = [lucky_number_widget, enable_button_widget, disable_button_widget]

      content = HBox(
        enable_button_widget.widget_id,
        disable_button_widget.widget_id,
        lucky_number_widget.widget_id
      )

      Yast::Wizard.CreateDialog
      CWM.ShowAndRun(
        "contents" => content,
        "caption"  => _("Lucky number"),
        "widgets"  => widgets
      )
      Yast::Wizard.CloseDialog

      lucky_number_widget.result
    end
  end
end

Yast::ExampleDialog.new.run
