#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import("NetworkInterfaces")

describe Yast::NetworkInterfaces do

  subject { Yast::NetworkInterfaces }

  describe "#CanonicalizeIP" do
    context "Handling IPv6 address" do
      it "Sets ipaddr, prefix and empty mask" do
        NetworkStubs::IPV6_IFCFG.each do |ipv6_ifcfg|
          canonical_ifcfg = subject.CanonicalizeIP(ipv6_ifcfg[:data])
          expect(canonical_ifcfg).to be_eql(ipv6_ifcfg[:expected])
        end
      end
    end

    context "Handling IPv4 address" do
      it "Sets ipaddr, prefix and empty mask" do
        NetworkStubs::IPV4_IFCFG.each do |ipv4_ifcfg|
          canonical_ifcfg = subject.CanonicalizeIP(ipv4_ifcfg[:data])
          expect(canonical_ifcfg).to be_eql(ipv4_ifcfg[:expected])
        end
      end
    end

  end

  describe "#Read" do
    let(:data_dir) { File.join(File.dirname(__FILE__), "data") }
    # Defined in test/data/etc/sysconfig/ifcfg-*
    let(:devices) { ["arc5", "bond0", "br1", "em1", "eth0", "eth1", "ppp0", "vlan3"] }

    around do |example|
      change_scr_root(data_dir, &example)
    end

    before do
      subject.Reset
    end

    it "returns true if success" do
      expect(subject.Read).to eql(true)
    end

    it "loads all valid devices from ifcfg-* definition" do
      subject.Read
      expect(subject.List("")).to eql devices
    end

    it "canonicalizes readed config" do
      expect(subject).to receive(:canonicalize_config!)
        .exactly(devices.size).times.and_call_original
      subject.Read
      expect(subject.GetIP("eth0")).to eql(["192.168.0.200", "192.168.20.100"])
      expect(subject.GetValue("eth0", "NETMASK")).to eql("255.255.255.0")
    end
  end

  describe "#FilterDevices" do
    let(:data_dir) { File.join(File.dirname(__FILE__), "data") }
    # Defined in test/data/etc/sysconfig/ifcfg-*
    let(:netcard_devices) { ["arc", "bond", "br", "em", "eth", "vlan"] }

    around do |example|
      change_scr_root(data_dir, &example)
    end

    context "when given regex is some of the predefined ones 'netcard', 'modem', 'isdn', 'dsl'." do
      it "returns devices of the given type" do
        expect(subject.FilterDevices("netcard").keys).to eql(netcard_devices)
        expect(subject.FilterDevices("modem").keys).to eql(["ppp"])
        expect(subject.FilterDevices("dsl").keys).to eql([])
        expect(subject.FilterDevices("isdn").keys).to eql([])
      end
    end
    context "when given regex is not a predefined one" do
      it "returns devices whose type exactly match the given regex" do
        expect(subject.FilterDevices("br").keys).to eql(["br"])
        expect(subject.FilterDevices("br").size).to eql(1)
        expect(subject.FilterDevices("vlan").keys).to eql(["vlan"])
        expect(subject.FilterDevices("vlan").size).to eql(1)
      end
    end
  end

end
