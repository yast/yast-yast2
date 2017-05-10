#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "Popup"

describe Yast::Popup do
  let(:ui) { double("Yast::UI") }
  subject { Yast::Popup }

  before do
    # generic UI stubs for the progress dialog
    stub_const("Yast::UI", ui)
  end

  describe ".Feedback" do
    context "when arguments are good" do
      before do
        expect(ui).to receive(:OpenDialog)
        expect(ui).to receive(:CloseDialog)
        allow(ui).to receive(:BusyCursor)
        allow(ui).to receive(:GetDisplayInfo).and_return({})
      end

      it "opens a popup dialog and closes it at the end" do
        # just pass an empty block
        subject.Feedback("Label", "Message") {}
      end

      it "closes the popup even when an exception occurs in the block" do
        # raise an exception in the block
        expect { subject.Feedback("Label", "Message") { raise "TEST" } }.to raise_error(RuntimeError, "TEST")
      end
    end

    context "when arguments are bad" do
      it "raises exception when the block parameter is missing" do
        # no block passed
        expect { subject.Feedback("Label", "Message") }.to raise_error(ArgumentError, /block must be supplied/)
      end
    end
  end

  describe ".AnyTimedMessage" do
    it "is an adapter for anyTimedMessageInternal" do
      expect(subject).to receive(:anyTimedMessageInternal)
        .with("headline", "message", Integer)
      expect(subject.AnyTimedMessage("headline", "message", 5)).to eq nil
    end
  end

  describe ".AnyTimedRichMessage" do
    it "is an adapter for anyTimedRichMessageInternal" do
      expect(subject).to receive(:anyTimedRichMessageInternal)
        .with("headline", "message", Integer, Integer, Integer)
      expect(subject.AnyTimedRichMessage("headline", "message", 5)).to eq nil
    end
  end
end
