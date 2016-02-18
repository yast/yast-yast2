#!/usr/bin/rspec

require_relative "test_helper"
require "ui/multi_messages_dialog"

describe UI::MultiMessagesDialog do
  DummyMessage = Struct.new(:title, :body)

  let(:messages) { (1..3).map { |n| DummyMessage.new("Title #{n}", "Body #{n}") } }
  subject(:dialog) { described_class.new("some title", messages) }

  before(:each) do
    allow(Yast::UI).to receive(:OpenDialog).and_return(true)
    allow(Yast::UI).to receive(:CloseDialog).and_return(true)
    allow(dialog).to receive(:PushButton)
  end

  describe "#run" do
    it "enables the 'back' button" do
      expect(dialog).to receive(:PushButton).with(Id(:back), Opt(:disabled), Yast::Label.BackButton)
        .and_call_original
      expect(Yast::UI).to receive(:UserInput).and_return(:close)
      dialog.run
    end

    describe "given more than one message" do
      it "'next' button is 'enabled'" do
        expect(dialog).to receive(:PushButton).with(Id(:next), Opt(:enabled), Yast::Label.NextButton)
          .and_call_original
        expect(Yast::UI).to receive(:UserInput).and_return(:close)
        dialog.run
      end
    end

    describe "given only one message" do
      let(:messages) { [DummyMessage.new("Title", "Body")] }

      it "disables the 'next' button" do
        expect(dialog).to receive(:PushButton).with(Id(:next), Opt(:disabled), Yast::Label.NextButton)
          .and_call_original
        expect(Yast::UI).to receive(:UserInput).and_return(:close)
        dialog.run
      end
    end
  end

  describe "#next_handler" do
    it "shows the following message and returns true" do
      expect(dialog).to receive(:move_to).with(1)
      expect(dialog.next_handler).to eq(true)
    end

    it "enables the 'back' button" do
      allow(Yast::UI).to receive(:ChangeWidget)
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:back), :Enabled, true).and_call_original
      dialog.next_handler
    end

    context "when current message is the last one" do
      before { dialog.move_to(messages.size - 1) }

      it "returns false" do
        expect(dialog).to_not receive(:move_to)
        expect(dialog.next_handler).to eq(false)
      end
    end

    context "when current message is the next-to-last one" do
      before { dialog.move_to(messages.size - 2) }

      it "disables the next button" do
        allow(Yast::UI).to receive(:ChangeWidget).and_call_original
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:next), :Enabled, false).and_call_original
        dialog.next_handler
      end
    end

    context "when current message is not the next-to-last one" do
      it "does not disabled the 'next' button" do
        allow(Yast::UI).to receive(:ChangeWidget).and_call_original
        expect(Yast::UI).to_not receive(:ChangeWidget).with(Id(:next), :Enabled, false)
          .and_call_original
        dialog.next_handler
      end
    end
  end

  describe "#back_handler" do
    before { dialog.move_to(messages.size - 1) }

    it "shows the previous message and returns true" do
      expect(dialog).to receive(:move_to).with(messages.size - 2)
      expect(dialog.back_handler).to eq(true)
    end

    it "enables the 'next' button" do
      allow(Yast::UI).to receive(:ChangeWidget)
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:next), :Enabled, true)
        .and_call_original
      dialog.back_handler
    end

    context "when current message is the first one" do
      before { dialog.move_to(0) }

      it "returns false" do
        expect(dialog).to_not receive(:move_to)
        expect(dialog.back_handler).to eq(false)
      end
    end

    context "when current message is the second one" do
      before { dialog.move_to(1) }

      it "disables the back button" do
        allow(Yast::UI).to receive(:ChangeWidget).and_call_original
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:back), :Enabled, false).and_call_original
        dialog.back_handler
      end
    end

    context "when is past the second one" do
      before { dialog.move_to(messages.size - 1) }

      it "does not disable the 'back' button" do
        allow(Yast::UI).to receive(:ChangeWidget).and_call_original
        expect(Yast::UI).to_not receive(:ChangeWidget).with(Id(:back), :Enabled, false).and_call_original
        dialog.back_handler
      end
    end
  end

  describe "#close_handler" do
    it "closes the dialog with :close value" do
      expect(subject).to receive(:finish_dialog).with(:close)
      subject.close_handler
    end
  end

  describe "#timeout_handler" do
    subject(:dialog) { described_class.new("some title", messages, timeout: timeout) }

    context "when the dialogs timeout is reached" do
      let(:timeout) { 1 }

      it "closes the dialog with :timeout value" do
        allow(Yast::UI).to receive(:TimeoutUserInput).and_return(:timeout)
        expect(dialog).to receive(:finish_dialog).with(:timeout)
        dialog.timeout_handler
      end
    end

    context "when the dialogs timeout is not reached yet" do
      let(:timeout) { 2 }

      it "updates the timer" do
        allow(Yast::UI).to receive(:TimeoutUserInput).and_return(:timeout)
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:timer), :Value, "1")
          .and_call_original
        dialog.timeout_handler
      end
    end
  end

  describe "#stop_handler" do
    subject(:dialog) { described_class.new("some title", messages, timeout: 5) }

    it "sets the dialog as 'non-timed'" do
      expect { dialog.stop_handler }.to change { dialog.timed? }.from(true).to(false)
    end
  end

  describe "#move_to" do
    it "shows the message at the given position" do
      expect(subject).to receive(:RichText).with(messages[2].body)
      subject.move_to(2)
    end
  end
end
