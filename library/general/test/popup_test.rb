#! /usr/bin/env rspec

require File.expand_path("../test_helper.rb", __FILE__)

require "yast"
include Yast

Yast.import "Popup"

describe "Popup" do
  let(:ui) { double("Yast::UI") }

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
      Popup.Feedback("Label", "Message") {}
    end

    it "closes the popup even when an exception occurs in the block" do
      # raise an exception in the block
      expect { Popup.Feedback("Label", "Message") { raise "TEST" } }.to raise_error(RuntimeError, "TEST")
    end

    it "raises exception when the block parameter is missing" do
      # no block passed
      expect { Popup.Feedback("Label", "Message") }.to raise_error(LocalJumpError)
    end
  end
end
