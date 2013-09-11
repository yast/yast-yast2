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
    valid_ip4s = [
      "0.0.0.0",
      "127.0.0.1",
      "255.255.255.255",
      "10.11.12.13",
    ]
    valid_ip4s.each do |valid_ip4|
      it "return true for valid IPv4 '#{valid_ip4}'" do
        @object.Check4(valid_ip4).must_equal true
      end
    end

    invalid_ip4s = [
      "0.0.0",
      "127.0.0.1.1",
      "256.255.255.255",
      "01.01.012.013",
      "10,11.12.13",
    ]
    invalid_ip4s.each do |invalid_ip4|
      it "return false for invalid IPv4 '#{invalid_ip4}'" do
        @object.Check4(invalid_ip4).must_equal false
      end
    end

    it "return false for empty argument" do
      @object.Check4("").must_equal false
    end

    it "return false for nil argument" do
      @object.Check4(nil).must_equal false
    end
  end

  describe "when told to check IPv6" do

    valid_ip6s = [
      "1:2:3:4:5:6:7:8",
      "::3:4:5:6:7:8",
      "1:2:3:4:5:6::",
      "1:2:3::5:6:7:8",
      "1:2:3:4:5:6::8",
      "a:FF:b:c:d:d:e:e",
      "fe80::200:1cff:feb5:5433",
      "0::",
      "0000::",
      "0:1::",
      "1:0::",
      "1:0::0",
      "1:2:3:4:5:6:127.0.0.1",
      "1:2:3::6:127.0.0.1",
    ]
    valid_ip6s.each do |valid_ip6|
      it "return true for valid IPv6 '#{valid_ip6}'" do
        @object.Check6(valid_ip6).must_equal true
      end
    end

    invalid_ip6s = [
      "1::3:4:5:6::8",
      "1:2:3:4:5:6:7:8:9",
      "1:2:3:4::5:6:7:8:9",
      ":2:3:4:5:6:7:8",
      "1:2:3:4:5:6:7:",
      "g:FF:b:c:d:d:e:e",
      "127.0.0.1",
      "1:2:3:4:5:6:7:127.0.0.1",
      "1:2:3::6:7:8:127.0.0.1",
#FIXME deprecated syntax, so we should handle it like invalid "::127.0.0.1",
#FIXME deprecated syntax, so we should handle it invalid "::FFFF:127.0.0.1",
#FIXME insufficient regex for ipv4 included in ipv6 "1:2:3:4:5:6:127.0.0.256"
    ]
    invalid_ip6s.each do |invalid_ip6|
      it "return false for invalid IPv6 '#{invalid_ip6}" do
          @object.Check6(invalid_ip6).must_equal false
      end
    end

    it "return false for empty argument" do
      @object.Check6("").must_equal false
    end

    it "return false for nil argument" do
      @object.Check6(nil).must_equal false
    end
  end

  describe "when told to compute integer value" do
    it "return value for valid ipv4" do
      result_map = {
        "0.0.0.0"        => 0,
        "127.0.0.1"      => 2130706433,
        "192.168.110.23" => 3232263703,
        "10.20.1.29"     => 169083165
      }
      result_map.each_pair do |k,v|
        @object.ToInteger(k).must_equal v
      end
    end

    it "return nil if value is not valid ipv4" do
      @object.ToInteger("blabla").must_equal nil
    end
  end

  describe "when told to create ipv4 string from integer" do
    it "it return ipv4" do
      result_map = {
        "0.0.0.0"        => 0,
        "127.0.0.1"      => 2130706433,
        "192.168.110.23" => 3232263703,
        "10.20.1.29"     => 169083165
      }
      result_map.each_pair do |k,v|
        @object.ToString(v).must_equal k
      end
    end
  end

  describe "when told to create string with hex value of ipv4 string" do
    it "return value for valid ipv4" do
      result_map = {
        "0.0.0.0"         => "00000000",
        "10.10.0.1"       => "0A0A0001",
        "192.168.1.1"     => "C0A80101",
        "255.255.255.255" => "FFFFFFFF"
      }
      result_map.each_pair do |k,v|
        @object.ToHex(k).must_equal v
      end
    end

    it "return nil if value is not valid ipv4" do
      @object.ToHex("blabla").must_equal nil
    end
  end

  describe "when told to convert IPv4 address into bits" do
    it "return value for proper ipv4" do
      result_map = {
        "80.25.135.2"    => "01010000000110011000011100000010",
        "172.24.233.211" => "10101100000110001110100111010011"
      }
      result_map.each_pair do |k,v|
        @object.IPv4ToBits(k).must_equal v
      end
    end

    it "return nil if value is not valid ipv4" do
      @object.IPv4ToBits("blabla").must_equal nil
    end
  end

  describe "when told to convert bits to IPv4 address" do
    it "return value for string" do
      result_map = {
        "80.25.135.2"    => "01010000000110011000011100000010",
        "172.24.233.211" => "10101100000110001110100111010011"
      }
      result_map.each_pair do |k,v|
        @object.BitsToIPv4(v).must_equal k
      end
    end

    it "return nil if size of string is not 32" do
      @object.BitsToIPv4("101").must_equal nil
    end

    it "return nil if value is not valid string with 0 or 1" do
      @object.BitsToIPv4("blabla").must_equal nil
    end
  end
end
