require "yast"

require "abstract_method"
require "cwm/abstract_widget"
require "cwm/custom_widget"
require "cwm/tabs"
require "cwm/tree"

# Common Widget Manipulation.
# An object-oriented API for the YCP-era {Yast::CWMClass}.
module CWM
  # An empty widget useful mainly as placeholder for replacement
  # or for catching global events
  #
  # @example empty widget usage
  #   CWM.show(VBox(CWM::Empty.new("replace_point")))
  class Empty < AbstractWidget
    self.widget_type = :empty

    # @param id [String] widget ID
    def initialize(id)
      self.widget_id = id
    end
  end

  # A mix-in for widgets using the :Value property
  module ValueBasedWidget
    # Get widget value
    # @return [Object] a value according to specific widget type
    def value
      Yast::UI.QueryWidget(Id(widget_id), :Value)
    end

    # Set widget value
    # @param val [Object] a value according to specific widget type
    # @return [void]
    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :Value, val)
    end
  end

  # A mix-in to define items used by widgets
  # that offer a selection from a list of values.
  module ItemsSelection
    # Items are defined as a list of pairs, where
    # the first one is the ID and
    # the second one is the user visible value
    # @return [Array<Array(String,String)>]
    # @example items method in widget
    #   def items
    #     [
    #       [ "Canada", _("Canada")],
    #       [ "USA", _("United States of America")],
    #       [ "North Pole", _("Really cold place")],
    #     ]
    #   end
    def items
      []
    end

    def cwm_definition
      super.merge(
        "items" => items
      )
    end

    # Change the list of items offered in widget.
    # The format is the same as in {#items}
    # @param items_list [Array<Array(String,String)>] new items
    # @return [void]
    def change_items(items_list)
      val = items_list.map { |i| Item(Id(i[0]), i[1]) }

      Yast::UI.ChangeWidget(Id(widget_id), :Items, val)
    end
  end

  # An input field widget.
  # The {#label} method is mandatory.
  #
  # @example input field widget child
  #   class MyWidget < CWM::InputField
  #     def initialize(myconfig)
  #       @config = myconfig
  #     end
  #
  #     def label
  #       _("The best widget ever is:")
  #     end
  #
  #     def init
  #       self.value = @config.value
  #     end
  #
  #     def store
  #       @config.value = value
  #     end
  #   end
  class InputField < AbstractWidget
    self.widget_type = :inputfield

    include ValueBasedWidget
    abstract_method :label
  end

  # A Password widget.
  # The {#label} method is mandatory.
  #
  # @see InputField for example of child
  class Password < AbstractWidget
    self.widget_type = :password

    include ValueBasedWidget
    abstract_method :label
  end

  # A CheckBox widget.
  # The {#label} method is mandatory.
  #
  # @see InputField for example of child
  class CheckBox < AbstractWidget
    self.widget_type = :checkbox

    include ValueBasedWidget
    abstract_method :label

    # @return [Boolean] true if the box is checked
    def checked?
      value == true
    end

    # @return [Boolean] true if the box is unchecked
    def unchecked?
      # explicit check as the value can be also nil,
      # which is shown as a grayed-out box, with "indeterminate" meaning
      value == false
    end

    # Checks the box
    # @return [void]
    def check
      self.value = true
    end

    # Unchecks the box
    # @return [void]
    def uncheck
      self.value = false
    end
  end

  # A Combo box to select a value.
  # The {#label} method is mandatory.
  #
  # @example combobox widget child
  #   class MyWidget < CWM::ComboBox
  #     def initialize(myconfig)
  #       @config = myconfig
  #     end
  #
  #     def label
  #       _("Choose carefully:")
  #     end
  #
  #     def init
  #       self.value = @config.value
  #     end
  #
  #     def store
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
  class ComboBox < AbstractWidget
    self.widget_type = :combobox

    include ValueBasedWidget
    include ItemsSelection
    abstract_method :label
  end

  # Widget representing selection box to select value.
  # The {#label} method is mandatory.
  #
  # @see ComboBox for child example
  class SelectionBox < AbstractWidget
    self.widget_type = :selection_box

    include ItemsSelection
    abstract_method :label

    # @return [String] ID of the selected item
    def value
      Yast::UI.QueryWidget(Id(widget_id), :CurrentItem)
    end

    # @param val [String] ID of the selected item
    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :CurrentItem, val)
    end
  end

  # A multi-selection box to select more values.
  # The {#label} method is mandatory.
  #
  # @see {ComboBox} for child example
  class MultiSelectionBox < AbstractWidget
    self.widget_type = :multi_selection_box

    include ItemsSelection
    abstract_method :label

    # @return [Array<String>] return IDs of selected items
    def value
      Yast::UI.QueryWidget(Id(widget_id), :SelectedItems)
    end

    # @param val [Array<String>] IDs of newly selected items
    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :SelectedItems, val)
    end
  end

  # An integer field widget.
  # The {#label} method is mandatory.
  # It supports optional {#minimum} and {#maximum} methods
  # for limiting the range.
  # See {#cwm_definition} method for minimum and maximum example
  #
  # @see InputField for example of child
  class IntField < AbstractWidget
    self.widget_type = :intfield

    include ValueBasedWidget
    abstract_method :label

    # @!method minimum
    #   @return [Fixnum] limited by C signed int range (-2**30 to 2**31-1).

    # @!method maximum
    #   @return [Fixnum] limited by C signed int range (-2**30 to 2**31-1).

    # The definition for IntField additionally supports
    # `minimum` and `maximum` methods.
    # @example minimum and maximum methods
    #   def minimum
    #     50
    #   end
    #
    #   def maximum
    #     200
    #   end
    def cwm_definition
      res = {}

      res["minimum"] = minimum if respond_to?(:minimum)
      res["maximum"] = maximum if respond_to?(:maximum)

      super.merge(res)
    end
  end

  # A selection of a value via radio buttons.
  # The {#label} method is mandatory.
  #
  # @see {ComboBox} for child example
  class RadioButtons < AbstractWidget
    self.widget_type = :radio_buttons

    include ItemsSelection
    abstract_method :label

    # @!method vspacing
    #   @return [Fixnum] space between the options

    # @!method hspacing
    #   @return [Fixnum] margin at both sides of the options list

    def value
      Yast::UI.QueryWidget(Id(widget_id), :CurrentButton)
    end

    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :CurrentButton, val)
    end

    # See AbstractWidget#cwm_definition
    # In addition to the base definition, this honors possible
    # `vspacing` and `hspacing` methods
    #
    # @example defining additional space between the options
    #   def vspacing
    #     1
    #   end
    #
    # @example defining some margin at both sides of the list of options
    #   def hspacing
    #     3
    #   end
    def cwm_definition
      additional = {}
      additional["vspacing"] = vspacing if respond_to?(:vspacing)
      additional["hspacing"] = hspacing if respond_to?(:hspacing)

      super.merge(additional)
    end
  end

  # Widget representing button.
  #
  # @example push button widget child
  #   class MyEvilWidget < CWM::PushButton
  #     def label
  #       _("Win the lottery by clicking this.")
  #     end
  #
  #     def handle
  #       Virus.install
  #       nil
  #     end
  #   end
  class PushButton < AbstractWidget
    self.widget_type = :push_button

    abstract_method :label
  end

  # Widget representing menu button with its submenu
  class MenuButton < AbstractWidget
    self.widget_type = :menu_button

    include ItemsSelection
    abstract_method :label
  end

  # Multiline text widget
  # @note label method is required and used as default value (TODO: incosistent with similar richtext in CWM itself)
  class MultiLineEdit < AbstractWidget
    self.widget_type = :multi_line_edit

    include ValueBasedWidget
    abstract_method :label
  end

  # Rich text widget supporting some highlighting
  class RichText < AbstractWidget
    self.widget_type = :richtext

    include ValueBasedWidget
  end

  # Placeholder widget that is used to replace content on demand.
  # The most important method is {#replace} which allows switching content
  class ReplacePoint < CustomWidget
    # @param id [Object] id of widget. Needed to redefine only if more than one
    # placeholder needed to be in dialog. Parameter type is limited by component
    # system
    # @param widget [CWM::AbstractWidget] initial widget in placeholder
    def initialize(id: "_placeholder", widget: Empty.new("_initial_placeholder"))
      Yast.import "CWM"
      self.handle_all_events = true
      self.widget_id = id
      @widget = widget
    end

    def contents
      ReplacePoint(Id(widget_id), widget_content(@widget))
    end

    def init
      @widget.init if @widget.respond_to?(:init)
    end

    # Replaces content with different widget. All its events are properly
    # handled.
    # @param widget [CWM::AbstractWidget] widget to display and process events
    def replace(widget)
      log.info "replacing with new widget #{widget.inspect}"
      Yast::UI.ReplaceWidget(Id(widget_id), widget_content(widget))
      @widget = widget
      init
    end

    def help
      @widget.respond_to?(:help) ? @widget.help : ""
    end

    def handle(event)
      return unless @widget.respond_to?(:handle)

      if !@widget.handle_all_events
        return if event["ID"] != @widget.widget_id
      end

      m = @widget.method(:handle)
      if m.arity == 0
        m.call
      else
        m.call(event)
      end
    end

    def validate
      @widget.respond_to?(:validate) ? @widget.validate : true
    end

    def store
      @widget.store if @widget.respond_to?(:store)
    end

    def cleanup
      @widget.cleanup if @widget.respond_to?(:cleanup)
    end

  private

    def widget_content(widget)
      definition = widget.cwm_definition
      definition["_cwm_key"] = widget.widget_id # a bit hacky way to pass widget id
      definition = Yast::CWM.prepareWidget(definition)
      definition["widget"]
    end
  end
end
