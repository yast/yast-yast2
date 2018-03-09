#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "TypeRepository"

describe Yast::TypeRepository do
  describe "#IsEmpty" do
    it "returns true for nil and the empty String, Array, Hash, Term" do
      expect(Yast::TypeRepository.IsEmpty(nil)).to eq(true)
      expect(Yast::TypeRepository.IsEmpty("")).to eq(true)
      expect(Yast::TypeRepository.IsEmpty([])).to eq(true)
      expect(Yast::TypeRepository.IsEmpty({})).to eq(true)
      expect(Yast::TypeRepository.IsEmpty(HBox())).to eq(true)
    end

    it "returns false otherwise" do
      expect(Yast::TypeRepository.IsEmpty(0)).to eq(false)
      expect(Yast::TypeRepository.IsEmpty(0.0)).to eq(false)
      expect(Yast::TypeRepository.IsEmpty("item")).to eq(false)
      expect(Yast::TypeRepository.IsEmpty(["item"])).to eq(false)
      expect(Yast::TypeRepository.IsEmpty("dummy" => "item")).to eq(false)
      expect(Yast::TypeRepository.IsEmpty(HBox(Label()))).to eq(false)
      expect(Yast::TypeRepository.IsEmpty(false)).to eq(false)
      expect(Yast::TypeRepository.IsEmpty(true)).to eq(false)
    end
  end
end
