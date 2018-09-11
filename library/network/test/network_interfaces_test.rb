#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import("NetworkInterfaces")

describe Yast::NetworkInterfaces do

  subject { Yast::NetworkInterfaces }

  TYPE_SYS_PATH = "/sys/class/net/ppp0/type".freeze

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
    let(:devices) { ["arc5", "bond0", "br1", "cold", "em1", "eth0", "eth1", "eth2", "ppp0", "vlan3"] }

    around do |example|
      change_scr_root(data_dir, &example)
    end

    before do
      subject.main
    end

    it "returns true if success" do
      expect(subject.Read).to eql(true)
    end

    it "loads all valid devices from ifcfg-* definition" do
      subject.Read
      expect(subject.List("").sort).to eql devices
    end

    it "doesn't load ifcfgs with a backup extension" do
      subject.Read

      devnames = subject.List("")

      expect(devnames.any? { |d| d =~ subject.send(:ignore_confs_regex) }).to be false
      expect(devnames).to include "cold"
    end

    it "canonicalizes readed config" do
      expect(subject).to receive(:canonicalize_config)
        .exactly(devices.size).times.and_call_original
      subject.Read
      expect(subject.GetIP("eth0")).to eql(["192.168.0.200", "192.168.20.100"])
      expect(subject.GetValue("eth0", "NETMASK")).to eql("255.255.255.0")
    end

  end

  describe "adapt_old_config!" do
    let(:data_dir) { File.join(File.dirname(__FILE__), "data") }
    # Defined in test/data/etc/sysconfig/ifcfg-*
    let(:devices) { ["arc5", "bond0", "br1", "em1", "eth0", "eth1", "eth2", "ppp0", "vlan3"] }

    around do |example|
      change_scr_root(data_dir, &example)
    end

    before do
      subject.main
    end

    it "converts old enslaved interfaces config" do
      subject.Read
      expect(subject.GetValue("eth2", "IPADDR")).to eql("0.0.0.0")
      subject.adapt_old_config!

      expect(subject.GetValue("eth0", "IPADDR")).to eql("192.168.0.200")
      expect(subject.GetValue("eth2", "NETMASK")).to eql("")
      expect(subject.GetValue("eth2", "PREFIXLEN")).to eql("")
      expect(subject.GetValue("eth2", "IPADDR")).to eql("")
      expect(subject.GetValue("eth2", "BOOTPROTO")).to eql("none")
    end

  end

  describe "#FilterDevices" do
    let(:data_dir) { File.join(File.dirname(__FILE__), "data") }
    # Defined in test/data/etc/sysconfig/ifcfg-*
    let(:netcard_devices) { ["bond", "br", "eth", "vlan"] }

    around do |example|
      change_scr_root(data_dir, &example)
    end

    context "when given regex is some of the predefined ones 'netcard', 'modem', 'isdn', 'dsl'." do
      before do
        # mock type id for ppp device in sysfs
        allow(Yast::FileUtils)
          .to receive(:Exists)
          .and_return false
        allow(Yast::FileUtils)
          .to receive(:Exists)
          .with(TYPE_SYS_PATH)
          .and_return true

        allow(Yast::SCR)
          .to receive(:Read)
          .and_call_original
        allow(Yast::SCR)
          .to receive(:Read)
          .with(path(".target.string"), TYPE_SYS_PATH)
          .and_return "512\n"

        subject.CleanCacheRead
      end

      it "returns device groups of the given type" do
        expect(subject.FilterDevices("netcard").keys.sort).to eql(netcard_devices)
        expect(subject.FilterDevices("modem").keys).to eql(["ppp"])
        expect(subject.FilterDevices("dsl").keys).to eql([])
        expect(subject.FilterDevices("isdn").keys).to eql([])
      end
    end

    context "when given regex is not a predefined one" do
      it "returns device groups whose type exactly match the given regex" do
        expect(subject.FilterDevices("br").keys).to eql(["br"])
        expect(subject.FilterDevices("br").size).to eql(1)
        expect(subject.FilterDevices("vlan").keys).to eql(["vlan"])
        expect(subject.FilterDevices("vlan").size).to eql(1)
      end
    end
  end

  describe "#FilterNOT" do
    let(:data_dir) { File.join(File.dirname(__FILE__), "data") }
    # Defined in test/data/etc/sysconfig/ifcfg-*
    let(:devices) { ["arc", "bond", "br", "em", "eth", "ppp", "vlan"] }

    around do |example|
      change_scr_root(data_dir, &example)
    end

    before do
      # mock type id for ppp device in sysfs
      allow(Yast::FileUtils)
        .to receive(:Exists)
        .and_return false
      allow(Yast::FileUtils)
        .to receive(:Exists)
        .with(TYPE_SYS_PATH)
        .and_return true

      allow(Yast::SCR)
        .to receive(:Read)
        .and_call_original
      allow(Yast::SCR)
        .to receive(:Read)
        .with(path(".target.string"), TYPE_SYS_PATH)
        .and_return "512\n"

      subject.CleanCacheRead
    end

    context "given a list of device types and a regex" do
      it "returns device groups that don't match the given regex" do
        expect(subject.FilterNOT(subject.FilterDevices(""), "eth").keys)
          .to eql(["bond", "br", "ppp", "vlan"])
      end
    end
  end

  describe "#ConcealSecrets1" do
    let(:ifcfg_out) do
      {
        "WIRELESS_KEY"          => "CONCEALED",
        "WIRELESS_KEY_1"        => "CONCEALED",
        "WIRELESS_KEY_2"        => "CONCEALED",
        "WIRELESS_KEY_3"        => "CONCEALED",
        "WIRELESS_KEY_4"        => "", # no need to conceal empty ones
        "WIRELESS_KEY_LENGTH"   => "128", # not a secret
        "WIRELESS_WPA_PSK"      => "CONCEALED",
        "WIRELESS_WPA_PASSWORD" => "CONCEALED",
        "other"                 => "data",
        "_aliases"              => {
          "foo" => {
            "WIRELESS_KEY" => "not masked, should not be here",
            "alias"        => "data"
          }
        }
      }
    end
    let(:ifcfg_in) do
      {
        "WIRELESS_KEY"          => "secret",
        "WIRELESS_KEY_1"        => "secret1",
        "WIRELESS_KEY_2"        => "secret2",
        "WIRELESS_KEY_3"        => "secret3",
        "WIRELESS_KEY_4"        => "", # no need to conceal empty ones
        "WIRELESS_KEY_LENGTH"   => "128", # not a secret
        "WIRELESS_WPA_PSK"      => "secretpsk",
        "WIRELESS_WPA_PASSWORD" => "seekrut",
        "other"                 => "data",
        "_aliases"              => {
          "foo" => {
            "WIRELESS_KEY" => "not masked, should not be here",
            "alias"        => "data"
          }
        }
      }
    end

    it "returns given ifcfg with wireless secret fields masked out" do
      expect(subject.ConcealSecrets1(ifcfg_in)).to eql(ifcfg_out)
    end
  end

  describe "#Locate" do
    let(:data_dir) { File.join(File.dirname(__FILE__), "data") }

    around do |example|
      change_scr_root(data_dir, &example)
    end

    before do
      subject.CleanCacheRead
    end

    it "returns an array of devices which have got given key,value" do
      expect(subject.Locate("BOOTPROTO", "static").sort).to eql(["bond0", "em1", "eth0", "eth1", "eth2"])
      expect(subject.Locate("BONDING_MASTER", "YES")).to eql(["bond0"])
    end

    it "returns an empty array if not device match given criteria" do
      expect(subject.Locate("NOTMATCH", "value")).to eql([])
    end
  end

end
