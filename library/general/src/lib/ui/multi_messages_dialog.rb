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
    TIMEOUT_STEP = 1000 # miliseconds

    attr_reader :messages, :headline, :min_height, :min_width, :timeout

    # Constructor
    #
    # @param headline   [String]  Dialog's headline
    # @param messages   [Array]   Array of messages. Objects in the array should
    #                             respond to #title and #body methods.
    # @param min_height [Integer] Minimal dialog's height.
    # @param min_width  [Integer] Minimal dialog's width.
    def initialize(headline, messages, min_height: nil, min_width: nil, timeout: false)
      super()
      textdomain "yast"
      @messages = messages
      @position = 0
      @headline = headline
      @min_height = min_height || DEFAULT_MIN_HEIGHT
      @min_width = min_width || DEFAULT_MIN_WIDTH
      @timeout = timeout
      @remaining_time = timeout
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
            ReplacePoint(Id(:body), message_body_ui)
          ),
          VSpacing(0.3),
          timed? ? Label(Id(:timer), @remaining_time.to_s) : Empty(),
          # Footer buttons
          buttons_ui
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
      stop_timer if timed?
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

    # Timeout handler
    #
    # Handles timeouts generated by TimeoutUserInput updating the
    # remaining_time counter and the timer. If no time left, it closes
    # the dialog.
    def timeout_handler
      @remaining_time -= 1
      if @remaining_time.zero?
        finish_dialog(:timeout)
      else
        Yast::UI.ChangeWidget(Id(:timer), :Value, @remaining_time.to_s)
      end
    end

    # Stop handler
    #
    # Disable timeout counter
    def stop_handler
      stop_timer
      Yast::UI.ChangeWidget(Id(:stop), :Enabled, false)
    end

    # Stop timer
    #
    # Stop the timer countdown.
    def stop_timer
      @timeout = false
    end

    # User input handling
    #
    # If the dialog is timed, it relies Yast::UI::TimeoutUserInput.
    # Otherwise, relies on Yast::UI::UserInput
    #
    # @return [Symbol] User input or :timeout symbol
    def user_input
      if timed?
        Yast::UI::TimeoutUserInput(TIMEOUT_STEP)
      else
        super
      end
    end

    # Determines whether the dialog is timed or not
    #
    # @return [true,false] True if the dialog is timed; false otherwise.
    def timed?
      timeout.is_a?(Integer)
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
      Yast::UI.ReplaceWidget(Id(:body), message_body_ui)
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
    def message_body_ui
      title =
        if messages.size > 1
          format(_("%s (%d out of %d)"), current_message.title, @position + 1, total)
        else
          current_message.title
        end
      Frame(
        title,
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

    # Build the set of buttons to be shown in the dialog
    #
    # Includes a 'stop' button only if the dialog is timed.
    #
    # @return [Yast::Term] UI content for dialog
    def buttons_ui
      buttons = [PushButton(Id(:close), Yast::Label.CloseButton)]
      if messages.size > 1
        buttons += [
          HStretch(),
          PushButton(Id(:back), Opt(:disabled), Yast::Label.BackButton),
          HStretch(),
          PushButton(Id(:next), Opt(last_message? ? :disabled : :enabled), Yast::Label.NextButton)
        ]
      end
      if timed?
        buttons.insert(2, PushButton(Id(:stop), Yast::Label.StopButton), HStretch())
      end
      HBox(*buttons)
    end
  end
end
