require "yast"

Yast.import "CWM"

module CWM
  # An OOP API and the pieces missing from {YastClass::CWM#show Yast::CWM.show}:
  # - creating and closing a wizard dialog
  # - Back/Abort/Next buttons
  #
  # @see UI::Dialog
  # @see CWM::AbstractWidget
  class Dialog
    include Yast::Logger
    include Yast::I18n
    include Yast::UIShortcuts

    # @return [String,nil] The dialog title. `nil`: keep the existing title.
    def title
      nil
    end

    # @return [CWM::WidgetTerm]
    abstract_method :contents

    # A shortcut for `.new(*args).run`
    def self.run(*args)
      new(*args).run
    end

    # The entry point.
    # Will open (and close) a wizard dialog unless one already exists.
    # @return [Symbol]
    def run
      if should_open_dialog?
        wizard_create_dialog { cwm_show }
      else
        cwm_show
      end
    end

    def should_open_dialog?
      !Yast::Wizard.IsWizardDialog
    end

    # The :back button
    # @return [String,true,nil] button label,
    #   `true` to use the default label, or `nil` to omit the button
    def back_button
      true
    end

    # The :abort button
    # @return [String,true,nil] button label,
    #   `true` to use the default label, or `nil` to omit the button
    def abort_button
      true
    end

    # The :next button
    # @return [String,true,nil] button label,
    #   `true` to use the default label, or `nil` to omit the button
    def next_button
      true
    end

    # @return [Array<Symbol>]
    #   Events for which `store` won't be called, see {CWMClass#show}
    def skip_store_for
      []
    end

  private

    # Create a wizard dialog, run the *block*, ensure the dialog is closed.
    # @param block
    def wizard_create_dialog(&block)
      Yast::Wizard.CreateDialog
      block.call
    ensure
      Yast::Wizard.CloseDialog
    end

    # Call {CWMClass#show} with appropriate arguments
    # @return [Symbol] wizard sequencer symbol
    def cwm_show
      Yast::CWM.show(
        contents,
        caption:        title,
        back_button:    replace_true(back_button, Yast::Label.BackButton),
        abort_button:   replace_true(abort_button, Yast::Label.AbortButton),
        next_button:    replace_true(next_button, Yast::Label.NextButton),
        skip_store_for: skip_store_for
      )
    end

    def replace_true(value, replacement)
      if value == true
        replacement
      else
        value
      end
    end
  end
end
