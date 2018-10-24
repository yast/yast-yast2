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
        "opt"               => %i[notify immediate],
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
      },
      "w3" => {
        "widget"        => :custom,
        "custom_widget" => HBox("w2", "w2")
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
    it "sets @processed_widget" do
      allow(self).to receive(:w1_init)
      allow(self).to receive(:generic_init)
      expect(subject).to receive(:processed_widget=).twice
      subject.initWidgets(run_widgets)
    end

    it "sets ValidChars" do
      allow(self).to receive(:w1_init)
      allow(self).to receive(:generic_init)
      widgets = deep_copy(run_widgets)
      widgets[0]["valid_chars"] = "ABC"
      expect(Yast::UI).to receive(:ChangeWidget).with(Id("w1"), :ValidChars, "ABC")
      subject.initWidgets(widgets)
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
    it "sets @processed_widget" do
      allow(self).to receive(:generic_save)
      allow(self).to receive(:w2_store)
      expect(subject).to receive(:processed_widget=).twice
      subject.saveWidgets(run_widgets, "ID" => :event)
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

    it "sets @processed_widget" do
      allow(self).to receive(:w1_handle).and_return(nil)
      allow(self).to receive(:w2_handle).and_return(nil)
      expect(subject).to receive(:processed_widget=).twice
      subject.handleWidgets(run_widgets, "ID" => :event)
    end

    it "filters the events if 'handle_events' is specified" do
      expect(self).to_not receive(:w1_handle)
      allow(self).to receive(:w2_handle)
      widgets = deep_copy(run_widgets)
      widgets[0]["handle_events"] = [:special_event]
      subject.handleWidgets(widgets, "ID" => :event)
    end
  end

  describe "#validateWidgets" do
    it "calls the validate methods" do
      expect(self).to receive(:w1_validate).with("w1", "ID" => :event).and_return(true)
      expect(self).to receive(:w2_validate).with("w2", "ID" => :event).and_return(true)
      expect(subject.validateWidgets(run_widgets, "ID" => :event)).to eq(true)
    end

    context "if a handler returns false" do
      before do
        expect(self).to receive(:w1_validate).with("w1", "ID" => :event).and_return(false)
      end

      it "breaks the loop if a handler returns false" do
        expect(self).to_not receive(:w2_validate)
        expect(subject.validateWidgets(run_widgets, "ID" => :event)).to eq(false)
      end

      # SetValidationFailedHandler
      it "calls validation_failed_handler if it has been set" do
        called = false
        handler = -> { called = true }
        subject.SetValidationFailedHandler(handler)

        subject.validateWidgets(run_widgets, "ID" => :event)
        # we cannot set an expectation on `handler` because a copy is made
        expect(called).to eq(true)
      end
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

    # Test that *block* does not modify its argument,
    # by storing a deep_copy of it and expecting equality afterwards
    # @param value [Object]
    # @yieldparam a copy of *value*
    def expect_not_modified(value, &block)
      copy = deep_copy(value)
      block.call(copy)
      expect(copy).to eq(value)
    end

    it "does not modify its arguments" do
      expect_not_modified(test_stringterm) do |contents|
        expect_not_modified(created_widgets) do |widgets|
          subject.PrepareDialog(contents, widgets)
        end
      end
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

    it "recurses into container widgets" do
      created_widgets = subject.CreateWidgets(["w2", "w3"], test_widgets)
      ret = subject.PrepareDialog(VBox("w2", "w3"), created_widgets)
      w3 = ret.params[1]
      expected = HBox(
        InputField(Id("w2"), Opt(:hstretch), "Text&Entry"),
        InputField(Id("w2"), Opt(:hstretch), "Text&Entry")
      )
      expect(w3).to eq(expected)
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
