#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "ProductFeatures"

describe Yast::ProductFeatures do
  subject { Yast::ProductFeatures }

  let(:original_features) do
    {
      "globals"      => {
        "keyboard  " => "Hammond",
        "flags"      => ["Uruguay", "Bhutan"]
      },
      "partitioning" => {
        "open_space" => false
      }
    }
  end

  let(:overlay_features) do
    {
      "globals"  => {
        "flags" => ["Namibia"]
      },
      "software" => {
        "packages" => ["tangut-fonts"]
      }
    }
  end

  let(:resulting_features) do
    {
      "globals"      => {
        "keyboard  " => "Hammond",
        "flags"      => ["Namibia"]
      },
      "partitioning" => {
        "open_space" => false
      },
      "software"     => {
        "packages" => ["tangut-fonts"]
      }
    }
  end

  describe ".SetOverlay" do
    it "overrides desired values and keeps other values" do
      subject.Import(original_features)
      subject.SetOverlay(overlay_features)
      expect(subject.Export).to eq(resulting_features)
    end
  end

  describe ".ClearOverlay" do
    it "restores the original state" do
      subject.Import(original_features)
      subject.SetOverlay(overlay_features)
      subject.ClearOverlay
      expect(subject.Export).to eq(original_features)
    end

    it "keeps the original state if nothing was overlaid" do
      subject.Import(original_features)
      subject.ClearOverlay
      expect(subject.Export).to eq(original_features)
    end
  end
end
