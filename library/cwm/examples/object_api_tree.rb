# Simple example to demonstrate object API for CWM

require_relative "example_helper"

require "cwm/widget"

Yast.import "CWM"
Yast.import "Popup"
Yast.import "Wizard"

class LuckyNumberWidget < ::CWM::IntField
  attr_reader :result, :minimum, :maximum

  def initialize
    @minimum = 0
    @maximum = 1000
  end

  def label
    _("Lucky number")
  end

  def init
    self.value = @result if @result
  end

  def store
    @result = value
  end
end

class GenerateButton < ::CWM::PushButton
  def initialize(lucky_number_widget)
    @lucky_number_widget = lucky_number_widget
  end

  def label
    _("Generate Lucky Number")
  end

  def handle
    @lucky_number_widget.value = rand(1000)

    nil
  end
end

class LuckyNumberTab < ::CWM::Tab
  def initialize
    self.initial = true
  end

  def contents
    HBox(
      button_widget,
      lucky_number_widget
    )
  end

  def result
    lucky_number_widget.result
  end

  def label
    _("Lucky Number")
  end

private

  def button_widget
    @button_widget ||= GenerateButton.new(lucky_number_widget)
  end

  def lucky_number_widget
    @lucky_number_widget ||= LuckyNumberWidget.new
  end
end

class TrueLoveSelector < ::CWM::RadioButtons
  def initialize
    @chosen = nil
  end

  def label
    _("Select true love")
  end

  def items
    [
      [:human, "Human"],
      [:pc, "PC"]
    ]
  end

  def init
    self.value = @chosen if @chosen
  end

  def validate
    if value == :pc
      Yast::Popup.Error(_("Human will be exterminated, pc cannot allow you to be your true love"))
      return false
    end

    true
  end

  def store
    @chosen = value
  end

  def result
    @chosen
  end
end

class TrueLoveTab < ::CWM::Tab
  def contents
    HBox(
      true_love_selector
    )
  end

  def label
    _("True Love")
  end

  def result
    true_love_selector.result
  end

private

  def true_love_selector
    @true_love_selector ||= TrueLoveSelector.new
  end
end

module Yast
  class ExampleDialog
    include Yast::I18n
    include Yast::UIShortcuts
    include Yast::Logger

    def run
      textdomain "example"

      lucky_number_tab = LuckyNumberTab.new
      true_love_tab = TrueLoveTab.new

      tabs = ::CWM::Tree.new(lucky_number_tab, true_love_tab)

      contents = VBox(tabs)

      Yast::Wizard.CreateDialog
      CWM.show(contents, caption: _("Tabs example"))
      Yast::Wizard.CloseDialog

      log.info "Lucky number: #{lucky_number_tab.result}, true love: #{true_love_tab.result}"
    end
  end
end

Yast::ExampleDialog.new.run
