#! /usr/bin/env rspec

require_relative "test_helper"

require "cwm/common_widgets" # needed for input field
require "cwm/replace_point"
require "cwm/rspec"

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
      subject = described_class.new(id: "test", widget: widget)
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
