#! /usr/bin/env rspec

require_relative "test_helper"
require "ui/multi_messages_dialog"

Yast.import "Popup"

describe Yast::Popup do
  let(:ui) { double("Yast::UI") }
  subject { Yast::Popup }

  before do
    # generic UI stubs for the progress dialog
    stub_const("Yast::UI", ui)
  end

  describe ".Feedback" do
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

    it "raises exception when the block parameter is missing" do
      # no block passed
      expect { subject.Feedback("Label", "Message") }.to raise_error
    end
  end

  describe ".multi_messages" do
    DummyMessage = Struct.new(:title, :body)

    let(:message) { DummyMessage.new("Title", "Body") }
    let(:dialog) { double("dialog") }

    it "shows a multi-messages dialog" do
      expect(UI::MultiMessagesDialog).to receive(:new)
        .with("Some title", [message], min_height: nil, min_width: nil, timeout: false)
        .and_return(dialog)
      expect(dialog).to receive(:run)
      subject.multi_messages("Some title", [message])
    end

    context "when a timeout is specified" do
      it "shows a multi-messages dialog with the given timeout" do
        expect(UI::MultiMessagesDialog).to receive(:new)
          .with("Some title", [message], min_height: nil, min_width: nil, timeout: 5)
          .and_return(dialog)
        expect(dialog).to receive(:run)
        subject.multi_messages("Some title", [message], timeout: 5)
      end
    end
  end
end
