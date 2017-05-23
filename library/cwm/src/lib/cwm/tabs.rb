require "cwm/page"
require "cwm/pager"

module CWM
  # Compatibility alias.
  # (Tab and Tabs were here first, later Page and Pager
  # were abstracted to allow for TreePager)
  Tab = Page

  # @see examples/object_api_tabs.rb
  class Tabs < Pager
  protected

    # visually mark currently active tab
    # @param page [Page]
    def mark_page(page)
      if Yast::UI.HasSpecialWidget(:DumbTab)
        Yast::UI.ChangeWidget(Id(widget_id), :CurrentItem, page.widget_id)
      else
        if @current_page
          Yast::UI.ChangeWidget(
            Id(@current_page.widget_id),
            :Label,
            @current_page.label
          )
        end
        Yast::UI.ChangeWidget(
          Id(page.widget_id),
          :Label,
          "#{Yast::UI.Glyph(:BulletArrowRight)}  #{page.label}"
        )
      end
    end

    def contents
      if Yast::UI.HasSpecialWidget(:DumbTab)
        panes = page_order.map do |page_id|
          page = page_for_id(page_id)
          Item(Id(page.widget_id), page.label, page.widget_id == initial_page_id)
        end
        DumbTab(Id(widget_id), panes, replace_point)
      else
        tabbar = page_order.each_with_object(HBox()) do |page, res|
          page = page_for_id(page)
          res << PushButton(Id(page.widget_id), page.label)
        end
        VBox(Left(tabbar), Frame("", replace_point))
      end
    end
  end
end
