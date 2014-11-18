#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

include Yast

describe "Yast::Netmask" do
  before( :all) do
    Yast.import "Netmask"
  end

  describe "#FromBits" do
    it "returns valid netmask for prefix shorter than 32 bits" do
      0.upto 32 do |prefix_len|
        expect(Netmask.FromBits(prefix_len)).not_to be_empty
      end
    end

    it "returns empty netmask for prefix longer than 32 bits" do
      33.upto 128 do |prefix_len|
        expect(Netmask.FromBits(prefix_len)).to be_empty
      end
    end

    it "returns empty netmask for incorrect prefix length" do
      expect(Netmask.FromBits(-1)).to be_empty
    end
  end
end
