#! /usr/bin/env rspec --format=doc

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

include Yast

describe "Yast::IP" do
  before( :all) do
    Yast.import "IP"
  end

  describe "#Valid4" do
    it "must return valid IPv4 description" do
      expect( IP.Valid4).not_to be_empty
    end
  end

  describe "#Check4" do
    VALID_IP4S = [
      "0.0.0.0",
      "127.0.0.1",
      "255.255.255.255",
      "10.11.12.13",
    ]

    VALID_IP4S.each do |valid_ip4|
      it "returns true for valid IPv4 '#{valid_ip4}'" do
        expect( IP.Check4(valid_ip4)).to be_true
      end
    end

    INVALID_IP4S = [
      "0.0.0",
      "127.0.0.1.1",
      "256.255.255.255",
      "01.01.012.013",
      "10,11.12.13",
    ]

    INVALID_IP4S.each do |invalid_ip4|
      it "returns false for invalid IPv4 '#{invalid_ip4}'" do
        expect( IP.Check4(invalid_ip4)).to be_false
      end
    end

    it "returns false for empty argument" do
      expect( IP.Check4("")).to be_false
    end

    it "returns false for nil argument" do
      expect( IP.Check4(nil)).to be_false
    end
  end


  describe "#Check6" do
    VALID_IP6S = [
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

    VALID_IP6S.each do |valid_ip6|
      it "returns true for valid IPv6 '#{valid_ip6}'" do
        expect( IP.Check6(valid_ip6)).to be_true
      end
    end

    INVALID_IP6S = [
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

    INVALID_IP6S.each do |invalid_ip6|
      it "returns false for invalid IPv6 '#{invalid_ip6}" do
          expect( IP.Check6(invalid_ip6)).to be_false
      end
    end

    it "returns false for empty argument" do
      expect( IP.Check6("")).to be_false
    end

    it "returns false for nil argument" do
      expect( IP.Check6(nil)).to be_false
    end
  end

  describe "#ToInteger" do
    RESULT_MAP_INT = {
      "0.0.0.0"        => 0,
      "127.0.0.1"      => 2130706433,
      "192.168.110.23" => 3232263703,
      "10.20.1.29"     => 169083165
    }

    RESULT_MAP_INT.each_pair do |k,v|
      it "returns #{v} for #{k}" do
        expect( IP.ToInteger(k)).to be_equal v
      end
    end

    it "returns nil if value is not valid IPv4 in dotted format" do
      expect( IP.ToInteger("foobar")).to be_equal nil
    end
  end

  describe "#ToString" do
    RESULT_MAP_INT.each_pair do |k,v|
      it "it returns #{k} for #{v}" do
        expect( IP.ToString(v)) == k
      end
    end
  end

  describe "#ToHex" do
    RESULT_MAP_HEX = {
      "0.0.0.0"         => "00000000",
      "10.10.0.1"       => "0A0A0001",
      "192.168.1.1"     => "C0A80101",
      "255.255.255.255" => "FFFFFFFF"
    }

    RESULT_MAP_HEX.each_pair do |k,v|
      it "returns #{v} for valid #{k}" do
        expect( IP.ToHex(k)) == v
      end
    end

    it "returns nil if value is not valid IPv4 in dotted format" do
      expect( IP.ToHex("foobar")).to be_equal nil
    end
  end

  RESULT_MAP_BITS = {
    "80.25.135.2"    => "01010000000110011000011100000010",
    "172.24.233.211" => "10101100000110001110100111010011"
  }

  describe "#IPv4ToBits" do
    RESULT_MAP_BITS.each_pair do |k,v|
      it "returns bitmap for #{k}" do
        expect( IP.IPv4ToBits(k)) == v
      end
    end

    it "returns nil if value is not valid IPv4" do
      expect( IP.IPv4ToBits("blabla")).to be_equal nil
    end
  end

  describe "#BitsToIPv4" do
    RESULT_MAP_BITS.each_pair do |k,v|
      it "returns #{k} for #{v}" do
        expect( IP.BitsToIPv4(v)) == k
      end
    end

    it "returns nil if length of bitmap is not 32" do
      expect( IP.BitsToIPv4("101")).to be_equal nil
    end

    it "returns nil if value is not valid bitmap with 0 or 1 only" do
      expect( IP.BitsToIPv4("foobar")).to be_equal nil
    end
  end
end
