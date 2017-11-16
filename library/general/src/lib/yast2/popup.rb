require "yast"

require "erb"

Yast.import "Label"
Yast.import "UI"

module Yast2
  # Class responsible for showing popups. It has a small but consistent API.
  # Intended as a replacement for {Yast::Popup} module.
  # @note as the UI is not easy to test, it is recommended to run
  #   `examples/popup_series_tester.sh` after modifying this code,
  #   to tests common combinations of options.
  # @note for RSpec tests, `require "yast2/popup_rspec"` for easier mocking
  #   that still does argument verifications.
  class Popup
    class << self
      include Yast::I18n

      # Number of lines to switch to richtext widget for richtext: false
      LINES_THRESHOLD = 20

      RICHTEXT_WIDTH = 60
      RICHTEXT_HEIGHT = 10

      # Show a popup, wait for a button press (or a timeout), return the button ID.
      # @param message [String] message to show. The only mandatory argument.
      # @param details [String] details that will be shown in another popup
      #   on pressing a "Details..." button. (`""` -> no button)
      # @param headline [String, :error, :warning] sets popup headline.
      #   A String is shown as is (`""` -> no headline shown).
      #   `:error` and `:warning` produce the corresponding translated string.
      #   Note: a Symbol means just predefined strings, not affecting popup style.
      # @param timeout [Integer] how many seconds until autoclosing. 0 means forever.
      # @param buttons [Hash<Symbol, String>, Symbol] buttons shown.
      #   - Explicit way: a **Hash** button_id => button_text,
      #     shown in source code order.
      #     Beware that symbols starting with `:__` are reserved.
      #   - Shorthand way: a **Symbol**, one of:
      #     - `:ok`              -> `{ ok: Label.OKButton}`
      #     - `:continue_cancel` -> `{ continue: Label.ContinueButton,
      #                                cancel:   Label.CancelButton }`
      #     - `:yes_no`          -> `{ yes: Label.YesButton, no: Label.NoButton }`
      # @param focus [Symbol, nil] which button gets the focus.
      #   Also it is the button which is returned if the timeout is exceeded.
      #   `nil` means the first button. See buttons parameter.
      # @param richtext [Boolean] whether to interpret richtext tags in message. If it it true,
      #   then always Richtext widget is used. If it is false, for short text Label widget is used
      #   and for long text Richtext widget is used, but richtext tags are not interpreted.
      # @param style [:notice, :important, :warning] popup dialog styling. :notice is common one,
      #   :important is brighter and :warning is style when something goes wrong.
      #   See Yast::UI.OpenDialog options :infocolor and :warncolor.
      # @return [Symbol] symbol of pressed button. If timeout appear,
      #   then button set in focus parameter is returned. If user click on 'x' button in window
      #   then `:cancel` symbol is returned.
      #
      # @example pair of old and new API calls
      #   Yast::Popup.Message(text)
      #   Yast2::Popup.show(text)
      #
      #   Yast::Popup.MessageDetails(text, details)
      #   Yast2::Popup.show(text, details: details)
      #
      #   Yast::Popup.TimedError(text, seconds)
      #   Yast2::Popup.show(text, headline: :error, timeout: seconds)
      #
      #   Yast::Popup.TimedErrorAnyQuestion(headline, message, yes_button_message, no_button_message,
      #     focus, timeout_seconds)
      #   Yast2::Popup.show(message, headline: headline, timeout: timeout_seconds,
      #     buttons: { yes: yes_button_message, no: no_button_message), focus: :yes)
      #
      #   Yast::Popup.TimedLongNotify(message, timeout_seconds)
      #   Yast2::Popup.show(message, richtext: true, timeout: timeout_seconds)
      #
      def show(message, details: "", headline: "", timeout: 0, focus: nil, buttons: :ok, richtext: false, style: :notice)
        textdomain "base"
        buttons = generate_buttons(buttons)
        headline = generate_headline(headline)
        # add default focus button before adding details, as details should not be focussed
        focus = buttons.keys.first if focus.nil?
        add_details_button(buttons) unless details.empty?
        add_stop_button(buttons) if timeout > 0
        check_arguments!(message, details, timeout, focus, buttons)
        content_res = content(body(headline, message, richtext, timeout), buttons)

        event_loop(content_res, focus, timeout, details, style)
      end

      # Shows a feedback popup while the given block is running.
      # @param message [String] message to show. The only mandatory argument.
      # @param headline [String] popup headline. If `""`, no headline is shown.
      # @return the result of the block
      def feedback(message, headline: "", &block)
        start_feedback(message, headline: headline)
        begin
          block.call
        ensure
          stop_feedback
        end
      end

      # Updates feedback message. Headline cannot be modified.
      # @param message [String] message to show. The only mandatory argument.
      def update_feedback(message)
        Yast::UI.ChangeWidget(Id(:__feedback_message), :Value, message)
      end

      # Starts showing feedback. Finish it with {#stop_feedback}. Non-block variant of #{feedback}.
      # @param message [String] message to show
      # @param headline [String] sets popup headline. String is shown.
      #   If empty string is passed no headline is shown.
      def start_feedback(message, headline: "")
        headline = generate_headline(headline)
        if !message.is_a?(::String)
          raise ArgumentError, "Invalid value #{message.inspect} of parameter message"
        end

        if !headline.is_a?(::String)
          raise ArgumentError, "Invalid value #{headline.inspect} of parameter headline"
        end

        body = VBox(
          VSpacing(0.4),
          *headline_widgets(headline),
          Left(Label(Id(:__feedback_message), message))
        )
        content_res = content(body, {})

        res = Yast::UI.OpenDialog(content_res)
        raise "Failed to open dialog, see logs." unless res
      end

      # Stops showing feedback. Use together with #{start_feedback}.
      # @see feedback
      def stop_feedback
        if !Yast::UI.WidgetExists(Id(:__feedback_message))
          raise "Trying to stop feedback, but dialog is not feedback dialog"
        end
        Yast::UI.CloseDialog
      end

    private

      include Yast::UIShortcuts

      def check_arguments!(message, details, timeout, focus, buttons)
        if !message.is_a?(::String)
          raise ArgumentError, "Invalid value #{message.inspect} of parameter message"
        end

        if !details.is_a?(::String)
          raise ArgumentError, "Invalid value #{details.inspect} of parameter details"
        end

        if !timeout.is_a?(::Integer)
          raise ArgumentError, "Invalid value #{timeout.inspect} of parameter timeout"
        end

        if !buttons.key?(focus)
          raise ArgumentError, "Invalid value #{focus.inspect} for parameter focus. " \
           "Known buttons: #{buttons.keys}."
        end

        nil
      end

      def generate_buttons(buttons)
        case buttons
        when ::Hash
          buttons
        when :ok
          { ok: Yast::Label.OKButton }
        when :continue_cancel
          { continue: Yast::Label.ContinueButton, cancel: Yast::Label.CancelButton }
        when :yes_no
          { yes: Yast::Label.YesButton, no: Yast::Label.NoButton }
        else
          raise ArgumentError, "Invalid value #{buttons.inspect} for parameter buttons."
        end
      end

      def generate_headline(headline)
        case headline
        when ::String
          headline
        when :warning
          Yast::Label.WarningMsg
        when :error
          Yast::Label.ErrorMsg
        else
          raise ArgumentError, "Invalid value #{headline.inspect} for parameter headline."
        end
      end

      def add_details_button(buttons)
        # use this way merge to have details as first place button
        buttons[:__details] = _("&Details...")
      end

      def add_stop_button(buttons)
        # use this way merge to have details as first place button
        buttons[:__stop] = Yast::Label.StopButton
      end

      def headline_widgets(headline)
        if headline.empty?
          [Empty()]
        else
          [Left(Heading(headline)), VSpacing(0.2)]
        end
      end

      def timeout_widget(timeout)
        if timeout > 0
          Label(Id(:__timeout_label), timeout.to_s)
        else
          Empty()
        end
      end

      def plain_to_richtext(text)
        ERB::Util.html_escape(text).gsub("\n", "<br>")
      end

      def message_widget(message, richtext)
        if richtext
          HBox(
            VSpacing(RICHTEXT_HEIGHT),
            VBox(
              HSpacing(RICHTEXT_WIDTH),
              RichText(message)
            )
          )
        else
          if message.lines.size >= LINES_THRESHOLD
            message_widget(plain_to_richtext(message), true)
          else
            Left(Label(message))
          end
        end
      end

      def body(headline, message, richtext, timeout)
        VBox(
          VSpacing(0.4),
          *headline_widgets(headline),
          message_widget(message, richtext),
          VSpacing(0.2),
          timeout_widget(timeout)
        )
      end

      def content(body, buttons)
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(0.2),
            body,
            VSpacing(1),
            button_box(buttons),
            VSpacing(0.2)
          ),
          HSpacing(1)
        )
      end

      def button_box(buttons)
        push_buttons = buttons.map do |id, label|
          # lets auto detect options for button box
          opt = case id
          when :ok, :yes, :continue
            Opt(:key_F10, :okButton)
          when :cancel, :no
            Opt(:key_F9, :cancelButton)
          else
            Opt(:customButton)
          end

          PushButton(Id(id), opt, label)
        end

        return Empty() if push_buttons.empty?

        # relax sanity check as there can be situation where is
        # e.g. OK and details with `show(text, details: text2)`
        ButtonBox(Opt(:relaxSanityCheck), *push_buttons)
      end

      def event_loop(content, focus, timeout, details, style)
        res = Yast::UI.OpenDialog(dialog_options(style), content)
        raise "Failed to open dialog, see logs." unless res
        begin
          remaining_time = timeout
          Yast::UI.SetFocus(focus)
          loop do
            res = timeout > 0 ? Yast::UI.TimeoutUserInput(1000) : Yast::UI.UserInput
            remaining_time -= 1
            res = handle_event(res, details, remaining_time, focus)
            return res if res
          end
        ensure
          Yast::UI.CloseDialog
        end
      end

      def dialog_options(style)
        case style
        when :notice
          Opt()
        when :important
          Opt(:infocolor)
        when :warning
          Opt(:warncolor)
        else
          raise ArgumentError, "Invalid style parameter #{style.inspect}"
        end
      end

      def handle_event(res, details, remaining_time, focus)
        case res
        when :__details
          show(details)
          nil
        when :timeout
          if remaining_time <= 0
            focus
          else
            Yast::UI.ChangeWidget(:__timeout_label, :Value, remaining_time.to_s)
            nil
          end
        when :__stop
          loop do
            res = Yast::UI.UserInput
            res = handle_event(res, details, remaining_time, focus)
            return res if res
          end
        else
          res
        end
      end
    end
  end
end
