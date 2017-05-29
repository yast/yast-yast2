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

  let(:widget) { ReplacePointTestWidget.new }
  subject do
    res = described_class.new(widget: widget)
    res.init
    res
  end

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
  end

  describe "#contents" do
    it "generates initial content" do
      expect(subject.contents).to be_a Yast::Term
    end
  end

  describe "#init" do
    it "places passed widget into replace point" do
      widget = ReplacePointTestWidget.new
      subject = described_class.new(widget: widget)
      expect(Yast::UI).to receive(:ReplaceWidget)
      subject.init
    end

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
      expect(Yast::UI).to receive(:ReplaceWidget)
      subject.replace(widget)
    end

    it "changes help of replace point to help of enclosed widget(-s)" do
      subject = described_class.new(widget: CWM::Empty.new(:initial))
      expect(Yast::CWM).to receive(:ReplaceWidgetHelp)
      subject.replace(widget)
    end
  end

  describe "#handle" do
    # rspec expect have problem with arity of expected classes
    # so test failing
    xit "Passes handle to CWM on active widget" do
      expect(widget).to receive(:handle)
      subject.handle("ID" => widget.widget_id)
    end
  end

  describe "#validate" do
    it "passes validate to enclosed widget" do
      expect(subject.validate).to eq false
    end
  end

  describe "#store" do
    it "passes store to enclosed widget" do
      expect(widget).to receive(:store)
      subject.store
    end
  end

  describe "#cleanup" do
    it "passes cleanup to enclosed widget" do
      expect(widget).to receive(:cleanup)
      subject.cleanup
    end
  end
end
