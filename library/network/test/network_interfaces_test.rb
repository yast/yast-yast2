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
      subject.main
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

  describe "#FilterDevices" do
    let(:data_dir) { File.join(File.dirname(__FILE__), "data") }
    # Defined in test/data/etc/sysconfig/ifcfg-*
    let(:netcard_devices) { ["arc", "bond", "br", "em", "eth", "vlan"] }

    around do |example|
      change_scr_root(data_dir, &example)
    end

    before do
      subject.CleanCacheRead
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

  describe "#FilterNOT" do
    let(:data_dir) { File.join(File.dirname(__FILE__), "data") }
    # Defined in test/data/etc/sysconfig/ifcfg-*
    let(:devices) { ["arc", "bond", "br", "em", "eth", "ppp", "vlan"] }

    around do |example|
      change_scr_root(data_dir, &example)
    end

    before do
      subject.CleanCacheRead
    end

    context "given a list of device types and a regex" do
      it "returns device types that don't match the given regex" do
        expect(subject.FilterNOT(subject.FilterDevices(""), "eth").keys)
          .to eql(["arc", "bond", "br", "em", "ppp", "vlan"])
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

  describe "IsHotplug" do
    it "returns true if given interfaces is a pcmcia interface" do
      expect(subject.IsHotplug("eth-pcmcia")).to eql(true)
    end
    it "returns true if given interfaces is a usb interface" do
      expect(subject.IsHotplug("eth-usb")).to eql(true)
    end

    it "return false otherwise" do
      expect(subject.IsHotplug("eth")).to eql(false)
      expect(subject.IsHotplug("qeth")).to eql(false)
      expect(subject.IsHotplug("br")).to eql(false)
    end
  end

  describe "#GetFreeDevices" do
    it "returns an array with available device numbers" do
      subject.instance_variable_set(:@Devices, "eth" => { "0" => {} })
      expect(subject.GetFreeDevices("eth", 2)).to eql(["1", "2"])
      subject.instance_variable_set(:@Devices, "eth" => { "1" => {} })
      expect(subject.GetFreeDevices("eth", 2)).to eql(["0", "2"])
      subject.instance_variable_set(:@Devices, "eth" => { "2" => {} })
      expect(subject.GetFreeDevices("eth", 2)).to eql(["0", "1"])
      subject.instance_variable_set(:@Devices, "eth-pcmcia" => { "0" => {} })
      expect(subject.GetFreeDevices("eth-pcmcia", 2)).to eql(["", "1"])
      subject.instance_variable_set(:@Devices, "eth-pcmcia" => { "" => {} })
      expect(subject.GetFreeDevices("eth-pcmcia", 2)).to eql(["0", "1"])
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

    it "returns an array of devices types which have got given key,value" do
      expect(subject.Locate("BOOTPROTO", "static")).to eql(["bond", "em", "eth"])
      expect(subject.Locate("BONDING_MASTER", "YES")).to eql(["bond"])
    end

    it "returns an empty array if not device match given criteria" do
      expect(subject.Locate("NOTMATCH", "value")).to eql([])
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

    it "returns an array of devices types which have got a different key,value than given ones" do
      expect(subject.LocateNOT("BOOTPROTO", "static")).to eql(["arc", "br", "ppp", "vlan"])
    end
  end

end
