#! /usr/bin/env rspec

require_relative "../test_helper"

require "yast2/feedback"

describe Yast2::Feedback do
  let(:ui) { double("Yast::UI") }

  before do
    # generic UI stubs
    stub_const("Yast::UI", ui)
  end

  describe "#update" do
    before do
      allow(ui).to receive(:ChangeWidget)
      allow(ui).to receive(:WidgetExists).and_return true
      allow(ui).to receive(:RecalcLayout)
    end

    it "modifies feedback message" do
      expect(ui).to receive(:ChangeWidget).with(anything, :Value, "test")

      subject.update("test")
    end

    it "recalculate UI layout" do
      expect(ui).to receive(:RecalcLayout)

      subject.update("test")
    end

    it "allows to modify also headline" do
      expect(ui).to receive(:ChangeWidget).with(anything, :Value, "Head2")

      subject.update("test", headline: "Head2")
    end

    it "raises ArgumentError if no headline was present before modify it" do
      allow(ui).to receive(:WidgetExists).and_return false

      expect { subject.update("test", headline: "Head2") }.to raise_error(ArgumentError)
    end
  end

  describe "#stop" do
    it "closes dialog with feedback" do
      allow(ui).to receive(:WidgetExists).and_return(true)
      expect(ui).to receive(:CloseDialog)

      subject.stop
    end

    it "raises runtime error if feedback is not opened previously" do
      allow(ui).to receive(:WidgetExists).and_return(false)
      expect { subject.stop }.to raise_error(RuntimeError)
    end
  end

  describe "#start" do
    it "opens dialog" do
      allow(ui).to receive(:OpenDialog).and_return(true)

      subject.start("test")
    end

    it "raises ArgumentError if message is not string" do
      expect { subject.start(nil) }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError if headline is not string" do
      expect { subject.start("test", headline: nil) }.to raise_error(ArgumentError)
    end

    it "raises RuntimeError if dialogs fails to open" do
      allow(ui).to receive(:OpenDialog).and_return(false)

      expect { subject.start("test") }.to raise_error(RuntimeError)
    end

    it "contains heading if headline is non-empty" do
      allow(ui).to receive(:OpenDialog) do |arg|
        expect(arg.nested_find { |w| w.is_a?(Yast::Term) && w.value == :Heading }).to be_a(Yast::Term)
        true
      end

      subject.start("test", headline: "head")
    end

    it "does not contain heading if headline is empty" do
      allow(ui).to receive(:OpenDialog) do |arg|
        expect(arg.nested_find { |w| w.is_a?(Yast::Term) && w.value == :Heading }).to eq nil
        true
      end

      subject.start("test", headline: "")
    end
  end
end
