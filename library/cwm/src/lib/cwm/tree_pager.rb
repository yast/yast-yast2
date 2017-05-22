require "cwm/page"
require "cwm/pager"

module CWM
  # A {TreeItem} that knows a {Page}, useful for a {TreePager}.
  # The UI label and `id` are taken from its {Page}: {Page#label},
  # {Page#widget_id}
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

    # @return [Array<Page>] My page and all pages of descendant items
    #   (needed to initialize a {Pager}).
    def pages
      children.values.flat_map(&:pages).unshift(@page)
    end
  end

  # A {Pager} that uses a {Tree} to select the {Page}s
  class TreePager < Pager
    # @param items [Array<PagerTreeItem>]
    def initialize(*items, label:)
      @tree = Tree.new(items, label: label)
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
      id = @tree.value if id == @tree.widget_id
      super(id)
    end

    def mark_page(page)
      @tree.value = page.widget_id
    end
  end
end
