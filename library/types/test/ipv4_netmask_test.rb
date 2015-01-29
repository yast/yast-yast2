#!/usr/bin/env rspec

require "test_helper"

Yast.import "Netmask"

describe Yast::Netmask do
  subject { Yast::Netmask }

  describe "#FromBits" do
    it "returns valid netmask for prefix shorter than 32 bits" do
      0.upto 32 do |prefix_len|
        expect(subject.FromBits(prefix_len)).not_to be_empty
      end
    end

    it "returns empty netmask for prefix longer than 32 bits" do
      33.upto 128 do |prefix_len|
        expect(subject.FromBits(prefix_len)).to be_empty
      end
    end

    it "returns empty netmask for incorrect prefix length" do
      expect(subject.FromBits(-1)).to be_empty
    end
  end
end
