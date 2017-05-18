require "cwm/pager"

module CWM
  # A {TreeItem} that knows a {Page}, useful for a {TreePager}.
  class PagerTreeItem < TreeItem
    # @return [Proc] returning a Page
    attr_reader :page_proc
    def initialize(id, label,
                   icon: nil, open: true, page_proc: nil, children: [])
      @page_proc = page_proc || -> { raise "TODO define a default empty page" }
      super(id, label, icon: icon, open: open, children: children)
    end

    def self.page(page, icon: nil, open: true, children: [])
      page_proc = -> { page }
      new(page.widget_id, page.label,
          icon: icon, open: open,
          page_proc: page_proc, children: children)
    end

    def pages
      children.values.flat_map(&:pages).unshift(@page_proc.call)
    end
  end

  # A {Pager} that uses a {Tree} to select the {Page}s
  class TreePager < Pager
    # @param items [Array<PagerTreeItem>]
    def initialize(*items)
      @tree = Tree.new(*items)
      pages = items.flat_map(&:pages)
      super(*pages)
    end

    def contents
      HBox(
        HWeight(30, @tree),
        HWeight(70, replace_point)
      )
    end

  protected

    def page_for_id(id)
      if id == @tree.widget_id
        id = @tree.value
      end
      super(id)
    end

    def mark_page(page)
      @tree.value = page.widget_id
    end
  end
end
