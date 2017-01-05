#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import("NetworkInterfaces")

module Yast
  describe NetworkInterfaces do
    context "Parsing device name" do
      DEVICE_DESCS = [
        {
          name:          "",
          alias_id:      "",
          type_by_regex: ""
        },
        {
          name:          "eth0",
          alias_id:      "",
          type_by_regex: "eth"
        },
        {
          name:          "eth-pcmcia-0",
          alias_id:      "",
          type_by_regex: "eth"
        },
        {
          name:          "enp0s3",
          alias_id:      "",
          type_by_regex: "enp"
        },
        {
          name:          "eth0#1",
          alias_id:      "1",
          type_by_regex: "eth"
        },
        {
          name:          "enp0s3#0",
          alias_id:      "0",
          type_by_regex: "enp"
        }
      ]

      DEVICE_DESCS.each do |device_desc|
        device_name = device_desc[:name]
        alias_id = device_desc[:alias_id]
        type_by_regex = device_desc[:type_by_regex]

        describe "#alias_num" do
          it "returns alias_id: <#{alias_id}> for name: <#{device_name}>" do
            expect(NetworkInterfaces.alias_num(device_name)).to be_eql alias_id
          end
        end

        describe "#device_type" do
          it "returns type by regex: <#{type_by_regex}> for name: <#{device_name}>" do
            expect(NetworkInterfaces.device_type(device_name)).to be_eql type_by_regex
          end
        end
      end
    end

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
        expect(subject.get_devices("1")).not_to include "em1", "eth1", "br1"
      end

      it "filters with <[~]> by default" do
        expect(subject.get_devices).not_to include "tr~"
      end

      it "returns an empty array with <.> argument" do
        expect(subject.get_devices(".")).to eql []
      end

      it "returns all devices filtering with <''>" do
        expect(subject.get_devices("")).to eql devices
      end

      it "does not crash with exception" do
        expect { subject.get_devices }.not_to raise_error
      end

      it "doesn't carry empty strings" do
        expect(subject.get_devices).not_to include ""
      end
    end
  end
end
