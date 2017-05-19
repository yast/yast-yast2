require "cwm/page"
require "cwm/pager"

module CWM
  # A {TreeItem} that knows a {Page}, useful for a {TreePager}.
  class PagerTreeItem < TreeItem
    # @return [Page]
    attr_reader :page

    # @param page [Page]
    # @param children [Array<PagerTreeItem>]
    def initialize(page, icon: nil, open: true, children: [])
      @page = page
      super(page.widget_id, page.label,
            icon: icon, open: open, children: children)
    end

    def pages
      children.values.flat_map(&:pages).unshift(@page)
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
