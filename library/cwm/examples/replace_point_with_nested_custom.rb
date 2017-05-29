# Simple example to demonstrate object oriented replace_point widget

require_relative "example_helper"

require "yast"

require "cwm"

Yast.import "UI"
Yast.import "CWM"
Yast.import "Wizard"
Yast.import "Popup"

class SwitchWidget < CWM::PushButton
  def initialize(replace_point, widgets)
    @replace_point = replace_point
    @widgets = widgets
  end

  def label
    "Switch"
  end

  def handle
    @widgets.rotate!
    @replace_point.replace(@widgets.first)
  end
end

class PopupButtonWidget < CWM::PushButton
  def label
    "Popup"
  end

  def handle
    Yast::Popup.Message("Click!")
  end
end

class WrappedPopup < CWM::CustomWidget
  def contents
    VBox(
      PopupButtonWidget.new
    )
  end
end

class StoreWidget < CWM::InputField
  def label
    "write here"
  end

  def validate
    return true unless value.empty?

    Yast::Popup.Error("Empty value!")
    false
  end

  def store
    Yast::Popup.Message(value)
  end
end

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

class GenerateButton < CWM::PushButton
  def initialize(lucky_number_widget)
    @lucky_number_widget = lucky_number_widget
  end

  def label
    _("Generate Lucky Number")
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

widgets = [PopupButtonWidget.new, WrappedPopup.new, StoreWidget.new, Page.new]
replace_point = CWM::ReplacePoint.new(widget: widgets.first)

content = Yast::Term.new(:VBox,
  SwitchWidget.new(replace_point, widgets),
  replace_point)

Yast::Wizard.CreateDialog
Yast::CWM.show(content)
Yast::Wizard.CloseDialog
