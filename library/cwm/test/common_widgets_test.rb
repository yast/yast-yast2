#! /usr/bin/env rspec
# typed: false

require_relative "test_helper"

require "cwm/common_widgets"
require "cwm/rspec"

describe CWM::RadioButtons do

  class TestRadioButtons < CWM::RadioButtons
    def label
      "Choose a number"
    end

    def items
      [[:one, "One"], [:two, "Two"], [:three, "Three"]]
    end
  end

  class TestSpacedRadioButtons < TestRadioButtons
    def vspacing
      2
    end

    def hspacing
      3
    end
  end

  describe "#cwm_definition" do
    context "if #vspacing and #hspacing are not defined" do
      subject { TestRadioButtons.new }

      it "does not include the vspacing key" do
        expect(subject.cwm_definition.keys).to_not include("vspacing")
      end

      it "does not include the hspacing key" do
        expect(subject.cwm_definition.keys).to_not include("hspacing")
      end
    end

    context "if #vspacing is defined" do
      subject { TestSpacedRadioButtons.new }

      it "sets vspacing based on the method result" do
        expect(subject.cwm_definition.keys).to include("vspacing")
        expect(subject.cwm_definition["vspacing"]).to eq 2
      end
    end

    context "if #hspacing is defined" do
      subject { TestSpacedRadioButtons.new }

      it "sets hspacing based on the method result" do
        expect(subject.cwm_definition.keys).to include("hspacing")
        expect(subject.cwm_definition["hspacing"]).to eq 3
      end
    end
  end
end
