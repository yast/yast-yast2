require "abstract_method"
require "cwm/abstract_widget"

module CWM
  # A custom widget that has its UI content defined in the method {#contents}.
  # Useful mainly when a specialized widget including more subwidgets should be
  # reusable at more places.
  #
  # @example custom widget child
  #   class MyWidget < CWM::CustomWidget
  #     def initialize
  #       self.handle_all_events = true
  #     end
  #
  #     def contents
  #       HBox(
  #         PushButton(Id(:reset), _("Reset")),
  #         PushButton(Id(:undo), _("Undo"))
  #       )
  #     end
  #
  #     def handle(event)
  #       case event["ID"]
  #       when :reset then ...
  #       when :undo then ...
  #       else ...
  #       end
  #       nil
  #     end
  #   end
  class CustomWidget < AbstractWidget
    self.widget_type = :custom

    # @!method contents
    #   Must be defined by subclasses
    #   @return [Yast::Term] a UI term; {AbstractWidget} are not allowed inside
    abstract_method :contents

    def cwm_definition
      res = { "custom_widget" => cwm_contents }

      res["handle_events"] = ids_in_contents unless handle_all_events

      super.merge(res)
    end

    # Returns all nested widgets used in contents
    def nested_widgets
      Yast.import "CWM"

      Yast::CWM.widgets_in_contents(contents)
    end

  protected

    # return contents converted to format understandable by CWM module
    # Basically it replace instance of AbstractWidget by its widget_id
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
