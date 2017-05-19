module CWM
  # Tab widget, usefull only with {CWM::Tabs}
  # @see tabs example for usage
  class Tab < CustomWidget
    # @return [Boolean] is this the initially selected tab
    attr_accessor :initial

    # @return [WidgetTerm] contents of the tab, can contain {AbstractWidget}s
    abstract_method :contents
    # @return [String] label defines name of tab header
    abstract_method :label

    # @return [WidgetHash]
    def cwm_definition
      super.merge(
        "widgets"       => cwm_widgets,
        "custom_widget" => Yast::CWM.PrepareDialog(cwm_contents, cwm_widgets)
      )
    end

    # get cwm style of widget definitions
    # @note internal api only used as gate to communicate with CWM
    # @return [Array<WidgetHash>]
    def cwm_widgets
      return @cwm_widgets if @cwm_widgets

      widgets = nested_widgets
      names = widgets.map(&:widget_id)
      definition = Hash[widgets.map { |w| [w.widget_id, w.cwm_definition] }]
      @cwm_widgets = Yast::CWM.CreateWidgets(names, definition)
    end

    # help that is result of used widget helps.
    # If overwritting, do not forget to use `super`, otherwise widget helps will
    # be missing
    def help
      Yast::CWM.MergeHelps(nested_widgets.map(&:cwm_definition))
    end
  end

  # useful to have tabs as widget. It contained {CWM::Tab} with its content
  # @see examples/object_api_tabs.rb
  class Tabs < CustomWidget
    # @param [Array<CWM::Tab>] tabs to be shown
    def initialize(*tabs)
      @tabs = tabs
      @current_tab = nil
      self.handle_all_events = true
    end

    # initializes tabs, show tab which is initial
    def init
      switch_tab(initial_tab_id)
    end

    def handle(event)
      # pass it to content of tab at first, maybe something stop passing
      res = Yast::CWM.handleWidgets(@current_tab.cwm_widgets, event)
      return res if res

      new_id = event["ID"]
      tab = tab_for_id(new_id)

      return nil unless tab

      return nil if @current_tab.widget_id == new_id

      unless validate
        mark_tab(@current_tab)
        return nil
      end

      store_tab(@current_tab.widget_id)

      switch_tab(new_id)

      nil
    end

    # store content of current tab
    def store
      store_tab(@current_tab.widget_id)
    end

    # validates current tab
    def validate
      Yast::CWM.validateWidgets(@current_tab.cwm_definition["widgets"], "ID" => @current_tab.widget_id)
    end

    def help
      @current_tab ? @current_tab.help : ""
    end

  protected

    # gets visual order of tabs
    # This default implementation returns same order as passed to constructor
    def tab_order
      @tabs.map(&:widget_id)
    end

    # stores tab with given id
    def store_tab(tab_id)
      Yast::CWM.saveWidgets(tab_for_id(tab_id).cwm_definition["widgets"], "ID" => tab_id)
    end

    # switch to target tab
    def switch_tab(tab_id)
      tab = tab_for_id(tab_id)
      return unless tab

      mark_tab(tab)
      Yast::UI.ReplaceWidget(Id(replace_point_id), tab.cwm_definition["custom_widget"])
      Yast::CWM.initWidgets(tab.cwm_definition["widgets"])
      @current_tab = tab

      Yast::CWM.ReplaceWidgetHelp(widget_id, help)
    end

    # visually mark currently active tab
    def mark_tab(tab)
      if Yast::UI.HasSpecialWidget(:DumbTab)
        Yast::UI.ChangeWidget(Id(widget_id), :CurrentItem, tab.widget_id)
      else
        if @current_tab
          Yast::UI.ChangeWidget(
            Id(@current_tab.widget_id),
            :Label,
            @current_tab.label
          )
        end
        Yast::UI.ChangeWidget(
          Id(tab.widget_id),
          :Label,
          "#{Yast::UI.Glyph(:BulletArrowRight)}  #{tab.label}"
        )
      end
    end

    # gets id of initial tab
    # This default implementation returns first tab passed to constructor
    def initial_tab_id
      initial = @tabs.find(&:initial)

      (initial || @tabs.first).widget_id
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

    def tab_for_id(id)
      @tabs.find { |t| t.widget_id == id }
    end

  private

    def replace_point_id
      :_cwm_tab_contents_rp
    end

    def replace_point
      ReplacePoint(Id(replace_point_id), VBox(VStretch(), HStretch()))
    end
  end
end
