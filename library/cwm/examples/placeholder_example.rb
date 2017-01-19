# Simple example to demonstrate object oriented placeholder widget

require_relative "example_helper"

require "yast"

require "cwm/widget"

Yast.import "UI"
Yast.import "CWM"
Yast.import "Wizard"

class SwitchWidget < CWM::PushButton
  def initialize(placeholder, widgets)
    @placeholder = placeholder
    @widgets = widgets
  end

  def label
    "Switch"
  end

  def handle
    @widgets.rotate!
    @placeholder.replace(@widgets.first)
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
    return false
  end

  def store
    Yast::Popup.Message(value)
  end
end

widgets = [ CWM::Empty.new(:empty), PopupButtonWidget.new, StoreWidget.new ]
placeholder = CWM::PlaceholderWidget.new(widget: widgets.first)

content = Yast::Term.new(:VBox,
  SwitchWidget.new(placeholder, widgets),
  placeholder
)


Yast::Wizard.CreateDialog
Yast::CWM.show(content)
Yast::Wizard.CloseDialog
