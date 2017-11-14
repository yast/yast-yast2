#! /usr/bin/env rspec

require_relative "../test_helper"
require "erb"

require "yast2/popup"

describe Yast2::Popup do
  let(:ui) { double("Yast::UI") }
  subject { Yast2::Popup }

  before do
    # generic UI stubs
    stub_const("Yast::UI", ui)
  end

  describe ".update_feedback" do
    it "modifies feedback message" do
      expect(ui).to receive(:ChangeWidget).with(anything, :Value, "test")

      subject.update_feedback("test")
    end
  end

  describe ".stop_feedback" do
    it "closes dialog with feedback" do
      allow(ui).to receive(:WidgetExists).and_return(true)
      expect(ui).to receive(:CloseDialog)

      subject.stop_feedback
    end

    it "raises runtime error if feedback is not opened previously" do
      allow(ui).to receive(:WidgetExists).and_return(false)
      expect { subject.stop_feedback }.to raise_error(RuntimeError)
    end
  end
end
