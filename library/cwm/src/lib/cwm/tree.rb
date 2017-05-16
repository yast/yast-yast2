module CWM
  # A Tree widget item
  class TreeItem
    attr_reader :id, :label, :icon, :open, :data
    # @return [Hash{id => TreeItem}]
    attr_reader :children

    def initialize(id, label, icon: nil, open: true, data: nil, children: {})
      @id = id
      @label = label
      @icon = icon
      @open = open
      @data = data
      @children = children
    end

    def ui_term
      args = [Id(id)]
      args << Yast::Term.new(:icon, icon) if icon
      args << label
      args << open
      args << children.values.map(&:ui_term)
      Item(*args)
    end
  end

  # Tree widget CWM object
  class Tree < Tabs
    def contents
      item_terms = items.map { |_id, i| i.ui_term }
      tree = Tree(Id(widget_id), Opt(:notify), label, item_terms)
      HBox(
        HWeight(30, tree),
        HWeight(70, replace_point)
      )
    end

  private

    def init
      # nothing, dont select initial "tab" yet
    end

    # Subclass will override
    def label
      "?"
    end

    # Subclass will override
    # Hash
    def items
      {}
    end
  end
end
