#!/usr/bin/env rspec

require_relative "test_helper"
#require_relative "../src/lib/yast2/fs_snapshot"
require "yast2/fs_snapshot"

describe Yast2::FsSnapshot do
  CREATE_CONFIG = "/usr/bin/snapper --no-dbus create-config -f btrfs /"
  FIND_CONFIG = "/usr/bin/snapper --no-dbus list-configs | grep \"^root \" >/dev/null"
  LIST_SNAPSHOTS = "LANG=en_US.UTF-8 /usr/bin/snapper --no-dbus list"

  describe ".configure" do
    before do
      allow(described_class).to receive(:configured?).and_return(configured)
    end

    context "when no configuration exists" do
      let(:configured) { false }

      it "tries to create the configuration and returns true if it was successful" do
        expect(Yast::SCR).to receive(:Execute).
          with(path(".target.bash_output"), CREATE_CONFIG).
          and_return({"stdout" => "", "exit" => 0})
        expect(described_class.configure).to eq(true)
      end

      it "tries to create the configuration and returns false if it wasn't successful" do
        expect(Yast::SCR).to receive(:Execute).
          with(path(".target.bash_output"), CREATE_CONFIG).
          and_return({"stdout" => "", "exit" => 1})
        expect(described_class.configure).to eq(false)
      end
    end

    context "when a configuration exists" do
      let(:configured) { true }

      it "does not try to create the configuration and returns true" do
        expect(Yast::SCR).to_not receive(:Execute).
          with(path(".target.bash_output"), CREATE_CONFIG)
        expect(described_class.configure).to eq(true)
      end
    end
  end

  describe ".configured?" do
    before do
      allow(Yast::SCR).to receive(:Execute).
        with(path(".target.bash_output"), FIND_CONFIG).
        and_return({ "stdout" => "", "exit" => find_code})
    end

    context "when snapper's configuration does not exist" do
      let(:find_code) { 1 }

      it "returns false" do
        expect(described_class.configured?).to eq(false)
      end
    end

    context "when snapper's configuration exists" do
      let(:find_code) { 0 }

      it "returns false" do
        expect(described_class.configured?).to eq(true)
      end
    end
  end

  describe ".create" do
    CREATE_SNAPSHOT = "/usr/lib/snapper/installation-helper --step 5 --description \"some-description\""

    before do
      allow(Yast::SCR).to receive(:Execute).
        with(path(".target.bash_output"), CREATE_SNAPSHOT).
        and_return(output)
    end

    context "when snapshot creation fails" do
      let(:output) { { "stdout" => "", "exit" => 1 } }

      it "should returns nil" do
        expect(described_class.create("some-description")).to be_nil
      end
    end

    context "when snapshot creation is successful" do
      let(:output) { { "stdout" => "2", "exit" => 0 } }
      let(:dummy_snapshot) { double('snapshot') }

      it "should return the just create snapshot" do
        expect(described_class).to receive(:find).with(2).
          and_return(dummy_snapshot)
        snapshot = described_class.create("some-description")
        expect(snapshot).to be(dummy_snapshot)
      end
    end
  end

  describe ".all" do
    let(:output) { File.read(output_path) }

    before do
      allow(Yast::SCR).to receive(:Execute).
        with(path('.target.bash_output'), LIST_SNAPSHOTS).
        and_return({ "stdout" => output, "exit" => 0 })
    end

    context "given some snapshots exist" do
      let(:output_path) { File.expand_path("../fixtures/snapper-list.txt", __FILE__) }

      it "should return the snapshots ordered by timestamp" do
        snapshots = described_class.all
        expect(snapshots).to be_kind_of(Array)
        expect(snapshots.size).to eq(5)
      end
    end

    context "given no snapshots exist" do
      let(:output_path) { File.expand_path("../fixtures/empty-snapper-list.txt", __FILE__) }

      it "should return an empty array" do
        expect(described_class.all).to eq([])

      end
    end
  end

  describe ".find" do
    let(:output) { File.read(output_path) }
    let(:output_path) { File.expand_path("../fixtures/snapper-list.txt", __FILE__) }

    before do
      allow(Yast::SCR).to receive(:Execute).
        with(path('.target.bash_output'), LIST_SNAPSHOTS).
        and_return({ "stdout" => output, "exit" => 0 })
    end

    context "when a snapshot with that number exists" do
      it "should return the snapshot" do
        snapshot = described_class.find(4)
        expect(snapshot.number).to eq(4)
        expect(snapshot.snapshot_type).to eq(:post)
        expect(snapshot.previous).to eq(3)
        expect(snapshot.timestamp).to eq(DateTime.parse("Wed 13 May 2015 05:03:13 PM WEST"))
        expect(snapshot.user).to eq("root")
        expect(snapshot.cleanup).to eq(:number)
        expect(snapshot.description).to eq("zypp(zypper)")
      end
    end

    context "when a snapshot with that number does not exists" do
      it "should return nil" do
        expect(described_class.find(100)).to be_nil
      end
    end
  end
end
