# typed: true
# Simple example to demonstrate object oriented replace_point widget

require_relative "example_helper"

require "yast"

require "cwm"

Yast.import "UI"
Yast.import "CWM"
Yast.import "Wizard"

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

widgets = [PopupButtonWidget.new, CWM::Empty.new("empty"), StoreWidget.new]
replace_point = CWM::ReplacePoint.new(widget: widgets.first)

content = Yast::Term.new(:VBox,
  SwitchWidget.new(replace_point, widgets),
  replace_point)

Yast::Wizard.CreateDialog
Yast::CWM.show(content)
Yast::Wizard.CloseDialog
