# This example is here to demonstrate how can be widgets easily enabled/disabled from other widgets

require_relative "example_helper"

require "cwm/widget"

Yast.import "CWM"
Yast.import "Wizard"

class DisplayWidget < CWM::InputFieldWidget
  attr_reader :result

  def initialize
    self.widget_id = "lucky_number_widget"
    self.handle_all_events = true
    disable
  end

  def label
    _("Lucky number")
  end

  def init
    self.value = "let's start"
  end

  def store
    @result = value
  end

  def opt
    [:notify]
  end

  def handle(event)
    return if event["ID"].to_s.start_with?("_") # underscored events is internal CWM events
    self.value = event["ID"]

    nil
  end
end

class FirstButton < CWM::PushButtonWidget
  def initialize
    self.widget_id = "first button"
  end

  def label
    _("Choose the best first button")
  end
end

class SecondButton < CWM::PushButtonWidget
  def initialize
    self.widget_id = "second button"
  end

  def label
    _("Choose the best second button")
  end
end

module Yast
  class ExampleDialog
    include Yast::I18n
    include Yast::UIShortcuts
    def run
      textdomain "example"

      display_widget = DisplayWidget.new
      first_button = FirstButton.new
      second_button = SecondButton.new

      widgets = [display_widget, first_button, second_button]

      contents = HBox(
        first_button.widget_id,
        display_widget.widget_id,
        second_button.widget_id
      )

      Yast::Wizard.CreateDialog
      CWM.ShowAndRun(
        "contents" => contents,
        "caption"  => _("Lucky number"),
        "widgets"  => widgets
      )
      Yast::Wizard.CloseDialog

      display_widget.result
    end
  end
end

Yast::ExampleDialog.new.run
