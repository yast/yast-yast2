# typed: false
require_relative "test_helper"

require "cwm/custom_widget"
require "cwm/rspec"

describe CWM::CustomWidget do
  class CustomTestWidget < CWM::CustomWidget
    def contents
      HBox(
        InputField(Id(:first), "test"),
        PushButton(Id("second"), "Discover 42")
      )
    end
  end
  subject { CustomTestWidget.new }

  include_examples "CWM::CustomWidget"

  context "handle_all_events is false" do
    class IsolationistTestWidget < CustomTestWidget
      def initialize
        self.handle_all_events = false
        self.widget_id = "test_widget"
      end
    end
    describe "#cwm_definition" do
      subject { IsolationistTestWidget.new }

      it "adds to description to handle only ids in contents and widget_id" do
        expect(subject.cwm_definition["handle_events"])
          .to eq [:first, "second", "test_widget"]
      end
    end
  end
end
