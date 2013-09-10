#! /usr/bin/env ruby

require "minitest/spec"
require "minitest/autorun"

require "yast"

Yast.import "Netmask"

describe "When creating netmask from prefixlen" do
  it "returns valid netmask for prefix shorter than 32 bits" do
    0.upto 32 do |prefix_len|
      Yast::Netmask.FromBits( prefix_len).wont_be_empty
    end
  end

  it "returns empty netmask for prefix longer than 32 bits" do
    33.upto 128 do |prefix_len| 
      Yast::Netmask.FromBits( prefix_len).must_be_empty
    end
  end

  it "returns empty netmask for incorrect prefix length" do
    Yast::Netmask.FromBits( -1).must_be_empty
  end
end
