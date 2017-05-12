module CWM
  class Tree < Tabs
    def contents
      tree = Tree(Id(widget_id), Opt(:notify), "TODO Tree title", items)
      HBox(
        HWeight(30, tree),
        HWeight(70, replace_point)
      )
    end

    private

    def tab_for_id(id)
      if id == widget_id
        id = Yast::UI.QueryWidget(Id(id), :CurrentBranch).last
      end
      super(id)
    end

    def items
      # FIXME too simple
      panes = tab_order.map do |tab_id|
        tab = tab_for_id(tab_id)
        item_for(tab.widget_id, tab.label)
      end
      panes
    end

    def item_for(id, title, icon: nil, subtree: [])
      args = [Id(id)]
      args << Yast::Term.new(:icon, icon) if icon
      args << title
      args << open?(id)
      args << subtree
      Item(*args)
    end

    def open?(id)
      id == initial_tab_id
    end
  end
end
