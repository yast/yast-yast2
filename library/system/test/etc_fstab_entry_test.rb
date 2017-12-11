#!/usr/bin/rspec
#
# Unit test for EtcFstab::Entry
#
# (c) 2017 Stefan Hundhammer <Stefan.Hundhammer@gmx.de>
#     Donated to the YaST project
#
# Original project: https://github.com/shundhammer/ruby-commented-config-file
#
# License: GPL V2
#

require_relative "test_helper"
require "yast2/etc_fstab"

describe EtcFstab::Entry do
  describe "#new" do
    it "can be created empty" do
      entry = described_class.new
      expect(entry).not_to be_nil
      expect(entry.to_a).to eq [nil, nil, nil, [], 0, 0]
    end

    it "can be created from an array" do
      mount_opts = []
      arr = ["/dev/sdb3", "/data3", "btrfs", mount_opts, 7, 2]
      entry = described_class.new(arr)
      expect(entry).not_to be_nil
      expect(entry.to_a).to eq arr
    end

    it "can be created with varargs" do
      entry = described_class.new("/dev/sdb3", "/data3", "btrfs")
      expect(entry).not_to be_nil
      expect(entry.to_a).to eq ["/dev/sdb3", "/data3", "btrfs", [], 0, 0]
    end

    it "can be created from a hash" do
      args =
        {
          device:         "/dev/vda2",
          mount_point:    "/home",
          fs_type:        "xfs",
          mount_opts:     ["foo", "bar"],
          dump_pass:      42,
          fsck_pass:      3,
          comment_before: ["# Home", "# sweet home"]
        }

      entry = described_class.new(args)
      expect(entry).not_to be_nil
      expect(entry.to_a).to eq ["/dev/vda2", "/home", "xfs", ["foo", "bar"], 42, 3]
      expect(entry.comment_before).to eq ["# Home", "# sweet home"]
    end

    it "can be created with named parameters" do
      entry = described_class.new(device: "/dev/sda4", mount_point: "/data", fs_type: "ext4")
      expect(entry).not_to be_nil
      expect(entry.to_a).to eq ["/dev/sda4", "/data", "ext4", [], 0, 0]
    end
  end

  describe "#parse" do
    subject { EtcFstab::Entry.new }

    it "parses a correct entry correctly" do
      subject.parse("/dev/sda1 /data xfs defaults 0 1")
      expect(subject.device).to eq "/dev/sda1"
      expect(subject.mount_point).to eq "/data"
      expect(subject.fs_type).to eq "xfs"
      expect(subject.mount_opts).to eq []
      expect(subject.dump_pass).to eq 0
      expect(subject.fsck_pass).to eq 1
    end

    it "removes all 'defaults' from the mount options" do
      subject.parse("/dev/sda1 /data xfs ro,defaults,defaults,foo 0 1")
      expect(subject.mount_opts).to eq ["ro", "foo"]
    end

    it "throws an exception if the number of columns is wrong" do
      expect { subject.parse("/dev/sda1 /data xfs duh defaults 0 1", 42) }
        .to raise_error(EtcFstab::ParseError, /in line 43/)

      expect { subject.parse("/dev/sda1 /data xfs duh defaults 0 1") }
        .to raise_error(EtcFstab::ParseError, "Wrong number of columns")

      expect { subject.parse("/dev/sda1 /data defaults 0 1") }
        .to raise_error(EtcFstab::ParseError)
    end
  end

  describe "#format" do
    subject { EtcFstab::Entry.new }

    it "formats a simple entry correctly" do
      subject.device = "/dev/sdb7"
      subject.mount_point = "/work"
      subject.fs_type = "ext4"
      subject.populate_columns
      expect(subject.format).to eq "/dev/sdb7  /work  ext4  defaults  0  0"
    end
  end
end
