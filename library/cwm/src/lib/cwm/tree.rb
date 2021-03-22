# typed: false
require "cwm/custom_widget"

module CWM
  # A {Tree} widget item
  class TreeItem
    # @return what to put in Id
    attr_reader :id
    # @return [String]
    attr_reader :label
    # @return [String] icon filename
    attr_reader :icon
    # @return [Boolean] is the subtree open?
    attr_reader :open
    # @return [Hash{id => TreeItem}]
    attr_reader :children

    def initialize(id, label, icon: nil, open: true, children: [])
      @id = id
      @label = label
      @icon = icon
      @open = open
      @children = children.map { |c| [c.id, c] }.to_h
    end

    def ui_term
      args = [Yast::Term.new(:id, id)]
      args << Yast::Term.new(:icon, icon) if icon
      args << label
      args << open
      args << children.values.map(&:ui_term)
      Yast::Term.new(:item, *args)
    end
  end

  # A tree of nested {TreeItem}s
  class Tree < CustomWidget
    def contents
      item_terms = items.map(&:ui_term)
      Tree(Id(widget_id), Opt(:notify), label, item_terms)
    end

    # FIXME: CurrentBranch? item id uniqueness?
    # TODO: extract value/value= to CurrentItemBasedWidget
    # or declare: value_property :CurrentItem
    def value
      Yast::UI.QueryWidget(Id(widget_id), :CurrentItem)
    end

    def value=(val)
      Yast::UI.ChangeWidget(Id(widget_id), :CurrentItem, val)
    end

    # An alias for {TreeItem#initialize TreeItem.new}
    def new_item(*args, **kwargs)
      TreeItem.new(*args, **kwargs)
    end

    # @return [Enumerable<TreeItem>]
    def items
      []
    end

    # @param items [Array<TreeItem>]
    def change_items(items)
      item_terms = items.map(&:ui_term)
      Yast::UI.ChangeWidget(Id(widget_id), :Items, item_terms)
    end
  end
end
