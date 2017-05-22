module CWM
  # A page widget is a group of widgets that are contained within it.
  # Several pages are in turn contained within a {Pager}.
  #
  # {TreePager} is a {Pager}.
  #
  # {Tabs} is a {Pager} and a {Tab} is its {Page}
  # (FIXME: We haven't made Tabs a subclass of Pager yet.
  # That will come after we have TreePager working.
  class Page < CustomWidget
    # @return [Boolean] is this the initially selected tab
    attr_accessor :initial

    # @return [WidgetTerm] contents of the tab, can contain {AbstractWidget}s
    attr_reader :contents
    # @return [String] Label of {Tab} or of {PagerTreeItem}
    attr_reader :label
    # @return [Symbol,String]
    attr_reader :widget_id

    def initialize(widget_id:, label:, contents:)
      @widget_id = widget_id
      @label = label
      @contents = contents
    end

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
end
