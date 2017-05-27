require "abstract_method"
require "cwm/abstract_widget"

module CWM
  # A custom widget that has its UI content defined in the method {#contents}.
  # Useful mainly when a specialized widget including more subwidgets should be
  # reusable at more places.
  #
  #
  # @example custom widget child
  #   class MyWidget < CWM::CustomWidget
  #     def contents
  #       HBox(
  #         MyPushButton.new,
  #         PushButton(Id(:undo), _("Undo"))
  #       )
  #     end
  #
  #     def handle(event)
  #       case event["ID"]
  #       when :undo then ...
  #       else
  #         # handle for MyPushButton lives in that PushButton
  #       end
  #       nil
  #     end
  #   end
  class CustomWidget < AbstractWidget
    self.widget_type = :custom

    # @!method contents
    #   Must be defined by subclasses
    #   @return [WidgetTerm] a UI term that can include another AbstractWidgets
    #   @see example/object_api_nested.rb
    abstract_method :contents

    # @return [WidgetHash]
    def cwm_definition
      res = { "custom_widget" => cwm_contents }

      res["handle_events"] = ids_in_contents unless handle_all_events

      super.merge(res)
    end

    # Returns all nested widgets used in contents
    # @return [Array<AbstractWidget>]
    def nested_widgets
      Yast.import "CWM"

      @widgets ||= Yast::CWM.widgets_in_contents(contents)
    end

  protected

    # return contents converted to format understandable by CWM module
    # Basically it replace instance of AbstractWidget by its widget_id
    # @return [StringTerm]
    def cwm_contents
      Yast.import "CWM"

      Yast::CWM.widgets_contents(contents)
    end

    def ids_in_contents
      find_ids(contents) << widget_id
    end

    def find_ids(term)
      term.each_with_object([]) do |arg, res|
        next unless arg.is_a? Yast::Term

        if arg.value == :id
          res << arg.params[0]
        else
          res.concat(find_ids(arg))
        end
      end
    end
  end
end
