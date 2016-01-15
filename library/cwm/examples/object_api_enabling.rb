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
  end

  def label
    _("Lucky number")
  end

  def store
    @result = value
  end
end

class EnableButton < CWM::PushButton
  def initialize(lucky_number_widget)
    @lucky_number_widget = lucky_number_widget
  end

  def disable_button=(val)
    @disable_button = val
  end

  def label
    _("Enable")
  end

  def init
    disable
  end

  def handle
    Yast::Builtins.y2milestone("enable handle called")
    @lucky_number_widget.enable
    @disable_button.enable
    disable

    nil
  end
end

class DisableButton < CWM::PushButton
  def initialize(lucky_number_widget)
    @lucky_number_widget = lucky_number_widget
  end

  def enable_button=(val)
    @enable_button = val
  end

  def label
    _("Disable")
  end

  def handle
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

      contents = HBox(
        enable_button_widget,
        disable_button_widget,
        lucky_number_widget
      )

      Yast::Wizard.CreateDialog
      CWM.show(contents, caption: _("Lucky number"))
      Yast::Wizard.CloseDialog

      lucky_number_widget.result
    end
  end
end

Yast::ExampleDialog.new.run
