require "yast"

require "abstract_method"

module CWM
  # Represent base for any widget used in CWM. It can be passed as "widget" argument. For more
  # details about usage see {CWM.ShowAndRun}
  class AbstractWidget
    include Yast::UIShortcuts
    include Yast::I18n

    # @return [String] id used for widget
    attr_accessor :widget_id

    # defines widget type for CWM usage
    def self.widget_type=(val)
      define_method(:widget_type) { val }
    end

    # generates description for CWM with widget. Description is auto filled from defined methods.
    #
    # methods used to generate description:
    #
    # - `#help` [String] to get translated help text for widget
    # - `#label` [String] to get translated label text for widget
    # - `#opt` [Array<Symbol>] to get options passed to widget like `[:hstretch, :vstretch]`
    # - `#validate` [Boolean (String, Hash)] validate widget value, arguments are
    #   widget key and event map causing validation, for other validation types, overwrite description
    # - `#init` [nil (String)] initialize widget. like its value. Parameter is widget id
    # - `#handle` [Symbol,nil (String, Hash)] handle widget changed value or press.
    #   return value is usually nil, returning symbol can be used to send different event
    # - `#store` [nil (String, Hash)] store widget value after user confirm dialog
    # - `#cleanup` [nil (String)] cleanup after widget is destroyed
    # @raise [RuntimeError] if required method is not implemented or widget id not set.
    def description
      raise "Widget '#{self.class}' does set its widget ID" if widget_id.nil?
      if !respond_to?(:widget_type)
        raise "Widget '#{self.class}' does set its widget type"
      end

      res = {}

      if respond_to?(:help)
        res["help"] = help
      else
        res["no_help"] = ""
      end
      res["label"] = label if respond_to?(:label)
      res["opt"] = opt if respond_to?(:opt)
      if respond_to?(:validate)
        res["validate_function"] = validate_method
        res["validate_type"] = :function
      end
      res["init"] = init_method if respond_to?(:init)
      res["handle"] = handle_method if respond_to?(:handle)
      res["store"] = store_method if respond_to?(:store)
      res["cleanup"] = cleanup_method if respond_to?(:cleanup)
      res["widget"] = widget_type

      res
    end

    # gets if widget is open for modification
    def enabled?
      Yast::UI.QueryWidget(Id(widget_id), :Enabled)
    end

    # Opens widget for modification
    def enable
      Yast::UI.ChangeWidget(Id(widget_id), :Enabled, true)
    end

    # Closes widget for modification
    def disable
      Yast::UI.ChangeWidget(Id(widget_id), :Enabled, false)
    end

  protected

    # helper to check if event is invoked by this widget
    def my_event?(widget, event)
      return widget == event["ID"]
    end

    # shortcut from Yast namespace to avoid including whole namespace
    # TODO: kill converts in CWM module, to avoid this workaround for funrefs
    def fun_ref(*args)
      Yast::FunRef.new(*args)
    end

  private

    def init_method
      fun_ref(method(:init), "void (string)")
    end

    def handle_method
      fun_ref(method(:handle), "symbol (string, map)")
    end

    def store_method
      fun_ref(method(:store), "void (string, map)")
    end

    def cleanup_method
      fun_ref(method(:cleanup), "void (string)")
    end

    def validate_method
      fun_ref(method(:validate), "boolean (string, map)")
    end
  end

  # Represents custom widget, that have its UI content defined in method content.
  # Useful mainly when specialized widget including more subwidget should be
  # reusable at more places.
  #
  # @example custom widget child
  #   class MyWidget < CWM::CustomWidget
  #     def initialize
  #       self.widget_id = "my_widget"
  #     end
  #
  #     def content
  #       HBox(
  #         PushButton(Id(:reset), _("Reset")),
  #         PushButton(Id(:undo), _("Undo"))
  #       )
  #     end
  #
  #     def handle(widget, event)
  #       case event["ID"]
  #       when :reset then ...
  #       when :undo then ...
  #       else ...
  #       end
  #     end
  #   end
  class CustomWidget < AbstractWidget
    self.widget_type = :custom
    # custom witget without content do not make sense
    abstract_method :content

    def description
      {
        "custom_widget" => content
      }.merge(super)
    end
  end

  # Empty widget useful mainly as place holder for replacement or for catching global events
  #
  # @example empty widget usage
  #   widget = CWM::EmptyWidget("replace_point")
  #   CWM.ShowAndRun(
  #     "content" => VBox(widget.widget_id),
  #     "widgets" => [widget]
  #   )
  class EmptyWidget < AbstractWidget
    self.widget_type = :empty

    def initialize(id)
      self.widget_id = id
    end
  end

  # helpers for easier set/obtain value of widget for widgets where value is
  # obtained by :Value symbol
  module ValueBasedWidget
    def value
      Yast::UI.QueryWidget(Id(widget_id), :Value)
    end

    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :Value, val)
    end
  end

  # helper to define items used by widgets that offer selection from list of
  # values.
  module ItemsSelection
    # items are defined as list of pair, where first one is id and second
    # one is user visible value
    # @return [Array<Array<String>>]
    # @example items method in widget
    #   def items
    #     [
    #       [ "Canada", _("Canada")],
    #       [ "USA", _("United States of America")],
    #       [ "North Pole", _("Really cold place")],
    #     ]
    #   end
    def items
    end

    def description
      {
        "items" => items
      }.merge(super)
    end

    # change list of items offered in widget. Format is same as in {#items}
    def change_items(items_list)
      val = items_list.map { |i| Item(Id(i[0]), i[1]) }

      Yast::UI.ChangeWidget(Id(widget_id), :Items, val)
    end
  end

  # Represents input field widget. `label` method is mandatory.
  #
  # @example input field widget child
  #   class MyWidget < CWM::InputFieldWidget
  #     def initialize(myconfig)
  #       self.widget_id = "my_widget"
  #       @config = myconfig
  #     end
  #
  #     def label
  #       _("The best widget ever is:")
  #     end
  #
  #     def init(_widget)
  #       self.value = @config.value
  #     end
  #
  #     def store(_widget, _event)
  #       @config.value = value
  #     end
  #   end
  class InputFieldWidget < AbstractWidget
    self.widget_type = :inputfield

    include ValueBasedWidget
    abstract_method :label
  end

  # Represents password widget. `label` method is mandatary
  #
  # @see InputFieldWidget for example of child
  class PasswordWidget < AbstractWidget
    self.widget_type = :password

    include ValueBasedWidget
    abstract_method :label
  end

  # Represents password widget. `label` method is mandatary
  #
  # @see InputFieldWidget for example of child
  class CheckboxWidget < AbstractWidget
    self.widget_type = :checkbox

    include ValueBasedWidget
    abstract_method :label

    # @return [Boolean] true if widget is checked
    def checked?
      value
    end

    # @return [Boolean] true if widget is unchecked
    def unchecked?
      !value
    end

    # checks given widget
    def check
      self.value = true
    end

    # Unchecks given widget
    def uncheck
      self.value = false
    end
  end

  # Widget representing combobox to select value.
  #
  # @example combobox widget child
  #   class MyWidget < CWM::InputFieldWidget
  #     def initialize(myconfig)
  #       self.widget_id = "my_widget"
  #       @config = myconfig
  #     end
  #
  #     def label
  #       _("Choose carefully:")
  #     end
  #
  #     def init(_widget)
  #       self.value = @config.value
  #     end
  #
  #     def store(_widget, _event)
  #       @config.value = value
  #     end
  #
  #     def items
  #       [
  #         [ "Canada", _("Canada")],
  #         [ "USA", _("United States of America")],
  #         [ "North Pole", _("Really cold place")],
  #       ]
  #     end
  #   end
  class ComboBoxWidget < AbstractWidget
    self.widget_type = :combobox

    include ValueBasedWidget
    include ItemsSelection
    abstract_method :label
  end

  # Widget representing selection box to select value.
  #
  # @see {ComboBoxWidget} for child example
  class SelectionBoxWidget < AbstractWidget
    self.widget_type = :selection_box

    include ItemsSelection
    abstract_method :label

    def value
      Yast::UI.QueryWidget(Id(widget_id), :CurrentItem)
    end

    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :CurrentItem, val)
    end
  end

  # Widget representing multi selection box to select more values.
  #
  # @see {ComboBoxWidget} for child example
  class MultiSelectionBoxWidget < AbstractWidget
    self.widget_type = :multi_selection_box

    include ItemsSelection
    abstract_method :label

    # @return [Array<String>] return ids of selected items
    def value
      Yast::UI.QueryWidget(Id(widget_id), :SelectedItems)
    end

    # @param [Array<String>] val array of ids for newly selected items
    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :SelectedItems, val)
    end
  end

  # Represents integer field widget. `label` method is mandatary. It supports
  # additional `minimum` and `maximum` method for limiting selection.
  # @see #{.description} method for minimum and maximum example
  #
  # @see InputFieldWidget for example of child
  class IntField < AbstractWidget
    self.widget_type = :intfield

    include ValueBasedWidget
    abstract_method :label

    # description for combobox additionally support `minimum` and `maximum` methods.
    # Both methods have to FixNum, where it is limited by C signed int range (-2**30 to 2**31-1).
    # @example minimum and maximum methods
    #   def minimum
    #     50
    #   end
    #
    #   def maximum
    #     200
    #   end
    #
    def description
      res = {}

      res["minimum"] = minimum if respond_to?(:minimum)
      res["maximum"] = maximum if respond_to?(:maximum)

      res.merge(super)
    end
  end

  # Widget representing selection of value via radio buttons.
  #
  # @see {ComboBoxWidget} for child example
  class RadioButtonsWidget < AbstractWidget
    self.widget_type = :radio_buttons

    include ItemsSelection
    abstract_method :label

    def value
      Yast::UI.QueryWidget(Id(widget_id), :CurrentButton)
    end

    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :CurrentButton, val)
    end
  end

  # Widget representing button.
  #
  # @example push button widget child
  #   class MyEvilWidget < CWM::PushButtonWidget
  #     def initialize
  #       self.widget_id = "my_evil_widget"
  #     end
  #
  #     def label
  #       _("Win lottery by clicking this.")
  #     end
  #
  #     def handle(widget, _event)
  #       return if widget != widget_id
  #
  #       Virus.install
  #
  #       nil
  #     end
  #   end
  class PushButtonWidget < AbstractWidget
    self.widget_type = :push_button
  end

  # Widget representing menu button with its submenu
  class MenuButtonWidget < AbstractWidget
    self.widget_type = :menu_button

    include ItemsSelection
    abstract_method :label
  end

  # Multiline text widget
  # @note label method is required and used as default value (TODO: incosistent with similar richtext in CWM itself)
  class MultiLineEditWidget < AbstractWidget
    self.widget_type = :multi_line_edit

    include ValueBasedWidget
    abstract_method :label
  end

  # Rich text widget supporting some highlighting
  class RichTextWidget < AbstractWidget
    self.widget_type = :richtext

    include ValueBasedWidget
  end
end
