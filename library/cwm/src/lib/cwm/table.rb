require "abstract_method"
require "cwm/custom_widget"

module CWM
  # An entry of a {Table}
  class TableItem
    # @return [String, Symbol]
    attr_reader :id

    # @return [Array]
    attr_reader :values

    # @see Table#items
    # @return [Array<TableItem, Array>]
    attr_reader :children

    # @return [Boolean] whether children are initially expanded
    attr_reader :open

    def initialize(id, values, open: true, children: [])
      @id = id
      @values = values
      @open = open
      @children = children
    end
  end

  # Represents Table widget
  class Table < CustomWidget
    # @method header
    #   return array of String or Yast::Term which is used as headers for table
    #   it can use e.g. align Left/Center/Right
    # @note It has to be overwritten
    # @return [Array<String|Yast::Term>]
    #
    # @example of header
    #   def header
    #     [
    #       _("First Name"),
    #       Right(_("Surname")
    #     ]
    #   end
    abstract_method :header

    # Array with the table content
    #
    # Each element can be a {TableItem} or an Array. The helper {#item} can be used to easily
    # create {TableItem} objects.
    #
    # If it's an array, the row contains no nested elements. The first element represents
    # the id of the row and the rest is used as data for its cells. Those can be e.g. terms.
    # Then it has to be enclosed in `cell` term.
    #
    # @see for more complex example see examples directory
    # @note default value is empty array. It is useful when computation expensive content
    #   need to be set. In such case, it is better to keep empty items to quickly show table and
    #   then in #init call #change_items method, so it will be filled when all widgets are at place
    #   and just filling its content.
    #
    # @example for table with two columns
    #   def items
    #     [
    #       item(:first_user, ["Joe", "Doe"], children: first_children),
    #       [:best_user, "Chuck", "Norris"]
    #     ]
    #   end
    #
    #   def first_children
    #     [
    #       [:first_sub1, "SubJoe1", "Doe"],
    #       [:first_sub2, "SubJoe2", "Doe"]
    #     ]
    #   end
    #
    # @return [Array<TableItem, Array>]
    def items
      []
    end

    # change list on fly with argument. Useful when content of widget is changed.
    # @note items and change_items is consistent with ItemsSelection mixin, just format of
    #   items is different due to nature of Table content.
    # @param items_list [Array] same format as {#items}
    def change_items(items_list)
      Yast::UI.ChangeWidget(Id(widget_id), :Items, format_items(items_list))
    end

    # gets id of selected item in table or array of ids if multiselection option is used
    # @return [Array<Object>, Object] array if multiselection? return true
    def value
      val = Yast::UI.QueryWidget(Id(widget_id), :SelectedItems)
      multiselection? ? val : val.first
    end

    # sets id of selected item(-s) in table
    # @param id [Object, Array<Object>] selected id, if multiselection? is true
    #   it require array of ids to select
    def value=(id)
      Yast::UI.ChangeWidget(Id(widget_id), :SelectedItems, Array(id))
    end

    # Replaces content of single cell
    # @param id [Object] id of row ( the first element in #items )
    # @param column_number [Integer] index of cell in row. Index start with 0 for first cell.
    # @param cell_content [String, Yast::Term, Object] Content of cell. Support same stuff as #items
    # @note more efficient for bigger tables then changing everything with #change_items
    def change_cell(id, column_number, cell_content)
      Yast::UI.ChangeWidget(Id(widget_id), Cell(id, column_number), cell_content)
    end

    # Resulting table as YUI term.
    # @note used mainly to pass it CWM.
    def contents
      opt_args = respond_to?(:opt, true) ? opt : []
      Table(
        Id(widget_id),
        Opt(*opt_args),
        Header(*header),
        format_items(items)
      )
    end

  protected

    # helper to create icon term
    # @param path [String] path to icon
    def icon(path)
      Yast::Term.new(:icon, path)
    end

    # helper to create sort-key term
    # @param value [String] sort-key
    def sort_key(value)
      Yast::Term.new(:sortKey, value)
    end

    # helper to create icon term
    # @param args content of cell, often used to combine icon and string
    # @note Please see difference between `Cell` and `cell`. The first one is
    #   used in queries to pick exact cell, but later is used for content of cell.
    #   For reasons ask libyui authors.
    #
    # @example
    #   cell(icon("/tmp/cool_icon.png"), "Really cool!!!")
    def cell(*args)
      Yast::Term.new(:cell, *args)
    end

    # helper to create a {TableItem}
    # @param args content of item
    # @note Not to be confused with the UI shortcut `Item`
    #
    # @example
    #   item(:joe, ["Joe", "Doe"], children: [[:joeson, "Joeson", "Doe"]], open: false)
    def item(*args)
      TableItem.new(*args)
    end

    # helper to say if table have multiselection
    def multiselection?
      return false unless respond_to?(:opt, true)

      opt.include?(:multiSelection)
    end

  private

    def format_items(items)
      items.map { |i| format_item(i) }
    end

    # @see #format_items
    def format_item(item)
      return Item(Id(item.first), *item[1..-1]) if item.is_a?(Array)

      children = format_items(item.children)
      open_tag = item.open ? :open : :closed
      Item(Id(item.id), *item.values, children, open_tag)
    end
  end
end
