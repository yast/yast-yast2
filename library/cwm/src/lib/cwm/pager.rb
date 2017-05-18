module CWM
  # A {Pager} contains several {Page}s and makes only one visible at a time.
  #
  # {TreePager} is a {Pager}.
  #
  # {Tabs} is a {Pager} and a {Tab} is its {Page}
  # (FIXME: We haven't made Tabs a subclass of Pager yet.
  # That will come after we have TreePager working.
  #
  # @see examples/object_api_tabs.rb
  class Pager < CustomWidget
    # @param [Array<CWM::Page>] pages to be shown
    def initialize(*pages)
      @pages = pages
      @current_page = nil
      self.handle_all_events = true
    end

    # initializes pages, show page which is initial
    def init
      switch_page(initial_page_id)
    end

    def handle(event)
      # pass it to content of page at first, maybe something stop passing
      res = Yast::CWM.handleWidgets(@current_page.cwm_widgets, event)
      return res if res

      new_id = event["ID"]
      page = page_for_id(new_id)

      return nil unless page

      return nil if @current_page.widget_id == new_id

      unless validate
        mark_page(@current_page)
        return nil
      end

      store_page(@current_page.widget_id)

      switch_page(new_id)

      nil
    end

    # store content of current page
    def store
      store_page(@current_page.widget_id)
    end

    # validates current page
    def validate
      Yast::CWM.validateWidgets(@current_page.cwm_definition["widgets"], "ID" => @current_page.widget_id)
    end

    def help
      @current_page ? @current_page.help : ""
    end

  protected

    # gets visual order of pages
    # This default implementation returns same order as passed to constructor
    def page_order
      @pages.map(&:widget_id)
    end

    # stores page with given id
    def store_page(page_id)
      Yast::CWM.saveWidgets(page_for_id(page_id).cwm_definition["widgets"], "ID" => page_id)
    end

    # switch to target page
    def switch_page(page_id)
      page = page_for_id(page_id)
      return unless page

      mark_page(page)
      Yast::UI.ReplaceWidget(Id(replace_point_id), page.cwm_definition["custom_widget"])
      Yast::CWM.initWidgets(page.cwm_definition["widgets"])
      @current_page = page

      Yast::CWM.ReplaceWidgetHelp(widget_id, help)
    end

    # Mark the currently active page in the selector
    def mark_page(tab)
      if Yast::UI.HasSpecialWidget(:DumbTab)
        Yast::UI.ChangeWidget(Id(widget_id), :CurrentItem, tab.widget_id)
      else
        if @current_page
          Yast::UI.ChangeWidget(
            Id(@current_page.widget_id),
            :Label,
            @current_page.label
          )
        end
        Yast::UI.ChangeWidget(
          Id(tab.widget_id),
          :Label,
          "#{Yast::UI.Glyph(:BulletArrowRight)}  #{tab.label}"
        )
      end
    end

    # gets id of initial page
    # This default implementation returns first page passed to constructor
    def initial_page_id
      initial = @pages.find(&:initial)

      (initial || @pages.first).widget_id
    end

    def contents
      if Yast::UI.HasSpecialWidget(:DumbTab)
        panes = tab_order.map do |tab_id|
          tab = tab_for_id(tab_id)
          Item(Id(tab.widget_id), tab.label, tab.widget_id == initial_tab_id)
        end
        DumbTab(Id(widget_id), panes, replace_point)
      else
        tabbar = tab_order.each_with_object(HBox()) do |tab, res|
          tab = tab_for_id(tab)
          res << PushButton(Id(tab.widget_id), tab.label)
        end
        VBox(Left(tabbar), Frame("", replace_point))
      end
    end

    def page_for_id(id)
      @pages.find { |t| t.widget_id == id }
    end

  private

    def replace_point_id
      :_cwm_page_contents_rp
    end

    def replace_point
      ReplacePoint(Id(replace_point_id), VBox(VStretch(), HStretch()))
    end
  end
end
