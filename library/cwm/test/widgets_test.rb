#! /usr/bin/env rspec

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
      expect { TNoWidgetType.new.cwm_definition }.to raise_error(RuntimeError)
    end

    class THelp < CWM::AbstractWidget
      self.widget_type = :empty
      def help
        "helpful string"
      end
    end

    it "returns hash with \"help\" key and #help result as value" do
      expect(THelp.new.cwm_definition["help"]).to eq "helpful string"
    end

    class TNoHelp < CWM::AbstractWidget
      self.widget_type = :empty
    end

    it "returns hash with \"no_help\" key if no help method specified" do
      expect(TNoHelp.new.cwm_definition).to be_key("no_help")
    end

    class TLabel < CWM::AbstractWidget
      self.widget_type = :empty
      def label
        "helpful string"
      end
    end

    it "returns hash with \"label\" key and #label result as value" do
      expect(TLabel.new.cwm_definition["label"]).to eq "helpful string"
    end

    class TOpt < CWM::AbstractWidget
      self.widget_type = :empty
      def opt
        [:notify]
      end
    end

    it "returns hash with \"opt\" key and #opt result as value" do
      expect(TOpt.new.cwm_definition["opt"]).to eq [:notify]
    end

    class TWidget < CWM::AbstractWidget
      self.widget_type = :empty
    end

    it "returns hash with \"widget\" key and #widget_type result as value" do
      expect(TWidget.new.cwm_definition["widget"]).to eq :empty
    end

    context "handle_all_events set to false" do
      class THandleEvents < CWM::AbstractWidget
        self.widget_type = :empty

        def initialize
          self.widget_id = "test"
          self.handle_all_events = false
        end
      end

      it "returns hash with \"handle_events\" key and array with #widget_id result as value" do
        expect(THandleEvents.new.cwm_definition["handle_events"]).to eq ["test"]
      end
    end

    context "handle_all_events set to true" do
      class TNotHandleEvents < CWM::AbstractWidget
        self.widget_type = :empty

        def initialize
          self.handle_all_events = true
        end
      end

      it "returns hash without \"handle_events\" key" do
        expect(TNotHandleEvents.new.cwm_definition).to_not be_key("handle_events")
      end
    end

    class TInit < CWM::AbstractWidget
      self.widget_type = :empty
      def init
      end
    end

    it "returns hash with key init when init method defined" do
      expect(TInit.new.cwm_definition).to be_key("init")
    end

    class THandle1 < CWM::AbstractWidget
      self.widget_type = :empty
      def handle
      end
    end

    it "returns hash with key handle when handle without parameter defined" do
      expect(THandle1.new.cwm_definition).to be_key("handle")
    end

    class THandle2 < CWM::AbstractWidget
      self.widget_type = :empty
      def handle(_event)
      end
    end

    it "returns hash with key handle when handle with parameter defined" do
      expect(THandle2.new.cwm_definition).to be_key("handle")
    end

    class TStore < CWM::AbstractWidget
      self.widget_type = :empty
      def store
      end
    end

    it "returns hash with key store when store method defined" do
      expect(TStore.new.cwm_definition).to be_key("store")
    end

    class TCleanup < CWM::AbstractWidget
      self.widget_type = :empty
      def cleanup
      end
    end

    it "returns hash with key cleanup when cleanup method defined" do
      expect(TCleanup.new.cwm_definition).to be_key("cleanup")
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
        expect(subject.cwm_definition["handle_events"]).to eq [:first, "second", "test_widget"]
      end
    end
  end
end

describe CWM::ReplacePoint do

  class ReplacePointTestWidget < CWM::InputField
    def label
      "test"
    end

    def init
    end

    def handle
    end

    def help
      "help"
    end

    def validate
      false
    end

    def store
    end

    def cleanup
    end
  end

  describe ".new" do
    it "has widget_id as passed" do
      subject = described_class.new(id: "test")
      expect(subject.widget_id).to eq "test"
    end

    it "uses passed widget as initial content" do
      widget = ReplacePointTestWidget.new
      subject = described_class.new(widget: widget)
      expect(widget).to receive(:init)
      subject.init
    end
  end

  describe "#contents" do
    it "generates contents including current widget UI definition" do
      widget = ReplacePointTestWidget.new
      subject = described_class.new(widget: widget)

      expect(subject.contents).to eq(
        ReplacePoint(
          Id(subject.widget_id),
          InputField(Id(widget.widget_id), Opt(:hstretch), "test")
        )
      )
    end
  end

  describe "#init" do
    it "passes init to enclosed widget" do
      widget = ReplacePointTestWidget.new
      subject = described_class.new(widget: widget)
      expect(widget).to receive(:init)
      subject.init
    end
  end

  describe "#replace" do
    it "changes enclosed widget" do
      subject = described_class.new(widget: CWM::Empty.new(:initial))
      widget = ReplacePointTestWidget.new
      expect(widget).to receive(:store)
      subject.replace(widget)
      subject.store
    end
  end

  describe "#help" do
    it "returns help of enclosed widget" do
      widget = ReplacePointTestWidget.new
      subject = described_class.new(widget: widget)
      expect(subject.help).to eq "help"
    end
  end

  class ComplexHandleTest < CWM::Empty
    def handle(_event)
      nil
    end
  end

  describe "#handle" do
    # Cannot test arity based dispatcher, because if we mock expect call of widget.handle, it is
    # replaced by rspec method with -1 arity, causing wrong dispatcher functionality

    it "do nothing if passed event is not widget_id and enclosed widget do not handle all events" do
      widget = ReplacePointTestWidget.new
      subject = described_class.new(widget: widget)
      expect(widget).to_not receive(:handle)
      subject.handle("ID" => "Not mine")
    end
  end

  describe "#validate" do
    it "passes validate to enclosed widget" do
      widget = ReplacePointTestWidget.new
      subject = described_class.new(widget: widget)
      expect(subject.validate).to eq false
    end
  end

  describe "#store" do
    it "passes store to enclosed widget" do
      widget = ReplacePointTestWidget.new
      subject = described_class.new(widget: widget)
      expect(widget).to receive(:store)
      subject.store
    end
  end

  describe "#cleanup" do
    it "passes cleanup to enclosed widget" do
      widget = ReplacePointTestWidget.new
      subject = described_class.new(widget: widget)
      expect(widget).to receive(:cleanup)
      subject.cleanup
    end
  end
end
