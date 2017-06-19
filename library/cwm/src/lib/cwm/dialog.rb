require "yast"

Yast.import "CWM"

# FIXME: move this to yast-yast2 as soon as the API stabilizes
module CWM
  # relate to UI::Dialog ?
  # just #run, .run
  # The important contract with the outside is:
  # who manages the dialog windows and buttons
  # Kinds: pop-up, full-size, wizard
  class Dialog
    include Yast::Logger
    include Yast::I18n
    include Yast::UIShortcuts

    # A shortcut for `.new(*args).run`
    def self.run(*args)
      new(*args).run
    end

    def run
      if should_open_dialog?
        wizard_create_dialog { run_assuming_open }
      else
        run_assuming_open
      end
    end

    def wizard_create_dialog(&block)
      Yast::Wizard.CreateDialog
      block.call
    ensure
      Yast::Wizard.CloseDialog
    end

    def run_assuming_open
      # should have #init/#store ?
      Yast::CWM.show(
        contents,
        caption:        title,
        back_button:    replace_true(back_button, Yast::Label.BackButton),
        abort_button:   replace_true(abort_button, Yast::Label.AbortButton),
        next_button:    replace_true(next_button, Yast::Label.NextButton),
        skip_store_for: skip_store_for
      )
    end

    def should_open_dialog?
      !Yast::Wizard.IsWizardDialog
    end

    # @return [CWM::WidgetTerm]
    abstract_method :contents

    # @return [String,nil] Set a title, or keep the existing title
    abstract_method :title

    # The :back button
    # @return [String,true,nil] button label, use default label, or `nil` to omit the button
    def back_button
      true
    end

    # The :abort button
    # @return [String,true,nil] button label, use default label, or `nil` to omit the button
    def abort_button
      true
    end

    # The :next button
    # @return [String,true,nil] button label, use default label, or `nil` to omit the button
    def next_button
      true
    end

    # @return
    def skip_store_for
      []
    end

  private

    def replace_true(value, replacement)
      if value == true
        replacement
      else
        value
      end
    end
  end
end
