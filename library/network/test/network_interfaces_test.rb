#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import("NetworkInterfaces")

describe Yast::NetworkInterfaces do

  subject { Yast::NetworkInterfaces }

  context "#CanonicalizeIP" do
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

  context "#Read" do
    let(:data_dir) { File.join(File.dirname(__FILE__), "data") }
    # Defined in test/data/etc/sysconfig/ifcfg-*
    let(:devices) { ["arc5", "bond0", "br1", "em1", "eth0", "eth1", "vlan3"] }

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
      expect(subject).to receive(:canonicalize_config)
        .exactly(devices.size).times.and_call_original
      subject.Read
      expect(subject.GetIP("eth0")).to eql(["192.168.0.200", "192.168.20.100"])
      expect(subject.GetValue("eth0", "NETMASK")).to eql("255.255.255.0")
    end
  end

end
