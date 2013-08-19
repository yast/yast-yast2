#! /usr/bin/env ruby
ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "minitest/autorun"
require "yast"

Yast.import "IP"

describe Yast::IP do
  before do
    @object = Yast::IPClass.new
    @object.main
  end

  describe "when asked for validation string for IPv4" do
    it "must return translated text" do
      @object.Valid4.must_match /^A valid/
    end
  end

  describe "when told to check IPv4" do

    VALID_IP4 = [
      "0.0.0.0",
      "127.0.0.1",
      "255.255.255.255",
      "10.11.12.13",
    ]

    it "return true for valid IPv4" do
      VALID_IP4.each do |ip4|
        @object.Check4(ip4).must_equal true
      end
    end

    INVALID_IP4 = [
      "0.0.0",
      "127.0.0.1.1",
      "256.255.255.255",
      "01.01.012.013",
      "10,11.12.13",
    ]
    it "return false for invalid IPv4" do
      INVALID_IP4.each do |ip4|
        @object.Check4(ip4).must_equal false
      end
    end

    it "return false for empty argument" do
      @object.Check4("").must_equal false
    end

    it "return false for nil argument" do
      @object.Check4(nil).must_equal false
    end
  end
end
