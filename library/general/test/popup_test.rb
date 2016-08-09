#! /usr/bin/env rspec

require_relative "test_helper"
require "erb"

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

  describe ".Message" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.Message("<h1>Title</h1>")
    end
  end

  describe ".Warning" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.Warning("<h1>Title</h1>")
    end
  end

  describe ".Error" do
    before { allow(ui).to receive(:OpenDialog) }

    let(:switch_to_richtext) { true }
    let(:line) { "<h1>Title</h1>\n" }
    let(:limit) { subject.too_many_lines }

    # Backup and restore the original switch_to_richtext flag
    around do |example|
      old_switch_to_richtext = subject.switch_to_richtext
      subject.switch_to_richtext = switch_to_richtext
      example.run
      subject.switch_to_richtext = old_switch_to_richtext
    end

    context "when switching to richtext is not allowed" do
      let(:switch_to_richtext) { false }

      it "shows a popup without escaping tags" do
        message = line * limit
        expect(subject).to receive(:RichText).with(message)
        subject.Error(message)
      end
    end

    context "when switch to richtext is allowed" do
      let(:switch_to_richtext) { true }

      it "escapes the tags if message is too long" do
        message = line * limit
        expect(subject).to receive(:RichText).with(ERB::Util.html_escape(message))
        subject.Error(message)
      end

      it "keeps the original text if the message is short" do
        expect(subject).to receive(:RichText).with(line)
        subject.Error(line)
      end
    end
  end

  #
  # LongMessage
  #
  describe ".LongMessage" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.LongMessage("<h1>Title</h1>")
    end
  end

  describe ".LongMessageGeometry" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.LongMessage("<h1>Title</h1>")
    end

    it "sets dialog width and height" do
      allow(subject).to receive(:HSpacing)
      allow(subject).to receive(:VSpacing)
      expect(subject).to receive(:HSpacing).with(30)
      expect(subject).to receive(:VSpacing).with(40)
      subject.LongMessageGeometry("Title", 30, 40)
    end
  end

  describe ".TimedLongMessage" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(ui).to receive(:TimeoutUserInput)
      allow(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.TimedLongMessage("<h1>Title</h1>", 1)
    end
  end

  describe ".TimedLongMessageGeometry" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(ui).to receive(:TimeoutUserInput)
      allow(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.TimedLongMessageGeometry("<h1>Title</h1>", 1, 30, 40)
    end

    it "sets dialog width and height" do
      allow(ui).to receive(:TimeoutUserInput)
      allow(subject).to receive(:HSpacing)
      allow(subject).to receive(:VSpacing)
      expect(subject).to receive(:HSpacing).with(30)
      expect(subject).to receive(:VSpacing).with(40)
      subject.TimedLongMessageGeometry("Title", 1, 30, 40)
    end
  end

  #
  # LongWarning
  #
  describe ".LongWarning" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.LongWarning("<h1>Title</h1>")
    end
  end

  describe ".LongWarningGeometry" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.LongWarningGeometry("<h1>Title</h1>", 30, 40)
    end

    it "sets dialog width and height" do
      allow(subject).to receive(:HSpacing)
      allow(subject).to receive(:VSpacing)
      expect(subject).to receive(:HSpacing).with(30)
      expect(subject).to receive(:VSpacing).with(40)
      subject.LongWarningGeometry("Title", 30, 40)
    end
  end

  describe ".TimedLongWarning" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(ui).to receive(:TimeoutUserInput)
      allow(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.TimedLongWarning("<h1>Title</h1>", 1)
    end
  end

  describe ".TimedLongWarningGeometry" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(ui).to receive(:TimeoutUserInput)
      allow(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.TimedLongWarningGeometry("<h1>Title</h1>", 1, 30, 40)
    end

    it "sets dialog width and height" do
      allow(ui).to receive(:TimeoutUserInput)
      allow(subject).to receive(:HSpacing)
      allow(subject).to receive(:VSpacing)
      expect(subject).to receive(:HSpacing).with(30)
      expect(subject).to receive(:VSpacing).with(40)
      subject.TimedLongWarningGeometry("Title", 1, 30, 40)
    end
  end

  #
  # LongError
  #
  describe ".LongError" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.LongError("<h1>Title</h1>")
    end
  end

  describe ".LongErrorGeometry" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.LongErrorGeometry("<h1>Title</h1>", 30, 40)
    end

    it "sets dialog width and height" do
      allow(subject).to receive(:HSpacing)
      allow(subject).to receive(:VSpacing)
      expect(subject).to receive(:HSpacing).with(30)
      expect(subject).to receive(:VSpacing).with(40)
      subject.LongErrorGeometry("Title", 30, 40)
    end
  end

  describe ".TimedLongError" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(ui).to receive(:TimeoutUserInput)
      allow(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.TimedLongError("<h1>Title</h1>", 1)
    end
  end

  describe ".TimedLongErrorGeometry" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(ui).to receive(:TimeoutUserInput)
      allow(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.TimedLongErrorGeometry("<h1>Title</h1>", 1, 30, 40)
    end

    it "sets dialog width and height" do
      allow(ui).to receive(:TimeoutUserInput)
      allow(subject).to receive(:HSpacing)
      allow(subject).to receive(:VSpacing)
      expect(subject).to receive(:HSpacing).with(30)
      expect(subject).to receive(:VSpacing).with(40)
      subject.TimedLongErrorGeometry("Title", 1, 30, 40)
    end
  end

  #
  # TimedLongNotify
  #
  describe ".LongNotify" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.LongNotify("<h1>Title</h1>")
    end
  end

  describe ".LongNotifyGeometry" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.LongNotifyGeometry("<h1>Title</h1>", 30, 40)
    end

    it "sets dialog width and height" do
      allow(subject).to receive(:HSpacing)
      allow(subject).to receive(:VSpacing)
      expect(subject).to receive(:HSpacing).with(30)
      expect(subject).to receive(:VSpacing).with(40)
      subject.LongNotifyGeometry("Title", 30, 40)
    end
  end

  describe ".TimedLongNotify" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(ui).to receive(:TimeoutUserInput)
      allow(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.TimedLongNotify("<h1>Title</h1>", 1)
    end
  end

  describe ".TimedLongNotifyGeometry" do
    before { allow(ui).to receive(:OpenDialog) }

    it "shows a popup without escaping tags" do
      expect(ui).to receive(:TimeoutUserInput)
      allow(subject).to receive(:RichText).with("<h1>Title</h1>")
      subject.TimedLongNotifyGeometry("<h1>Title</h1>", 1, 30, 40)
    end

    it "sets dialog width and height" do
      allow(ui).to receive(:TimeoutUserInput)
      allow(subject).to receive(:HSpacing)
      allow(subject).to receive(:VSpacing)
      expect(subject).to receive(:HSpacing).with(30)
      expect(subject).to receive(:VSpacing).with(40)
      subject.TimedLongNotifyGeometry("Title", 1, 30, 40)
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
