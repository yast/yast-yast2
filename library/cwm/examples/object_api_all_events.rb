# This example is here to demonstrate how can be widgets easily enabled/disabled from other widgets

require_relative "example_helper"

require "cwm"

Yast.import "CWM"
Yast.import "Wizard"

class DisplayWidget < CWM::InputField
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

class FirstButton < CWM::PushButton
  def initialize
    self.widget_id = "first button"
  end

  def label
    _("Choose the best first button")
  end
end

class SecondButton < CWM::PushButton
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

      contents = HBox(
        FirstButton.new,
        display_widget,
        SecondButton.new
      )

      Yast::Wizard.CreateDialog
      CWM.show(contents, caption: _("Lucky button"))
      Yast::Wizard.CloseDialog

      display_widget.result
    end
  end
end

Yast::ExampleDialog.new.run
