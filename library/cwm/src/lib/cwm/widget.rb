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

      res
    end

  protected

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
    # custom witget without content do not make sense
    abstract_method :content

    def description
      {
        "custom_widget" => content,
        "widget"        => :custom
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
    def initialize(id)
      self.widget_id = id
    end

    def description
      {
        "widget" => :empty
      }.merge(super)
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
    include ValueBasedWidget
    abstract_method :label

    def description
      {
        "widget" => :inputfield
      }.merge(super)
    end
  end

  # Represents password widget. `label` method is mandatary
  #
  # @see InputFieldWidget for example of child
  class PasswordWidget < AbstractWidget
    include ValueBasedWidget
    abstract_method :label

    def description
      {
        "widget" => :password
      }.merge(super)
    end
  end

  # Represents password widget. `label` method is mandatary
  #
  # @see InputFieldWidget for example of child
  class CheckboxWidget < AbstractWidget
    include ValueBasedWidget
    abstract_method :label

    def description
      {
        "widget" => :checkbox
      }.merge(super)
    end

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
    include ValueBasedWidget
    abstract_method :label

    # description for combobox additionally support `items` method.
    # `items` method have to return array of string pairs, where first value is
    # item id and second is item label.
    def description
      res = {
        "widget" => :combobox
      }
      res["items"] = items if respond_to?(:items)

      res.merge(super)
    end
  end

  # Widget representing selection box to select value.
  #
  # @see {ComboBoxWidget} for child example
  class SelectionBoxWidget < AbstractWidget
    abstract_method :label

    # description for selectionbox additionally support `items` method.
    # `items` method have to return array of string pairs, where first value is
    # item id and second is item label.
    # @example items method
    #   def items
    #     [
    #       [ "Canada", _("Canada")],
    #       [ "USA", _("United States of America")],
    #       [ "North Pole", _("Really cold place")],
    #     ]
    #   end
    #
    def description
      res = {
        "widget" => :selection_box
      }
      res["items"] = items if respond_to?(:items)

      res.merge(super)
    end

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
    abstract_method :label

    # description for multiselectionbox additionally support `items` method.
    # `items` method have to return array of string pairs, where first value is
    # item id and second is item label.
    # @example items method
    #   def items
    #     [
    #       [ "Canada", _("Canada")],
    #       [ "USA", _("United States of America")],
    #       [ "North Pole", _("Really cold place")],
    #     ]
    #   end
    #
    def description
      res = {
        "widget" => :multi_selection_box
      }
      res["items"] = items if respond_to?(:items)

      res.merge(super)
    end

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
      res = {
        "widget" => :intfield
      }
      res["minimum"] = minimum if respond_to?(:minimum)
      res["maximum"] = maximum if respond_to?(:maximum)

      res.merge(super)
    end
  end

  # Widget representing selection of value via radio buttons.
  #
  # @see {ComboBoxWidget} for child example
  class RadioButtonsWidget < AbstractWidget
    abstract_method :label

    # description for radio buttons additionally support `items` method.
    # `items` method have to return array of string pairs, where first value is
    # radio button id and second is button label.
    # @example items method
    #   def items
    #     [
    #       [ "Canada", _("Canada")],
    #       [ "USA", _("United States of America")],
    #       [ "North Pole", _("Really cold place")],
    #     ]
    #   end
    #
    def description
      res = {
        "widget" => :radio_buttons
      }
      res["items"] = items if respond_to?(:items)

      res.merge(super)
    end

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
    def description
      {
        "widget" => :push_button
      }.merge(super)
    end
  end

  # Widget representing menu button with its submenu
  class MenuButtonWidget < AbstractWidget
    abstract_method :label

    # description for menu button additionally support `items` method.
    # `items` method have to return array of string pairs, where first value is
    # menu item id and second is menu item label.
    # @example items method
    #   def items
    #     [
    #       [ "Canada", _("Canada")],
    #       [ "USA", _("United States of America")],
    #       [ "North Pole", _("Really cold place")],
    #     ]
    #   end
    #
    def description
      res = {
        "widget" => :menu_button
      }
      res["items"] = items if respond_to?(:items)

      res.merge(super)
    end
  end

  # Multiline text widget
  # @note label method is required and used as default value (TODO: incosistent with similar richtext in CWM itself)
  class MultiLineEditWidget < AbstractWidget
    include ValueBasedWidget
    abstract_method :label

    def description
      {
        "widget" => :multi_line_edit
      }.merge(super)
    end
  end

  # Rich text widget supporting some highlighting
  class RichTextWidget < AbstractWidget
    include ValueBasedWidget

    def description
      {
        "widget" => :richtext
      }.merge(super)
    end
  end
end
