require "yast"

module UI
  # Provides switch between event_loop and dispatching to handlers.
  # @example simple OK/cancel dialog
  #   class OKDialog
  #     include Yast::UIShortcuts
  #     include UI::EventDispatcher
  #     Yast.import "UI"
  #
  #     def run
  #       return nil unless Yast::UI.OpenDialog(
  #         HBox(
  #           PushButton(Id(:ok), "OK"),
  #           PushButton(Id(:cancel), "Cancel")
  #         )
  #       )
  #       begin
  #         return event_loop
  #       ensure
  #          Yast::UI.CloseDialog
  #       end
  #     end
  #
  #     def ok_handler
  #       exit_dialog(true)
  #     end
  #   end
  module EventDispatcher
    # Does UI event dispatching.
    # @return value from exit_dialog method.
    def event_loop
      Yast.import "UI"

      loop do
        input = Yast::UI.UserInput
        if respond_to?(:"#{input}_handler")
          res = send(:"#{input}_handler")
          if res.is_a?(::Hash) && res.has_key?(:_exit_dialog)
            return res[:_exit_dialog]
          end
        else
          raise "Unknown action #{input}"
        end
      end
    end

    # Construct value that indicate that handler cause end of dialog
    # @param return_value[Object] value to return from event_loop
    def exit_dialog(return_value = nil)
      {
        :_exit_dialog => return_value
      }
    end

    # Default handler for cancel which can be also 'x' on dialog window
    def cancel_handler
      exit_dialog
    end
  end
end
