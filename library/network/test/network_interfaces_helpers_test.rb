#!/usr/bin/env rspec
# typed: false

require_relative "test_helper"

Yast.import("NetworkInterfaces")

module Yast
  describe NetworkInterfaces do
    describe "NetworkInterfaces#filter_interfacetype" do
      it "drops interface type if present and not set to \"lo\" or \"dummy\"" do
        devmap = { "INTERFACETYPE" => "eth" }

        expect(NetworkInterfaces.filter_interfacetype(devmap)).not_to include "INTERFACETYPE"
      end

      it "keeps interface type if present and is set to \"lo\" or \"dummy\"" do
        expect(NetworkInterfaces.filter_interfacetype("INTERFACETYPE" => "lo")).to include "INTERFACETYPE"
        expect(NetworkInterfaces.filter_interfacetype("INTERFACETYPE" => "dummy")).to include "INTERFACETYPE"
      end
    end

    describe "#get_devices" do
      let(:data_dir) { File.join(File.dirname(__FILE__), "data") }
      # MOCKED IN test/data/etc/sysconfig/ifcfg*
      let(:devices) do
        ["arc5", "bond0", "br1", "em1", "eth0", "eth1", "ppp0", "tr~", "vlan3"]
      end

      around do |example|
        change_scr_root(data_dir, &example)
      end

      before do
        subject.main
        allow(subject).to receive(:Read).and_return(true)
        allow(Yast::SCR).to receive(:Dir).with(Yast::Path.new(".network.section")).and_return(devices)
      end

      it "returns an array of configured interfaces filtered by regexp" do
        expect(subject.send(:get_devices, /1/)).not_to include "em1", "eth1", "br1"
      end

      it "returns an empty array with <.> argument" do
        expect(subject.send(:get_devices, /./)).to eql []
      end

      it "returns all devices filtering with <''>" do
        expect(subject.send(:get_devices, //)).to eql devices
      end

      it "doesn't carry empty strings" do
        expect(subject.send(:get_devices, //)).not_to include ""
      end
    end

    describe "#canonicalize_config" do
      let(:in_config_without_aliases) do
        {
          "IPADDR"    => "10.0.0.1/8",
          "other"     => "data",
          "STARTMODE" => "on"
        }
      end
      let(:out_config_without_aliases) do
        {
          "IPADDR"    => "10.0.0.1",
          "PREFIXLEN" => "8",
          "NETMASK"   => "255.0.0.0",
          "other"     => "data",
          "STARTMODE" => "auto"
        }
      end
      let(:in_config) do
        {
          "IPADDR"    => "10.0.0.1/8",
          "other"     => "data",
          "STARTMODE" => "on",
          "_aliases"  => {
            "0" => {
              "IPADDR"    => "192.168.0.1/24",
              "NETMASK"   => "255.255.0.0",
              "PREFIXLEN" => "8"

            }
          }
        }
      end
      let(:out_config) do
        {
          "IPADDR"    => "10.0.0.1",
          "PREFIXLEN" => "8",
          "NETMASK"   => "255.0.0.0",
          "other"     => "data",
          "STARTMODE" => "auto",
          "_aliases"  => {
            "0" => {
              "IPADDR"    => "192.168.0.1",
              "PREFIXLEN" => "24",
              "NETMASK"   => "255.255.255.0"
            }
          }
        }
      end

      it "returns the given config with canonicalized addresses" do
        expect(subject.canonicalize_config(in_config)).to eql(out_config)
        expect(subject.canonicalize_config(in_config_without_aliases))
          .to eql(out_config_without_aliases)
      end
    end

    describe "#GetEthTypeFromSysfs" do
      let(:data_dir) { File.join(File.dirname(__FILE__), "data") }

      # MOCKED IN test/data/etc/sysconfig/ifcfg*
      #
      around do |example|
        change_scr_root(data_dir, &example)
      end

      it "returns eth if not match any sysfs entry" do
        expect(subject.GetEthTypeFromSysfs("missing_dev")).to eql("eth")
      end

      NetworkStubs::MOCKUP_SYSFS_INTERFACES.each do |dev, v|
        it "returns <#{v[:eth_type]}> for <#{dev}> if <#{v[:sysfs]} exists" do
          allow(FileUtils).to receive(:Exists).with(anything).and_return false
          allow(FileUtils).to receive(:Exists).with(v[:sysfs].to_s).and_return true
          expect(subject.GetEthTypeFromSysfs(dev.to_s)).to eql(v[:eth_type])
        end
      end
    end

    describe "#GetIbTypeFromSysfs" do
      before do
        allow(FileUtils).to receive(:Exists).with(anything).and_return false
      end

      it "returns <bond> if </sys/class/net/bond> exists" do
        allow(FileUtils).to receive(:Exists).with("/sys/class/net/bond0/bonding").and_return true

        expect(subject.GetIbTypeFromSysfs("bond0")).to eql("bond")
      end

      it "returns <ib> if </sys/class/net/create_child> exists" do
        allow(FileUtils).to receive(:Exists).with("/sys/class/net/ib0/create_child").and_return true

        expect(subject.GetIbTypeFromSysfs("ib0")).to eql("ib")
      end

      it "returns <ibchild> otherwise" do
        expect(subject.GetIbTypeFromSysfs("ib0.8001")).to eql("ibchild")
      end
    end

    describe "#devmap" do
      DEV_MAP = { "IPADDR" => "1.1.1.1" }.freeze

      it "provides a map for existing device" do
        allow(NetworkInterfaces)
          .to receive(:GetType)
          .and_return("eth")
        allow(NetworkInterfaces)
          .to receive(:Devices)
          .and_return("eth" => { "eth0" => DEV_MAP })

        expect(NetworkInterfaces.devmap("eth0")).to be DEV_MAP
      end

      it "returns nil when no device could be found" do
        expect(NetworkInterfaces.devmap("eth0")).to be nil
      end
    end
  end
end
