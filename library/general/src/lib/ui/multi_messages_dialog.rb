require "yast"
require "ui/dialog"

Yast.import "UI"
Yast.import "Label"

module UI
  # This dialog receives several messages and allows the user to browse them
  # using 'Next' and 'Back' buttons.
  #
  # Each message is an object that should respond to #title and #body methods.
  class MultiMessagesDialog < ::UI::Dialog
    include Yast::Logger

    DEFAULT_MIN_HEIGHT = 20
    DEFAULT_MIN_WIDTH = 60

    attr_reader :messages, :headline, :min_height, :min_width

    # Constructor
    #
    # @param headline   [String]  Dialog's headline
    # @param messages   [Array]   Array of messages. Objects in the array should
    #                             respond to #title and #body methods.
    # @param min_height [Integer] Minimal dialog's height.
    # @param min_width  [Integer] Minimal dialog's width.
    def initialize(headline, messages, min_height: nil, min_width: nil)
      super()
      textdomain "yast"
      @messages = messages
      @position = 0
      @headline = headline
      @min_height = min_height || DEFAULT_MIN_HEIGHT
      @min_width = min_width || DEFAULT_MIN_WIDTH
    end

    # Dialog's content
    #
    # Overrides UI::Dialog#dialog_content
    #
    # @return [Yast::Term] UI content for dialog
    #
    # @see UI::Dialog#dialog_content
    def dialog_content
      MinSize(min_width, min_height,
        VBox(
          # Header
          Heading(headline),
          # Interval
          VBox(
            ReplacePoint(Id(:body), message_body)
          ),
          VSpacing(0.3),
          # Footer buttons
          HBox(
            PushButton(Id(:close), Yast::Label.CloseButton),
            HStretch(),
            PushButton(Id(:back), Opt(:disabled), Yast::Label.BackButton),
            HStretch(),
            PushButton(Id(:next), Opt(last_message? ? :disabled : :enabled), Yast::Label.NextButton)
          )
        )
      )
    end

    # 'Next' button handler
    #
    # Set the next message as the current one and refresh the dialog.
    # If it was the last message already, does nothing.
    #
    # @return [true,false] True if the dialog was updated; false otherwise.
    def next_handler
      return false if last_message?
      move_to(@position + 1)
      true
    end

    # 'Back' handler
    #
    # Set the previous message as the current one and refresh the dialog.
    # If it was the first message already, does nothing.
    #
    # @return [true,false] True if the dialog was updated; false otherwise.
    def back_handler
      return false if first_message?
      move_to(@position - 1)
      true
    end

    # 'Close' button handler
    #
    # Closes the dialog returning :close
    def close_handler
      finish_dialog(:close)
    end

    # Display the message in the given position
    #
    # @param position [Integer] Position of the message to be considered as
    #                           'current'.
    def move_to(position)
      @position = position
      refresh
    end

    private

    # Dialog options
    #
    # Overrides UI::Dialog#dialog_options
    #
    # @return [Yast::Term] Dialog options.
    #
    # @see UI::Dialog#dialog_options
    def dialog_options
      Opt(:decorated)
    end

    # Refresh message and buttons
    #
    # Update the message and enables/disables 'Next' and 'Back' buttons
    # accordingly.
    #
    # @see #current_message
    # @see #first_message?
    # @see #last_message?
    def refresh
      Yast::UI.ReplaceWidget(Id(:body), message_body)
      Yast::UI.ChangeWidget(Id(:back), :Enabled, !first_message?)
      Yast::UI.ChangeWidget(Id(:next), :Enabled, !last_message?)
    end

    # Returns the current message
    #
    # That's the message that it's supposed to be shown to the user at a given
    # time.
    #
    # @return Object
    def current_message
      messages[@position]
    end

    # Returns the amount of messages
    #
    # It is just a convenience method.
    #
    # @return [Integer] Amount of messages.
    def total
      messages.size
    end

    # UI content describing the UI for the current message's body
    #
    # @return [Yast::Term] UI content for dialog
    def message_body
      Frame(
        format(_("%s (%d out of %d)"), current_message.title, @position + 1, total),
        RichText(current_message.body)
      )
    end

    # Determines whether the current is the first message
    #
    # @return [true,false] True when it's the first message; true otherwise.
    def first_message?
      @position.zero?
    end

    # Determines whether the current is the last message
    #
    # @return [true,false] True when it's the last message; false otherwise.
    def last_message?
      @position == (total - 1)
    end
  end
end
