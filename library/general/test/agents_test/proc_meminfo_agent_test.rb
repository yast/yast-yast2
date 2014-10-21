#!/usr/bin/env rspec

require_relative "../test_helper"
require "yast"

describe ".proc.meminfo" do

  AGENT_PATH = Yast::Path.new(".proc.meminfo")
  before :each do
    root = File.join(File.dirname(__FILE__), "test_root")
    check_version = false
    handle = Yast::WFM.SCROpen("chroot=#{root}:scr", check_version)
    Yast::WFM.SCRSetDefault(handle)
  end

  after :each do
    Yast::WFM.SCRClose(Yast::WFM.SCRGetDefault)
  end

  describe ".Read" do
    it "read content of /proc/meminfo return hash" do
      content = Yast::SCR.Read(AGENT_PATH)
      expect(content).to be_a(Hash)
    end

    it "returned hash contain memtotal key" do
      content = Yast::SCR.Read(AGENT_PATH)
      expect(content).to include("memtotal" => 1021032)
    end

    it "returned hash contain memfree key" do
      content = Yast::SCR.Read(AGENT_PATH)
      expect(content).to include("memfree" => 83408)
    end
  end
end
