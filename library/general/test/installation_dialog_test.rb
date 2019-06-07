#! /usr/bin/env rspec
# typed: false

require_relative "test_helper"

require "ui/installation_dialog"

class TestInstDialog < UI::InstallationDialog
  def dialog_content
    HBox(
      InputField(Id(:foo), "Value for Foo")
    )
  end
end

describe UI::Dialog do
  subject { TestInstDialog }
  describe ".run" do
    def mock_ui_events(*events)
      allow(Yast::UI).to receive(:UserInput).and_return(*events)
    end

    before do
      Yast.import "Wizard"
      allow(Yast::Wizard).to receive(:IsWizardDialog).and_return(wizard_is_open)
      allow(Yast::Wizard).to receive(:SetContents)
      mock_ui_events(:cancel)
    end

    let(:wizard_is_open) { true }

    it "returns :next when next is clicked" do
      mock_ui_events(:next)

      expect(subject.run).to eq(:next)
    end

    it "returns :next when accepting a proposal" do
      mock_ui_events(:accept)

      expect(subject.run).to eq(:next)
    end

    it "return :abort if the user aborts and confirms" do
      mock_ui_events(:abort, :next)

      expect(Yast::Popup).to receive(:ConfirmAbort).and_return true
      expect(subject.run).to eq(:abort)
    end

    it "stops the abort process if user does not confirm" do
      mock_ui_events(:abort, :next)

      expect(Yast::Popup).to receive(:ConfirmAbort).and_return false
      expect(subject.run).to eq(:next)
    end

    context "if the wizard is already open" do
      let(:wizard_is_open) { true }

      it "reuses the wizard" do
        expect(Yast::Wizard).to_not receive(:CreateDialog)
        expect(Yast::Wizard).to_not receive(:CloseDialog)
        subject.run
      end
    end

    context "if the wizard is not there" do
      let(:wizard_is_open) { false }

      it "opens a new wizard and closes it afterwards" do
        expect(Yast::Wizard).to receive(:CreateDialog)
        expect(Yast::Wizard).to receive(:CloseDialog)
        subject.run
      end

      it "returns the user input" do
        allow(Yast::Wizard).to receive(:CreateDialog)
        allow(Yast::Wizard).to receive(:CloseDialog)
        expect(subject.run).to eq(:cancel)
      end
    end
  end
end
