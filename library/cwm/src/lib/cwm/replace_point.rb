require "yast"
require "cwm/custom_widget"

Yast.import "UI"
Yast.import "CWM"

module CWM
  # Placeholder widget that is used to replace content on demand.
  # The most important method is {#replace} which allows switching content
  class ReplacePoint < CustomWidget
    # @param id [Object] id of widget. Needed to redefine only if more than one
    # placeholder needed to be in dialog. Parameter type is limited by component
    # system
    # @param widget [CWM::AbstractWidget] initial widget in placeholder
    def initialize(id: "_placeholder", widget:)
      self.handle_all_events = true
      self.widget_id = id
      @widget = widget
    end

    # @return [UITerm]
    def contents
      # In `contents` we must use an Empty Term, otherwise CWMClass
      # would see an {AbstractWidget} and handle events itself,
      # which result in double calling of methods like {handle} or {store} for
      # initial widget.
      ReplacePoint(Id(widget_id), Empty(Id("___cwm_rp_empty")))
    end

    # switches to initial widget
    def init
      replace(@widget)
    end

    # Replaces content with different widget. All its events are properly
    # handled.
    # @param widget [CWM::AbstractWidget] widget to display and process events
    def replace(widget)
      Yast::Builtins.y2milestone("REPLACE BEG %1", t1 = Time.now.to_f)
      widgets = Yast::CWM.widgets_in_contents([widget])
      @widgets_hash = widgets.map { |w| Yast::CWM.prepareWidget(w.cwm_definition) }
      # VBox as CWM ignore top level term and process string inside it,
      # so non-container widgets have problem and its value is processed
      term = Yast::CWM.PrepareDialog(VBox(widget.widget_id), @widgets_hash)
      Yast::UI.ReplaceWidget(Id(widget_id), term)
      Yast::CWM.initWidgets(@widgets_hash)
      @widget = widget
      refresh_help
      Yast::Builtins.y2milestone("REPLACE END %1; %2", t2 = Time.now.to_f, t2 - t1)
    end

    # Passes to replace point content
    def handle(event)
      Yast::CWM.handleWidgets(@widgets_hash, event)
    end

    # Dynamic help, that compute help of current displayed widgets
    def help
      Yast::CWM.MergeHelps(@widgets_hash)
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
