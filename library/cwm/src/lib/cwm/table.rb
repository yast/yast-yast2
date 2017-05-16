require "abstract_method"
require "cwm/custom_widget"

module CWM
  # Represents Table widget
  class Table < CustomWidget
    # @method header
    #   return array of String or Yast::Term which is used as headers for table
    #   it can use e.g. align Left/Center/Right
    # @note have to be overwritten
    #
    # @example of header
    #   def header
    #     [
    #       _("First Name"),
    #       Right(_("Surname")
    #     ]
    #   end
    abstract_method :header

    # gets initial two dimensional array of Table content
    # one element in the first dimension contain as first element id and then
    # rest is data in table, which can be e.g. terms. Then it have to be enclosed in
    # `cell` term.
    # @see for more complex example see examples directory
    #
    # @example for table with two collumns
    #   def items
    #     [
    #       [:first_user, "Joe", "Doe"],
    #       [:best_user, "Chuck", "Norris"]
    #     ]
    #   end
    def items
      []
    end

    # change list on fly with argument. Useful when content of widget is changed.
    # @arg items_list [Array<Array<Object>>] same format as {#items}
    def change_items(items_list)
      Yast::UI.ChangeWidget(Id(widget_id), :Items, format_items(items_list))
    end

  protected

    # helper to create icon term
    # @arg path [String] path to icon
    def icon(path)
      Yast::Term.new(:icon, path)
    end

    # helper to create icon term
    # @arg args content of cell, often used to combine icon and string
    #
    # @example
    #   cell(icon("/tmp/cool_icon.png"), "Really cool!!!")
    def cell(*args)
      Yast::Term.new(:cell, *args)
    end

  private

    def contents
      opt_args = respond_to?(:opt, true) ? opt : []
      Table(
        Id(widget_id),
        Opt(*opt_args),
        Header(*header),
        format_items(items)
      )
    end

    def format_items(items)
      items.map do |item|
        Item(Id(item.first), *item[1..-1])
      end
    end
  end
end
