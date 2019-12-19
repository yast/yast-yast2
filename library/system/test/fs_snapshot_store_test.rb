#!/usr/bin/env rspec

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "yast2/fs_snapshot_store"

describe Yast2::FsSnapshotStore do
  describe ".save" do
    let(:root_dir) { Dir.mktmpdir }

    before do
      allow(Yast::SCR).to receive(:Write).and_call_original
    end

    around do |example|
      change_scr_root(root_dir, &example)
    ensure
      ::FileUtils.remove_entry(root_dir) if Dir.exist?(root_dir)
    end

    it "stores snapshot id to file identified by purpose" do
      described_class.save("test", 42)
      snapshot_id_file = File.join(root_dir, "/var/lib/YaST2/pre_snapshot_test.id")
      expect(File.read(snapshot_id_file)).to eq("42")
    end

    it "raises exception if writing failed" do
      expect(Yast::SCR).to receive(:Write).with(
        path(".target.string"),
        "/var/lib/YaST2/pre_snapshot_test.id",
        "42"
      ).and_return(nil)

      expect { described_class.save("test", 42) }.to raise_error(/Failed to write/)
    end

    it "ensures that the data directory exists" do
      described_class.save("test", 42)
      expect(Dir).to exist(File.join(root_dir, "/var/lib/YaST2"))
    end
  end

  describe ".load" do
    it "loads snapshot id from file identified by purpose" do
      expect(Yast::SCR).to receive(:Read).with(
        path(".target.string"),
        "/var/lib/YaST2/pre_snapshot_test.id"
      ).and_return("42\n")

      expect(described_class.load("test")).to eq 42
    end

    it "raises exception if reading failed" do
      expect(Yast::SCR).to receive(:Read).with(
        path(".target.string"),
        "/var/lib/YaST2/pre_snapshot_test.id"
      ).and_return(nil)

      expect { described_class.load("test") }.to raise_error(/Failed to read/)
    end

    it "raises exception if file content is not number" do
      expect(Yast::SCR).to receive(:Read).with(
        path(".target.string"),
        "/var/lib/YaST2/pre_snapshot_test.id"
      ).and_return("blabla\n")

      expect { described_class.load("test") }.to raise_error(/Failed to read/)
    end
  end

  describe "clean" do
    it "cleans file storing snapshot id" do
      expect(Yast::SCR).to receive(:Execute).with(
        path(".target.remove"),
        "/var/lib/YaST2/pre_snapshot_test.id"
      )

      described_class.clean("test")
    end

    context "in initial stage before SCR switched" do
      it "use path on mounted target system" do
        Yast.import "Installation"
        Yast::Installation.destdir = "/mnt"

        Yast.import "Stage"
        allow(Yast::Stage).to receive(:initial).and_return(true)
        allow(Yast::WFM).to receive(:scr_chrooted?).and_return(false)

        expect(Yast::SCR).to receive(:Execute).with(
          path(".target.remove"),
          "/mnt/var/lib/YaST2/pre_snapshot_test.id"
        )

        described_class.clean("test")
      end
    end
  end
end
