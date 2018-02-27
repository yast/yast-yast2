# Simple example to demonstrate object API for CWM

require_relative "example_helper"

require "cwm"

Yast.import "CWM"
Yast.import "Popup"
Yast.import "Wizard"

class LuckyNumberWidget < CWM::IntField
  attr_reader :result, :minimum, :maximum

  def initialize
    @minimum = 0
    @maximum = 1000
  end

  def label
    "Lucky number"
  end

  def store
    @result = value
  end
end

class GenerateButton < CWM::PushButton
  def initialize(lucky_number_widget)
    @lucky_number_widget = lucky_number_widget
  end

  def label
    "Generate Lucky Number"
  end

  def handle
    Yast::Builtins.y2milestone("handle called")
    @lucky_number_widget.value = rand(1000)

    nil
  end
end

class LuckyNumberGenerator < CWM::CustomWidget
  def contents
    HBox(
      button_widget,
      lucky_number_widget
    )
  end

  def result
    lucky_number_widget.result
  end

private

  def button_widget
    @button_widget ||= GenerateButton.new(lucky_number_widget)
  end

  def lucky_number_widget
    @lucky_number_widget ||= LuckyNumberWidget.new
  end
end

class Page < CWM::CustomWidget
  def contents
    VBox(
      lucky_number_generator,
      PushButton(Id(:rate_page), "Rate Pager")
    )
  end

  def handle
    Yast::Popup.Warning("Be honest")
  end

  def lucky_number_generator
    @lng = LuckyNumberGenerator.new
  end
end

module Yast
  class ExampleDialog
    include Yast::I18n
    include Yast::UIShortcuts
    include Yast::Logger
    def run
      generate_widget = Page.new

      contents = HBox(generate_widget)

      Yast::Wizard.CreateDialog
      CWM.show(contents, caption: "Lucky number")
      Yast::Wizard.CloseDialog
    end
  end
end

Yast::ExampleDialog.new.run
