module CWM
  # Placeholder widget that is used to replace content on demand.
  # The most important method is {#replace} which allows switching content
  class ReplacePoint < CustomWidget
    # @param id [Object] id of widget. Needed to redefine only if more than one
    # placeholder needed to be in dialog. Parameter type is limited by component
    # system
    # @param widget [CWM::AbstractWidget] initial widget in placeholder
    def initialize(id: "_placeholder", widget: Empty.new("_initial_placeholder"))
      Yast.import "CWM"
      self.handle_all_events = true
      self.widget_id = id
      @widget = widget
    end

    # @return [UITerm]
    def contents
      ReplacePoint(Id(widget_id), Empty(Id("____CWM_empty")))
    end

    # Switches to initial widgets
    def init
      replace(@widget)
    end

    # Replaces content with different widget. All its events are properly
    # handled.
    # @param widget [CWM::AbstractWidget] widget to display and process events
    def replace(widget)
      log.info "replacing with new widget #{widget.inspect}"
      widgets = Yast::CWM.widgets_in_contents([widget])
      @widgets_hash = widgets.map { |w| Yast::CWM.prepareWidget(w.cwm_definition) }
      log.info "widgets hash is #{@widgets_hash.inspect}"
      # VBox as CWM ignore top level term and process string inside it,
      # so non-container widgets have problem and its value is processed
      term = Yast::CWM.PrepareDialog(VBox(widget.widget_id), @widgets_hash)
      log.info "term to use is #{term.inspect}"
      Yast::UI.ReplaceWidget(Id(widget_id), term)
      Yast::CWM.initWidgets(@widgets_hash)
      @widget = widget
      Yast::CWM.ReplaceWidgetHelp(widget_id, Yast::CWM.MergeHelps(@widgets_hash))
    end

    # Passes to replace point content
    def handle(event)
      Yast::CWM.handleWidgets(@widgets_hash, event)
    end

    # Passes to replace point content
    def validate
      Yast::CWM.validateWidgets(@widgets_hash, "ID" => widget_id)
    end

    # Passes to replace point content
    def store
      Yast::CWM.saveWidgets(@widgets_hash, "ID" => widget_id)
    end

    # Passes to replace point content
    def cleanup
      Yast::CWM.cleanupWidgets(@widgets_hash)
    end
  end
end
