#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "Report"

describe Yast::Report do
  before { subject.ClearAll }

  describe ".LongMessage" do
    let(:show) { true }
    let(:timeout) { 0 }
    let(:log) { true }

    before do
      subject.DisplayMessages(show, timeout) 
      subject.LogMessages(log)
    end

    context "when display of messages is disabled" do
      let(:show) { false }

      it "does not show a popup" do
        expect(Yast::Popup).to_not receive(:LongMessage)
        subject.LongMessage("Message")
      end
    end

    context "when display of messages is enabled" do
      it "shows a popup" do
        expect(Yast::Popup).to receive(:LongMessage)
          .with("Message")
        subject.LongMessage("Message")
      end
    end

    context "when timeouts are enabled" do
      let(:timeout) { 1 }

      it "shows a timed popup" do
        expect(Yast::Popup).to receive(:TimedLongMessage)
          .with("Message", 1)
        subject.LongMessage("Message")
      end
    end

    context "when logging is enabled" do
      it "logs the message" do
        allow(Yast::Popup).to receive(:LongMessage)
        expect(Yast::Builtins).to receive(:y2milestone)
          .with(1, "%1", "Message")
        subject.LongMessage("Message")
      end
    end

    context "when logging is disabled" do
      let(:log) { false }

      it "does not log the message" do
        allow(Yast::Popup).to receive(:LongMessage)
        expect(Yast::Builtins).to_not receive(:y2milestone)
        subject.LongMessage("Message")
      end
    end

    it "stores the message" do
      subject.LongMessage("Message")
      expect(subject.GetMessages(0, 1, 0, 0)).to match(/Message/)
    end
  end

  describe ".LongWarning" do
    let(:show) { true }
    let(:timeout) { 0 }
    let(:log) { true }

    before do
      subject.DisplayWarnings(show, timeout)
      subject.LogWarnings(log)
    end

    context "when display of messages is disabled" do
      let(:show) { false }

      it "does not show a popup" do
        expect(Yast::Popup).to_not receive(:LongWarning)
        subject.LongWarning("Message")
      end
    end

    context "when display of messages is enabled" do
      it "shows a popup" do
        expect(Yast::Popup).to receive(:LongWarning)
          .with("Message")
        subject.LongWarning("Message")
      end
    end

    context "when timeouts are enabled" do
      let(:timeout) { 1 }

      it "shows a timed popup" do
        expect(Yast::Popup).to receive(:TimedLongWarning)
          .with("Message", 1)
        subject.LongWarning("Message")
      end
    end

    context "when logging is enabled" do
      it "logs the message" do
        allow(Yast::Popup).to receive(:LongWarning)
        expect(Yast::Builtins).to receive(:y2warning)
          .with(1, "%1", "Message")
        subject.LongWarning("Message")
      end
    end

    context "when logging is disabled" do
      let(:log) { false }

      it "does not log the message" do
        allow(Yast::Popup).to receive(:LongWarning)
        expect(Yast::Builtins).to_not receive(:y2warning)
        subject.LongWarning("Message")
      end
    end

    it "stores the message" do
      subject.LongWarning("Message")
      expect(subject.GetMessages(0, 1, 0, 0)).to match(/Message/)
    end
  end

  describe ".LongError" do
    let(:show) { true }
    let(:timeout) { 0 }
    let(:log) { true }

    before do
      subject.DisplayErrors(show, timeout) 
      subject.LogErrors(log)
    end

    context "when display of messages is disabled" do
      let(:show) { false }

      it "does not show a popup" do
        expect(Yast::Popup).to_not receive(:LongError)
        subject.LongError("Message")
      end
    end

    context "when display of messages is enabled" do
      it "shows a popup" do
        expect(Yast::Popup).to receive(:LongError)
          .with("Message")
        subject.LongError("Message")
      end
    end

    context "when timeouts are enabled" do
      let(:timeout) { 1 }

      it "shows a timed popup" do
        expect(Yast::Popup).to receive(:TimedLongError)
          .with("Message", 1)
        subject.LongError("Message")
      end
    end

    context "when logging is enabled" do
      it "logs the message" do
        allow(Yast::Popup).to receive(:LongError)
        expect(Yast::Builtins).to receive(:y2error)
          .with(1, "%1", "Message")
        subject.LongError("Message")
      end
    end

    context "when logging is disabled" do
      let(:log) { false }

      it "does not log the message" do
        allow(Yast::Popup).to receive(:LongError)
        expect(Yast::Builtins).to_not receive(:y2error)
        subject.LongError("Message")
      end
    end

    it "stores the message" do
      subject.LongError("Message")
      expect(subject.GetMessages(0, 1, 0, 0)).to match(/Message/)
    end
  end
end
