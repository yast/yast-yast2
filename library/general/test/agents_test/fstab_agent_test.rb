#!/usr/bin/env rspec

require_relative "../test_helper"
require "yast"

describe ".proc.meminfo" do
  around :each do |example|
    root = File.join(File.dirname(__FILE__), "test_root")
    change_scr_root(root, &example)
  end

  describe ".Read" do
    let(:content) { Yast::SCR.Read(path(".etc.fstab")) }

    it "reads content of /etc/fstab and returns array" do
      expect(content).to be_a(Array)
    end

    it "returned array contains nfs entries" do
      expect(content).to satisfy { |r| r.find { |e| e["file"] == "/home/kv2" } }
      expect(content).to satisfy { |r| r.find { |e| e["file"] == "/media/new" } }
      expect(content).to satisfy { |r| r.find { |e| e["file"] == "/media/new2" } }
    end

    it "returned array contains tmpfs entry" do
      expect(content).to satisfy { |r| r.find { |e| e["file"] == "/tmp" } }
    end
  end
end
