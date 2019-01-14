# Simple example to demonstrate object API for CWM

require_relative "example_helper"

require "cwm"
require "cwm/popup"

Yast.import "CWM"

class Goat < CWM::CheckBox
  def initialize
    textdomain "example"
  end

  def label
    _("Goat")
  end

  def help
    _("<p>Goat will eat cabbage.</p>")
  end
end

class Cabbage < CWM::CheckBox
  def initialize
    textdomain "example"
  end

  def label
    _("Cabbage")
  end

  def help
    _("<p>Poor cabbage cannot eat anyone.</p>")
  end
end

class Wolf < CWM::CheckBox
  def initialize
    textdomain "example"
  end

  def label
    _("Wolf")
  end

  def help
    _("<p>Wolf hates vegans, so will eat goat and won't even touch cabbage.</p>")
  end
end

class Ferryman < ::CWM::Popup
  def initialize
    textdomain "example"
  end

  def contents
    HBox(
      Cabbage.new,
      Goat.new,
      Wolf.new
    )
  end

  def help
    _("<h3>Ferryman</h3><p>Represents common Ferryman challenge with two place in boat and following rules for passengers:</p>")
  end

  def title
    ""
#_("Ferryman")
  end
end

Ferryman.new.run
