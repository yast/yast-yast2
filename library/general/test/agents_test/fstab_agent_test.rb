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

    it "returns an array containing nfs entries" do
      expect(content).to satisfy { |r| r.find { |e| e["file"] == "/home/kv2" } }
      expect(content).to satisfy { |r| r.find { |e| e["file"] == "/media/new" } }
      expect(content).to satisfy { |r| r.find { |e| e["file"] == "/media/new2" } }
    end

    it "returns an array containing tmpfs entry" do
      expect(content).to satisfy { |r| r.find { |e| e["file"] == "/tmp" } }
    end

    it "see comments" do
      pending "need to be fixed"
      expect(content).to include("#comment")
    end
  end
end
