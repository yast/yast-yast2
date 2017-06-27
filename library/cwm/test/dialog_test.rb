#! /usr/bin/env rspec
require_relative "test_helper"

require "cwm/dialog"
require "cwm/rspec"

describe "CWM::Dialog" do
  class TestCWMDialog < CWM::Dialog
    def contents
      VBox()
    end
  end
  subject { TestCWMDialog.new }

  include_examples "CWM::Dialog"

  describe ".run" do
    it "opens a dialog when needed, and calls CWM#show" do
      expect(Yast::Wizard).to receive(:IsWizardDialog).and_return(false)
      expect(Yast::Wizard).to receive(:CreateDialog)
      expect(Yast::Wizard).to receive(:CloseDialog)
      expect(Yast::CWM).to receive(:show).and_return(:launch)

      expect(subject.class.run).to eq(:launch)
    end

    it "does not open a dialog when not needed, and calls CWM#show" do
      expect(Yast::Wizard).to receive(:IsWizardDialog).and_return(true)
      expect(Yast::Wizard).to_not receive(:CreateDialog)
      expect(Yast::Wizard).to_not receive(:CloseDialog)
      expect(Yast::CWM).to receive(:show).and_return(:launch)

      expect(subject.class.run).to eq(:launch)
    end
  end

  describe "#replace_true" do
    it "replaces true" do
      expect(subject.send(:replace_true, true, :new)).to eq :new
    end

    it "does not replace others" do
      expect(subject.send(:replace_true, nil, :new)).to eq nil
      expect(subject.send(:replace_true, false, :new)).to eq false
      expect(subject.send(:replace_true, :old, :new)).to eq :old
    end
  end
end
