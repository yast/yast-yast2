#!/usr/bin/env rspec --format doc

require_relative "test_helper"

require "cwm/widget"

describe CWM::CustomWidget do
  describe "#description" do
    context "handle_all_events is false" do
      class CustomTestWidget < CWM::CustomWidget
        def initialize
          self.handle_all_events = false
          self.widget_id = "test_widget"
        end

        def contents
          HBox(
            InputField(Id(:first), "test"),
            PushButton(Id("second"), "Discover 42")
          )
        end
      end
      subject { CustomTestWidget.new }

      it "adds to description to handle only ids in contents and widget_id" do
        expect(subject.description["handle_events"]).to eq [:first, "second", "test_widget"]
      end
    end
  end
end
