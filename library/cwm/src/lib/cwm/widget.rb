require "yast"

module CWM
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
      if widget_id.nil?
        raise "Widget '#{self.class}' does set its widget ID"
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

  class CustomWidget < AbstractWidget
    def description
      unless respond_to?(:content)
        raise "For custom widget '#{self.class}' content method have to be defined"
      end

      {
        "custom_widget" => content,
        "widget"        => :custom
      }.merge(super)
    end
  end

  class EmptyWidget < AbstractWidget
    def initialize(id)
      self.widget_id = id
    end

    def description
      {
        "widget"        => :empty
      }.merge(super)
    end
  end

  # helpers for easier set/obtain value of widget for widgets where value is
  # obtained by :Value symbol
  module ValueBasedWidget

  protected

    def value
      Yast::UI.QueryWidget(Id(widget_id), :Value)
    end

    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :Value, val)
    end
  end

  class InputFieldWidget < AbstractWidget
    include ValueBasedWidget

    def description
      unless respond_to?(:label)
        raise "For input field widget '#{self.class}' label method have to be defined"
      end

      {
        "widget"        => :inputfield
      }.merge(super)
    end
  end

  class PasswordWidget < AbstractWidget
    include ValueBasedWidget

    def description
      unless respond_to?(:label)
        raise "For input field widget '#{self.class}' label method have to be defined"
      end

      {
        "widget"        => :password
      }.merge(super)
    end
  end

  class CheckboxWidget < AbstractWidget
    include ValueBasedWidget

    def description
      unless respond_to?(:label)
        raise "For input field widget '#{self.class}' label method have to be defined"
      end

      {
        "widget"        => :checkbox
      }.merge(super)
    end

  protected

    def checked?
      value
    end

    def unchecked?
      !value
    end

    def check
      self.value = true
    end

    def uncheck
      self.value = false
    end
  end

  class ComboBoxWidget < AbstractWidget
    include ValueBasedWidget

    # description for combobox additionally support `items` method.
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
      unless respond_to?(:label)
        raise "For input field widget '#{self.class}' label method have to be defined"
      end

      res = {
        "widget"        => :combobox,
      }
      res["items"] = items if respond_to?(:items)

      res.merge(super)
    end
  end

  class SelectionBoxWidget < AbstractionWidget
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
      unless respond_to?(:label)
        raise "For input field widget '#{self.class}' label method have to be defined"
      end

      res = {
        "widget"        => :selection_box, # yeah, really so incosistent to have combox and selection_box
      }
      res["items"] = items if respond_to?(:items)

      res.merge(super)
    end

  protected
    def value
      Yast::UI.QueryWidget(Id(widget_id), :CurrentItem)
    end

    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :CurrentItem, val)
    end
  end

  class MultiSelectionBoxWidget < AbstractionWidget
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
      unless respond_to?(:label)
        raise "For input field widget '#{self.class}' label method have to be defined"
      end

      res = {
        "widget"        => :multi_selection_box,
      }
      res["items"] = items if respond_to?(:items)

      res.merge(super)
    end

  protected
    def values
      Yast::UI.QueryWidget(Id(widget_id), :SelectedItems)
    end

    def values=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :SelectedItems, val)
    end
  end

  class IntField < AbstractionWidget
    include ValueBasedWidget

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
      unless respond_to?(:label)
        raise "For input field widget '#{self.class}' label method have to be defined"
      end

      res = {
        "widget"        => :intfield,
      }
      res["minimum"] = minimum if respond_to?(:minimum)
      res["maximum"] = minimum if respond_to?(:maximum)

      res.merge(super)
    end
  end

  class RadioButtonsWidget < AbstractWidget
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
      unless respond_to?(:label)
        raise "For radio buttons widget '#{self.class}' label method have to be defined"
      end

      res = {
        "widget"        => :radio_buttons, # yeah, really so incosistent to have combox and selection_box
      }
      res["items"] = items if respond_to?(:items)

      res.merge(super)
    end

  protected
    def value
      Yast::UI.QueryWidget(Id(widget_id), :CurrentButton)
    end

    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :CurrentButton, val)
    end
  end

  class PushButtonWidget < AbstractWidget
    # @param [Symbol] id is used as widget id
    # @yield block runned after button is clicked
    def initialize(id, &block)
      self.widget_id = id
      @block = block
    end

    def description
      {
        "widget"        => :push_button
      }.merge(super)
    end

  private

    def handle(widget, event)
      return if event["ID"] != widget

      @block.call

      nil
    end
  end

  class MenuButtonWidget < AbstractWidget
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
      unless respond_to?(:label)
        raise "For menu button widget '#{self.class}' label method have to be defined"
      end

      res = {
        "widget"        => :menu_button,
      }
      res["items"] = items if respond_to?(:items)

      res.merge(super)
    end
  end

  # @note label method is required and used as default value (TODO: incosistent with similar richtext in CWM itself)
  class MultiLineEditWidget < AbstractWidget
    include ValueBasedWidget

    def description
      unless respond_to?(:label)
        raise "For multi line edit widget '#{self.class}' label method have to be defined"
      end

      {
        "widget"        => :multi_line_edit
      }.merge(super)
    end
  end

  class RichTextWidget < AbstractWidget
    include ValueBasedWidget

    def description
      {
        "widget"        => :richtext
      }.merge(super)
    end
  end
end
