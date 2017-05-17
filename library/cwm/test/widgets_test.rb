#! /usr/bin/env rspec

require_relative "test_helper"

require "cwm/widget"
require "cwm/rspec"

describe CWM::RadioButtons do

  class TestRadioButtons < CWM::RadioButtons
    def label
      "Choose a number"
    end

    def items
      [[:one, "One"], [:two, "Two"], [:three, "Three"]]
    end
  end

  class TestSpacedRadioButtons < TestRadioButtons
    def vspacing
      2
    end

    def hspacing
      3
    end
  end

  describe "#cwm_definition" do
    context "if #vspacing and #hspacing are not defined" do
      subject { TestRadioButtons.new }

      it "does not include the vspacing key" do
        expect(subject.cwm_definition.keys).to_not include("vspacing")
      end

      it "does not include the hspacing key" do
        expect(subject.cwm_definition.keys).to_not include("hspacing")
      end
    end

    context "if #vspacing is defined" do
      subject { TestSpacedRadioButtons.new }

      it "sets vspacing based on the method result" do
        expect(subject.cwm_definition.keys).to include("vspacing")
        expect(subject.cwm_definition["vspacing"]).to eq 2
      end
    end

    context "if #hspacing is defined" do
      subject { TestSpacedRadioButtons.new }

      it "sets hspacing based on the method result" do
        expect(subject.cwm_definition.keys).to include("hspacing")
        expect(subject.cwm_definition["hspacing"]).to eq 3
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

  include_examples "CWM::CustomWidget"

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
