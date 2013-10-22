#!/usr/bin/env rspec

inc_dirs = Dir.glob("../../../library/*/src")
inc_dirs.map { |inc_dir| File.expand_path(inc_dir, __FILE__) }
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"

Yast.import("NetworkInterfaces")

module Yast

  describe NetworkInterfaces do

    context "Parsing device name" do

      DEVICE_DESCS = [
        { 
          name: "",
          alias_id: "",
          type_by_regex: ""
        },
        {
          name: "eth0",
          alias_id: "",
          type_by_regex: "eth"
        },
        {
          name: "eth-pcmcia-0",
          alias_id: "",
          type_by_regex: "eth"
        },
        {
          name: "enp0s3",
          alias_id: "",
          type_by_regex: "enp"
        },
        {
          name: "eth0#1",
          alias_id: "1",
          type_by_regex: "eth"
        },
        {
          name: "enp0s3#0",
          alias_id: "0",
          type_by_regex: "enp"
        }
      ]

      DEVICE_DESCS.each do |device_desc|
          
        device_name = device_desc[:name]
        alias_id = device_desc[:alias_id]
        type_by_regex = device_desc[:type_by_regex]

        describe '#alias_num' do

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
  end
end
