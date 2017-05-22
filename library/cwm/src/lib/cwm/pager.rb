require "abstract_method"

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

    # Mark the currently active page in the selector.
    # This is needed in case the user has switched to a different page
    # but we need to switch back because the current one failed validation.
    # @param page [Page]
    # @return [void]
    abstract_method :mark_page

    # The contents will probably include a *selector*, such as {Tabs}
    # or {Tree} and a {ReplacePoint} where {Page}s will appear.
    # @return [WidgetTerm]
    abstract_method :contents

    # gets id of initial page
    # This default implementation returns first page passed to constructor
    def initial_page_id
      initial = @pages.find(&:initial)

      (initial || @pages.first).widget_id
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
