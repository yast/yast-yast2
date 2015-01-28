#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "PackageCallbacks"

describe Yast::PackageCallbacks do
  subject { Yast::PackageCallbacks }

  describe "#textmode" do
    it "returns if runned as CLI" do
      mode = double(:commandline => true )
      stub_const("Yast::Mode", mode)

      expect(subject.send(:textmode)).to eq true
    end

    it "returns if running in TUI" do
      ui = double(:GetDisplayInfo => { "TextMode" => true })
      stub_const("Yast::UI", ui)

      expect(subject.send(:textmode)).to eq true
    end

    it "returns false in other cases" do
      ui = double(:GetDisplayInfo => { "TextMode" => false })
      stub_const("Yast::UI", ui)

      expect(subject.send(:textmode)).to eq false
    end
  end
end
