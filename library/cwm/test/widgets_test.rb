#!/usr/bin/env rspec --format doc

require_relative "test_helper"

require "cwm/widget"

describe CWM::AbstractWidget do
  describe "#widget_id" do
    class T1 < CWM::AbstractWidget
      def initialize(id: nil)
        self.widget_id = id
      end
    end

    it "returns string specified by #widget_id=" do
      widget = T1.new(id: "test")
      expect(widget.widget_id).to eq "test"
    end

    it "returns class as string if not specified by #widget_id=" do
      widget = T1.new
      expect(widget.widget_id).to eq "T1"
    end
  end

  describe "#widget_type" do
    class T2 < CWM::AbstractWidget
      self.widget_type = :empty
    end

    it "return symbol of widget type specified by .widget_type=" do
      expect(T2.new.widget_type).to eq :empty
    end
  end

  describe "#handle_all_events" do
    class T3 < CWM::AbstractWidget
      def initialize(all: nil)
        self.handle_all_events = all
      end
    end

    it "returns boolean specified by #handle_all_events=" do
      widget = T3.new(all: true)
      expect(widget.handle_all_events).to eq true
    end

    it "returns false if not specified by #handle_all_events=" do
      widget = T3.new
      expect(widget.handle_all_events).to eq false
    end
  end

  describe "#description" do

    class TNoWidgetType < CWM::AbstractWidget; end

    it "raises exception if widget type in child is not specified" do
      expect{TNoWidgetType.new.description}.to raise_error(RuntimeError)
    end

    class THelp < CWM::AbstractWidget
      self.widget_type = :empty
      def help
        "helpful string"
      end
    end

    it "returns hash with \"help\" key and #help result value" do
      expect(THelp.new.description["help"]).to eq "helpful string"
    end

    class TNoHelp < CWM::AbstractWidget
      self.widget_type = :empty
    end

    it "returns hash with \"no_help\" key if no help method specified" do
      expect(TNoHelp.new.description).to be_key("no_help")
    end
  end
end

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
