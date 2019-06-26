# typed: true
# Simple example to demonstrate object API for CWM

require_relative "example_helper"

require "cwm"
require "cwm/popup"

Yast.import "CWM"

class Name < CWM::InputField
  def initialize
    textdomain "example"
  end

  def label
    _("Name")
  end
end

class EventDate < CWM::DateField
  def initialize
    textdomain "example"
  end

  def init
    self.value = Time.now.strftime("%Y-%m-%d")
  end

  def label
    _("Event date")
  end
end

class EventTime < CWM::TimeField
  def initialize
    textdomain "example"
  end

  def init
    self.value = Time.now.strftime("%H:%M:%S")
  end

  def label
    _("Event time")
  end
end

class Event < ::CWM::Popup
  def initialize
    textdomain "example"
  end

  def contents
    VBox(
      Name.new,
      HBox(
        EventDate.new,
        HSpacing(1),
        EventTime.new
      )
    )
  end

  def title
    _("Event Example")
  end
end

Event.new.run
