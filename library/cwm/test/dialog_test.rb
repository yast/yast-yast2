#! /usr/bin/env rspec
require_relative "test_helper"

require "cwm/dialog"
require "cwm/rspec"

describe "CWM::Dialog" do
  class TestCWMDialog < CWM::Dialog
    attr_reader :title, :disable

    def initialize(title = "test", disable: :abort)
      super()

      @title = title
      @disable = disable
    end

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
      allow(Yast::CWM).to receive(:show).and_return(:next)
    end

    it "pass all given arguments to constructor" do
      expect(TestCWMDialog).to receive(:new).with("test2", disable: :next).and_call_original

      TestCWMDialog.run("test2", disable: :next)
    end

    it "does not past extra arguments to constructor" do
      expect(TestCWMDialog).to receive(:new).with(no_args).and_call_original

      TestCWMDialog.run
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

    it "passes the next handler to CWM#show" do
      expect(Yast::CWM).to receive(:show) do |_content, options|
        expect(options).to include(:next_handler)
        # Checking the default handler is passed (simply returns true)
        expect(options[:next_handler].call).to eq(true)
      end

      subject.class.run
    end

    it "passes the back handler to CWM#show" do
      expect(Yast::CWM).to receive(:show) do |_content, options|
        expect(options).to include(:back_handler)
        # Checking the default handler is passed (simply returns true)
        expect(options[:back_handler].call).to eq(true)
      end

      subject.class.run
    end

    it "passes the abort handler to CWM#show" do
      expect(Yast::CWM).to receive(:show) do |_content, options|
        expect(options).to include(:abort_handler)
        # Checking the default handler is passed (simply returns true)
        expect(options[:abort_handler].call).to eq(true)
      end

      subject.class.run
    end
  end
end
