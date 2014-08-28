#!/usr/bin/env rspec

require_relative "../test_helper"
require "yast"

describe ".proc.meminfo" do

  before :each do
    root = File.join(File.dirname(__FILE__), "test_root")
    set_root_path(root)
  end

  after :each do
    reset_root_path
  end

  describe ".Read" do
    let(:content) { Yast::SCR.Read(Yast::Path.new(".proc.meminfo")) }

    it "read content of /proc/meminfo return hash" do
      expect(content).to be_a(Hash)
    end

    it "returned hash contain memtotal key" do
      expect(content).to include("memtotal" => 1021032)
    end

    it "returned hash contain memfree key" do
      expect(content).to include("memfree" => 83408)
    end
  end
end
