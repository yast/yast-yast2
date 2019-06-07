# typed: true
require "yast"

require "cwm/abstract_widget"

module CWM
  # Wrapper when combination of old hash based CWM definition needed to be used
  # with new object based one. Useful e.g. when content is provided by other
  # module like CWMFirewallInterfaces.CreateOpenFirewallWidget
  # @note it does not support some of common methods and helpers from abstract widget
  #
  # @example how to initialize object from firewall interface
  #   ::CWM::WrapperWidget.new("firewall",
  #     CWMFirewallInterfaces.CreateOpenFirewallWidget("services" => ["service:sshd", "service:ntp"])
  #   )
  class WrapperWidget < AbstractWidget
    # Creates new instance with specified id and content
    # @param id [String] name of widget used as identified, have to be unique.
    #   It have to be same as real widget id in content, otherwise enable/disable won't work.
    #   If nil is used, it use default widget_id from class name.
    # @param content [CWM::WidgetHash] CWM hash definition
    def initialize(content, id: nil)
      self.widget_id = id if id
      @content = content
    end

    # returns given hash specification
    def cwm_definition
      @content.merge("_cwm_key" => widget_id)
    end

    def handle_all_events
      @content["handle_events"].nil?
    end

    # not supported
    # @raise [RuntimeError] always when called
    def handle_all_events=(_arg)
      raise "Not supported for WrapperWidget"
    end

    # not supported
    # @raise [RuntimeError] always when called
    def self.widget_type=(_arg)
      raise "Not supported for WrapperWidget"
    end
  end
end
