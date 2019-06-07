# typed: false
require "yast"
require "abstract_method"
require "cwm/common_widgets"

Yast.import "CWM"
Yast.import "Wizard"

module CWM
  # An OOP API and the pieces missing from {Yast::CWMClass#show Yast::CWM.show}:
  # - creating and closing a wizard dialog
  # - Back/Abort/Next buttons
  # - Help introduction for dialog
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
    # @return [String, nil] button label,
    #   `nil` to use the default label, `""` to omit the button
    def back_button
      nil
    end

    # The :abort button
    # @return [String, nil] button label,
    #   `nil` to use the default label, `""` to omit the button
    def abort_button
      nil
    end

    # The :next button
    # @return [String, nil] button label,
    #   `nil` to use the default label, `""` to omit the button
    def next_button
      nil
    end

    # @return [Array<Symbol>]
    #   Events for which `store` won't be called, see {Yast::CWMClass#show}
    def skip_store_for
      []
    end

    # @return [Array<Symbol>] Buttons to disable (:back, :next
    def disable_buttons
      []
    end

    # Handler when the next button is used
    #
    # If returns false, then it does not go next.
    #
    # @return [Boolean]
    def next_handler
      true
    end

    # Handler when the back button is used
    #
    # If returns false, then it does not go back.
    #
    # @return [Boolean]
    def back_handler
      true
    end

    # Handler when the abort button is used
    #
    # If returns false, then it does not abort.
    #
    # @return [Boolean]
    def abort_handler
      true
    end

    # Introduction for help. This help text will be displayed before widget specific help.
    # Default implementation is empty. If dialog want its help it need to
    # overwrite the method with own text.
    # @note text should be marked for translation
    # @return [String] help text with rich text formatting
    def help
      ""
    end

  private

    # Empty widget which is first on the page and contain help for whole dialog
    class FakeHelp < Empty
      def initialize(text)
        @text = text
      end

      def init
        Yast::CWM.ReplaceWidgetHelp # needed for popup to properly set help text outside wizard
        log.info "calling init on fake help"
      end

      def help
        @text
      end
    end

    # Create a wizard dialog, run the *block*, ensure the dialog is closed.
    # @param block
    def wizard_create_dialog(&block)
      Yast::Wizard.CreateDialog
      block.call
    ensure
      Yast::Wizard.CloseDialog
    end

    # Call {Yast::CWMClass#show} with appropriate arguments
    # @return [Symbol] wizard sequencer symbol
    def cwm_show
      Yast::CWM.show(
        Yast::Term.new(:HBox, FakeHelp.new(help), contents),
        caption:         title,
        back_button:     back_button,
        abort_button:    abort_button,
        next_button:     next_button,
        skip_store_for:  skip_store_for,
        disable_buttons: disable_buttons,
        next_handler:    proc { next_handler },
        back_handler:    proc { back_handler },
        abort_handler:   proc { abort_handler }
      )
    end
  end
end
