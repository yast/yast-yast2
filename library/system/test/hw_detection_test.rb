#!/usr/bin/env rspec

require "yast"

require_relative "../src/lib/yast2/hw_detection"

describe "HwDetection" do
  before do
    # 16GB
    @ramsize = 16*1024*1024*1024
    @memory = {
      "bus" => "None",
      "bus_hwcfg" => "none",
      "class_id" => 257,
      "model" => "Main Memory",
      "old_unique_key" => "4srm.CxwsZFjVASF",
      "resource" =>  {
        "mem" => [{"active" => true, "length" => 16815341568, "start" => 0}],
        "phys_mem" => [{"range" => @ramsize}]
      },
      "sub_class_id" => 2,
      "unique_key" => "rdCR.CxwsZFjVASF"
    }
    @non_memory = {
      "class_id" => 42,
      "sub_class_id" => 42,
      "resource" =>  {
        "mem" => [{"active" => true, "length" => 16815341568, "start" => 0}],
        "phys_mem" => [{"range" => @ramsize}]
      }
    }
  end

  describe "#memory" do
    it "returns detected memory size in bytes" do
      Yast::SCR.should_receive(:Read).with(Yast::Path.new(".probe.memory")).and_return([@memory])
      expect(Yast2::HwDetection.memory).to eq(@ramsize)
    end

    it "sums detected memory sizes" do
      Yast::SCR.should_receive(:Read).with(Yast::Path.new(".probe.memory")).and_return([@memory, @memory])
      expect(Yast2::HwDetection.memory).to eq(2*@ramsize)
    end

    it "ignores non-memory devices" do
      Yast::SCR.should_receive(:Read).with(Yast::Path.new(".probe.memory")).and_return([@memory, @non_memory])
      expect(Yast2::HwDetection.memory).to eq(@ramsize)
    end

    it "raises exception when detection fails" do
      Yast::SCR.should_receive(:Read).with(Yast::Path.new(".probe.memory")).and_return(nil)
      expect{Yast2::HwDetection.memory}.to raise_error
    end
  end
end
