require "yast"

Yast.import "UI"

module Yast2
  # Class to show some feedback when doing time consuming operation
  class Feedback
    class << self
      # Shows a feedback popup while the given block is running.
      # @param message [String] message to show. The only mandatory argument.
      # @param headline [String] popup headline. If `""`, no headline is shown.
      # @yield runs time consuming operation
      # @yieldparam feedback [Yast2::Feedback] feedback object.
      #   Useful when needed to change text. See {Feedback.update}
      # @return the result of the block
      def show(message, headline: "", &block)
        feedback = new
        feedback.start(message, headline: headline)
        begin
          block.call(feedback)
        ensure
          feedback.stop
        end
      end
    end

    include Yast::UIShortcuts

    MESSAGE_ID = :__feedback_message
    private_constant :MESSAGE_ID
    HEADLINE_ID = :__feedback_headline
    private_constant :HEADLINE_ID

    # Starts showing feedback. Finish it with {#stop}. Non-block variant of #{Feedback.show}.
    # @param message [String] message to show
    # @param headline [String] sets popup headline. String is shown.
    #   If empty string is passed no headline is shown.
    def start(message, headline: "")
      check_params!(message, headline)

      res = Yast::UI.OpenDialog(content(message, headline))
      raise "Failed to open dialog, see logs." unless res
    end

    # Stops showing feedback. Use together with #{start}.
    # @see {Feedback.show}
    # @raise [RuntimeError] when feedback was not started or another dialog is open on top of it.
    def stop
      raise "Trying to stop feedback, but dialog is not feedback dialog" if !Yast::UI.WidgetExists(Id(MESSAGE_ID))

      Yast::UI.CloseDialog
    end

    # Updates feedback message. Headline can be modified only if initial feedback have
    # non-empty feedback.
    # @param message [String] message to show. The only mandatory argument.
    # @param headline [String] headline to show. Only if original feedback have headline.
    # @raise ArgumentError when headline is not empty, but original feedback have it empty.
    def update(message, headline: "")
      check_params!(message, headline)

      if !headline.empty?
        if Yast::UI.WidgetExists(Id(HEADLINE_ID))
          Yast::UI.ChangeWidget(Id(HEADLINE_ID), :Value, headline)
        else
          raise ArgumentError,
            "Headline is not empty for feedback, but original feedback does not have it."
        end
      end
      Yast::UI.ChangeWidget(Id(MESSAGE_ID), :Value, message)
      Yast::UI.RecalcLayout
    end

  private

    def check_params!(message, headline)
      raise ArgumentError, "Invalid value #{message.inspect} of parameter message" if !message.is_a?(::String)

      raise ArgumentError, "Invalid value #{headline.inspect} of parameter headline" if !headline.is_a?(::String)

      nil
    end

    def content(message, headline)
      VBox(
        VSpacing(0.2),
        *headline_widgets(headline),
        MinSize(30, 4,
          HBox(
            HSpacing(1),
            Left(Label(Id(MESSAGE_ID), message)),
            HSpacing(1)
          )),
        VSpacing(0.2)
      )
    end

    def headline_widgets(headline)
      if headline.empty?
        [Empty()]
      else
        [
          HBox(
            HSpacing(1),
            Left(Heading(Id(HEADLINE_ID), headline)),
            HSpacing(1)
          ),
          VSpacing(0.2)
        ]
      end
    end
  end
end
