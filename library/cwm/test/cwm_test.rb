#! /usr/bin/env rspec --format doc

require_relative "test_helper"

require "yast"
Yast.import "CWM"

# The handler methods must exist because fun_ref needs that
# but they are stubbed out.
module MyHandlers
  def w1_init(_key)
    raise
  end

  def w1_handle(_key, _event)
    raise
  end

  def w1_validate(_key, _event)
    raise
  end

  def w2_store(_key, _event)
    raise
  end

  def w2_handle(_key, _event)
    raise
  end

  def w2_validate(_key, _event)
    raise
  end

  def generic_init(_key)
    raise
  end

  def generic_save(_key, _event)
    raise
  end
end

describe Yast::CWMClass do
  subject { Yast::CWM }
  include Yast
  include MyHandlers

  let(:test_stringterm) { VBox(HBox("w1")) }
  let(:widget_names) { ["w1", "w2"] }
  let(:test_widgets) do
    {
      "w1" => {
        "widget"            => :checkbox,
        "opt"               => [:notify, :immediate],
        "label"             => "Check&Box",
        "init"              => fun_ref(method(:w1_init), "void (string)"),
        "handle"            => fun_ref(
          method(:w1_handle),
          "symbol (string, map)"
        ),
        "validate_type"     => :function,
        "validate_function" => fun_ref(
          method(:w1_validate),
          "boolean (string, map)"
        )
      },
      "w2" => {
        "widget"            => :textentry,
        "label"             => "Text&Entry",
        "store"             => fun_ref(
          method(:w2_store),
          "void (string, map)"
        ),
        "handle"            => fun_ref(
          method(:w2_handle),
          "symbol (string, map)"
        ),
        "validate_type"     => :function,
        "validate_function" => fun_ref(
          method(:w2_validate),
          "boolean (string, map)"
        )
      }
    }
  end

  let(:fallback_funcs) do
    {
      "init"  => fun_ref(method(:generic_init), "void (string)"),
      "store" => fun_ref(method(:generic_save), "void (string, map)")
    }
  end

  let(:created_widgets) { subject.CreateWidgets(widget_names, test_widgets) }
  let(:run_widgets) { subject.mergeFunctions(created_widgets, fallback_funcs) }

  # many public uses
  describe "#CreateWidgets" do
    let(:cw) { created_widgets }

    it "produces an Array" do
      expect(cw).to be_an(Array)
    end

    it "creates Terms at the 'widget' keys" do
      expect(cw[0]["widget"]).to eq(CheckBox(Id("w1"), Opt(:notify, :immediate), "Check&Box"))
      expect(cw[1]["widget"]).to eq(InputField(Id("w2"), Opt(:hstretch), "Text&Entry"))
    end

    # used by other CWM modules+classes
    it "creates the '_cwm_key' keys" do
      expect(cw[0]["_cwm_key"]).to eq("w1")
      expect(cw[1]["_cwm_key"]).to eq("w2")
    end
  end

  # used by CWMTab
  describe "#mergeFunctions" do
    it "uses the second argument as fallback" do
      expect(run_widgets[0]["init"].remote_method).to eq(method(:w1_init))
      expect(run_widgets[0]["store"].remote_method).to eq(method(:generic_save))
      expect(run_widgets[1]["init"].remote_method).to eq(method(:generic_init))
      expect(run_widgets[1]["store"].remote_method).to eq(method(:w2_store))
    end
  end

  # used by CWMTab and CWM::ReplacePoint
  describe "#initWidgets" do
    it "calls init methods" do
      expect(self).to receive(:w1_init).with("w1")
      expect(self).to receive(:generic_init).with("w2")
      subject.initWidgets(run_widgets)
    end

    # used via GetProcessedWidget by yast2-slp-server and yast2
    xit "sets @processed_widget" do
    end

    xit "sets ValidChars" do
    end
  end

  # used by CWMTab and CWM::ReplacePoint
  describe "#saveWidgets" do
    it "calls store methods" do
      expect(self).to receive(:generic_save).with("w1", "ID" => :event)
      expect(self).to receive(:w2_store).with("w2", "ID" => :event)
      subject.saveWidgets(run_widgets, "ID" => :event)
    end

    # used via GetProcessedWidget by yast2-slp-server and yast2
    xit "sets @processed_widget" do
    end
  end

  # used by CWMTab and CWM::ReplacePoint
  describe "#handleWidgets" do
    it "calls the handle methods" do
      expect(self).to receive(:w1_handle).with("w1", "ID" => :event).and_return(nil)
      expect(self).to receive(:w2_handle).with("w2", "ID" => :event).and_return(nil)
      expect(subject.handleWidgets(run_widgets, "ID" => :event)).to eq(nil)
    end

    it "breaks the loop if a handler returns non-nil" do
      expect(self).to receive(:w1_handle).with("w1", "ID" => :event).and_return(:foo)
      expect(self).to_not receive(:w2_handle)
      expect(subject.handleWidgets(run_widgets, "ID" => :event)).to eq(:foo)
    end

    xit "sets @processed_widget" do
    end

    xit "filters the events if 'handle_events' is specified" do
    end
  end

  describe "#validateWidgets" do
    it "calls the validate methods" do
      expect(self).to receive(:w1_validate).with("w1", "ID" => :event).and_return(true)
      expect(self).to receive(:w2_validate).with("w2", "ID" => :event).and_return(true)
      expect(subject.validateWidgets(run_widgets, "ID" => :event)).to eq(true)
    end

    it "breaks the loop if a handler returns false" do
      expect(self).to receive(:w1_validate).with("w1", "ID" => :event).and_return(false)
      expect(self).to_not receive(:w2_validate)
      expect(subject.validateWidgets(run_widgets, "ID" => :event)).to eq(false)
    end

    # SetValidationFailedHandler
    xit "calls validation_failed_handler if..." do
    end
  end

  # Used by many packages. All known uses are of the form
  # `contents = CWM.PrepareDialog(contents, ...)`
  describe "#PrepareDialog" do
    it "returns early if the term is empty" do
      expect(subject).to_not receive(:ProcessTerm)
      expect(subject.PrepareDialog(VBox(), test_widgets)).to eq(VBox())
    end

    it "prepares args for ProcessTerm" do
      expect(subject).to receive(:ProcessTerm).with(test_stringterm, Hash)
      subject.PrepareDialog(test_stringterm, created_widgets)
    end
  end

  # tested via its adapter PrepareDialog
  # YAY, a private method
  describe "#ProcessTerm" do
    it "replaces string ids with UI terms" do
      ret = subject.PrepareDialog(test_stringterm, created_widgets)
      w1 = ret.params[0].params[0] # inside VBox, HBox
      expect(w1).to eq(CheckBox(Id("w1"), Opt(:notify, :immediate), "Check&Box"))
    end

    xit "recurses into container widgets" do
    end

    it "leaves Frame titles alone" do
      ret = subject.PrepareDialog(Frame("Config", test_stringterm), created_widgets)
      expect(ret.params[0]).to eq("Config")
    end

    it "leaves id'd Frame titles alone" do
      ret = subject.PrepareDialog(Frame(Id("f1"), "Config", test_stringterm), created_widgets)
      expect(ret.params[1]).to eq("Config")
    end
  end
end
