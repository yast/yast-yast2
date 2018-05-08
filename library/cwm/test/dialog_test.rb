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
    before do
      allow(Yast::Wizard).to receive(:IsWizardDialog).and_return(false)
      allow(Yast::Wizard).to receive(:CreateDialog)
      allow(Yast::Wizard).to receive(:CloseDialog)
    end

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

    it "uses the back handler" do
      expect(Yast::CWM).to receive(:show) do |_content, options|
        expect(options).to include(:back_handler)
        expect(options[:back_handler].call).to eq(true)
      end

      subject.class.run
    end

    it "uses the abort handler" do
      expect(Yast::CWM).to receive(:show) do |_content, options|
        expect(options).to include(:abort_handler)
        expect(options[:abort_handler].call).to eq(true)
      end

      subject.class.run
    end
  end
end
