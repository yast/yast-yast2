require "abstract_method"
require "cwm/abstract_widget"
require "cwm/custom_widget"

module CWM
  # Represents Table widget
  class Table < CustomWidget
    # @method header
    #   return array of String which is used as headers for table
    # @note have to be overwritten
    abstract_method :header

    # gets initial two dimensional array of Table content
    # one element in the first dimension contain as first element id and then
    # rest is data in table
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

  private

    def contents
      opt_args = respond_to?(:opt, with_private = true) ? opt : []
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
