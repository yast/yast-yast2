#!/usr/bin/rspec
#
# Unit test for EtcFstab
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
require "fileutils"

describe EtcFstab do
  context "with demo-fstab" do
    before(:all) { @fstab = described_class.new(TEST_DATA + "fstab/demo-fstab") }
    subject { @fstab }

    describe "Parser and access methods" do
      it "has the expected number of entries" do
        expect(subject.size).to eq 9
      end

      it "has the expected devices" do
        devices =
          ["/dev/disk/by-label/swap",
           "/dev/disk/by-label/openSUSE",
           "/dev/disk/by-label/Ubuntu",
           "/dev/disk/by-label/work",
           "/dev/disk/by-label/Win-Boot",
           "/dev/disk/by-label/Win-App",
           "nas:/share/sh",
           "nas:/share/work",
           "//fritz.box/fritz.nas/"]
        expect(subject.devices).to eq devices
      end

      it "has the expected mount points" do
        mount_points =
          ["none",
           "/alternate-root",
           "/",
           "/work",
           "/win/boot",
           "/win/app",
           "/nas/sh",
           "/nas/work",
           "/fritz.nas"]
        expect(subject.mount_points).to eq mount_points
      end

      it "has the expected filesystem types" do
        fs_types =
          ["swap",
           "ext4",
           "ext4",
           "ext4",
           "ntfs",
           "ntfs",
           "nfs",
           "nfs",
           "cifs"]
        expect(subject.fs_types).to eq fs_types
      end

      it "the root filesystem has the correct mount options and fsck pass" do
        entry = subject.find_mount_point("/")
        expect(entry).not_to be_nil
        expect(entry.mount_opts).to eq ["errors=remount-ro"]
        expect(entry.fsck_pass).to be == 1
      end

      it "the /work filesystem has no mount options" do
        entry = subject.find_mount_point("/work")
        expect(entry).not_to be_nil
        expect(entry.mount_opts).to eq []
        expect(entry.mount_opts.empty?).to be true
      end

      it "the Windows boot partition has the correct mount options" do
        entry = subject.find_device("/dev/disk/by-label/Win-Boot")
        expect(entry).not_to be_nil
        expect(entry.mount_opts).to eq ["umask=007", "gid=46"]
      end

      it "the /fritz.nas partition's mount options are not cut off" do
        entry = subject.find_mount_point("/fritz.nas")
        expect(entry).not_to be_nil
        opts = entry.mount_opts.dup
        expect(opts.shift).to end_with("credentials.txt")
        expect(opts).to eq ["uid=sh", "forceuid", "gid=users", "forcegid"]
      end

      it "the two Linux non-root partitions have fsck_pass 2" do
        entries = subject.select { |e| e.fsck_pass == 2 }
        devices = entries.map(&:device)
        expected_devices =
          ["/dev/disk/by-label/openSUSE",
           "/dev/disk/by-label/work"]
        expect(devices).to eq expected_devices
      end

      it "all non-ext4 filesystems have fsck_pass 0" do
        entries = subject.reject { |e| e.fs_type == "ext4" }
        nonzero_fsck = entries.reject { |e| e.fsck_pass == 0 }
        expect(nonzero_fsck).to be_empty
      end

      it "all dump_pass fields are 0" do
        dump_pass = subject.map(&:dump_pass)
        expect(dump_pass.count(0)).to be == 9
      end
    end

    describe "#fstab_encode" do
      it "escapes space characters correctly" do
        encoded = described_class.fstab_encode("very weird name")
        expect(encoded).to eq "very\\040weird\\040name"
      end
    end

    describe "#fstab_decode" do
      it "unescapes escaped space characters correctly" do
        decoded = described_class.fstab_decode("very\\040weird\\040name")
        expect(decoded).to eq "very weird name"
      end

      it "unescaping an escaped string with spaces results in the original" do
        orig = "very weird name"
        encoded = described_class.fstab_encode(orig)
        decoded = described_class.fstab_decode(encoded)
        expect(decoded).to eq orig
      end
    end

    describe "#get_mount_by" do
      it "correctly detects a device mounted by label" do
        entry = subject.find_mount_point("/work")
        expect(entry).not_to be_nil
        expect(entry.get_mount_by).to eq :label

        expect(described_class.get_mount_by("LABEL=work")).to eq :label
      end

      it "correctly detects a device mounted by UUID" do
        expect(described_class.get_mount_by("UUID=4711")).to eq :uuid
        expect(described_class.get_mount_by("/dev/disk/by-uuid/4711")).to eq :uuid
      end

      it "correctly detects a device mounted by device" do
        entry = subject.find_mount_point("/nas/work")
        expect(entry).not_to be_nil
        expect(entry.get_mount_by).to eq :device
      end

      it "correctly detects a device mounted by path" do
        expect(described_class.get_mount_by("/dev/disk/by-path/pci-00:11.4")).to eq :path
      end
    end

    describe "#check_mount_order" do
      it "detects a mount order problem" do
        expect(subject.check_mount_order).to be false
      end
    end

    describe "#next_mount_order_problem" do
      it "finds the mount order problem" do
        problem_index = subject.next_mount_order_problem
        expect(problem_index).to be == 2
        entry = subject.entries[problem_index]
        expect(entry).not_to be_nil
        expect(entry.mount_point).to eq "/"
      end
    end

    describe "#find_sort_index" do
      it "finds the correct place to move the problematic mount point to" do
        problem_index = 2
        entry = subject.entries[problem_index]
        expect(entry).not_to be_nil
        expect(subject.send(:find_sort_index, entry)).to be == 1
      end
    end

    describe "#fix_mount_order" do
      it "fixes the mount order problem" do
        new_fstab = subject.dup
        new_fstab.fix_mount_order
        mount_points =
          ["none",
           "/", # moved one position up
           "/alternate-root",
           "/work",
           "/win/boot",
           "/win/app",
           "/nas/sh",
           "/nas/work",
           "/fritz.nas"]
        expect(new_fstab.mount_points).to eq mount_points
        expect(new_fstab.check_mount_order).to be true
      end
    end
  end

  context "created empty" do
    let(:root) do
      EtcFstab::Entry.new("/dev/sda1", "/", "ext4")
    end

    let(:var) do
      EtcFstab::Entry.new("/dev/sda2", "/var", "xfs")
    end

    let(:var_lib) do
      EtcFstab::Entry.new("/dev/sda3", "/var/lib", "jfs")
    end

    let(:var_lib_myapp) do
      EtcFstab::Entry.new("/dev/sda4", "/var/lib/myapp", "ext3")
    end

    let(:var_lib2) do
      EtcFstab::Entry.new("/dev/sda5", "/var/lib", "ext2")
    end

    describe "#add_entry" do
      it "adds entries in the correct sequence" do
        subject.add_entry(var_lib_myapp)
        subject.add_entry(var)
        subject.add_entry(var_lib)
        subject.add_entry(root)
        expect(subject.mount_points).to eq ["/", "/var", "/var/lib", "/var/lib/myapp"]
      end
    end

    describe "#fix_mount_order" do
      it "fixes a wrong mount order" do
        # Intentionally using the wrong superclass method to add items
        subject.entries << var_lib_myapp << var << var_lib << root

        # Wrong order as expected
        expect(subject.mount_points).to eq ["/var/lib/myapp", "/var", "/var/lib", "/"]
        expect(subject.check_mount_order).to be false

        expect(subject.fix_mount_order).to be true
        expect(subject.mount_points).to eq ["/", "/var", "/var/lib", "/var/lib/myapp"]
        expect(subject.check_mount_order).to be true
      end

      it "does not get into an endless loop in the pathological case" do
        # Intentionally using the wrong superclass method to add items.
        subject.entries << var_lib << var_lib2 << var << root

        # Wrong order as expected
        expect(subject.mount_points).to eq ["/var/lib", "/var/lib", "/var", "/"]
        expect(subject.check_mount_order).to be false

        expect(subject.fix_mount_order).to be false
        expect(subject.mount_points).to eq ["/", "/var", "/var/lib", "/var/lib"]

        # There still is a problem; we couldn't fix it completely.
        # This is expected.
        expect(subject.check_mount_order).to be false
      end
    end

    describe "#format_lines" do
      it "formats a simple entry correctly" do
        entry = subject.create_entry(device: "/dev/sdk3", mount_point: "/work",
          fs_type: "ext4", mount_opts: ["ro", "foo", "bar"])
        subject.add_entry(entry)
        subject.output_delimiter = " "

        expect(subject.size).to eq 1
        expect(subject.first).to equal(entry)
        expect(subject.format_lines).to eq ["/dev/sdk3 /work ext4 ro,foo,bar 0 0"]
      end
    end
  end

  context "with demo-fstab" do
    before(:all) { @fstab = described_class.new(TEST_DATA + "fstab/demo-fstab") }
    subject { @fstab }

    let(:save_as_name) { TEST_DATA + "fstab/demo-fstab-2-generated" }
    let(:modified_reference_name) { TEST_DATA + "fstab/demo-fstab-2-expected" }

    describe "full-blown read, modify, write cycle" do
      it "reads the file correctly" do
        # Notice that constructing an EtcFstab with a filename will read that
        # file right away
        expect(subject.size).to eq 9
        devices =
          ["/dev/disk/by-label/swap",
           "/dev/disk/by-label/openSUSE",
           "/dev/disk/by-label/Ubuntu",
           "/dev/disk/by-label/work",
           "/dev/disk/by-label/Win-Boot",
           "/dev/disk/by-label/Win-App",
           "nas:/share/sh",
           "nas:/share/work",
           "//fritz.box/fritz.nas/"]
        expect(subject.devices).to eq devices
      end

      it "has the expected header and footer comments" do
        expect(subject.header_comments.size).to be == 15
        expect(subject.footer_comments.size).to be == 1
      end

      it "has the expected comments before certain entries" do
        commented = subject.select(&:comment_before?)
        expect(commented.size).to be == 4

        entry = commented.shift
        expect(entry.fs_type).to eq "swap"
        expect(entry.comment_before).to eq ["# Linux disk"]

        entry = commented.shift
        expect(entry.mount_point).to eq "/win/boot"
        expect(entry.comment_before).to eq ["", "# Windows disk"]

        entry = commented.shift
        expect(entry.mount_point).to eq "/nas/sh"
        expect(entry.comment_before).to eq ["", "# Network"]

        entry = commented.shift
        expect(entry.mount_point).to eq "/fritz.nas"
        expect(entry.comment_before).to eq [""]
      end

      it "can rearrange entries" do
        win_boot = subject.find_mount_point("/win/boot")
        win_app = subject.find_mount_point("/win/app")

        # Move both Windows partitions to the end (after the network shares)
        subject.entries -= [win_boot, win_app]
        subject.entries << win_boot << win_app

        mount_points =
          ["none",
           "/alternate-root",
           "/",
           "/work",
           "/nas/sh",
           "/nas/work",
           "/fritz.nas",
           "/win/boot",
           "/win/app"]
        expect(subject.mount_points).to eq mount_points
      end

      it "can modify existing entries" do
        nas_shares = subject.select { |s| s.device.start_with?("nas:") }
        nas_shares.each { |s| s.device.gsub!(/^nas/, "home_nas") }

        devices =
          ["/dev/disk/by-label/swap",
           "/dev/disk/by-label/openSUSE",
           "/dev/disk/by-label/Ubuntu",
           "/dev/disk/by-label/work",
           "home_nas:/share/sh",
           "home_nas:/share/work",
           "//fritz.box/fritz.nas/",
           "/dev/disk/by-label/Win-Boot",
           "/dev/disk/by-label/Win-App"]
        expect(subject.devices).to eq devices
      end

      it "can remove entries" do
        # Removing the longest mount point to test the automatic column sizing
        # and alignment inherited from ColumnConfigFile
        subject.delete_if { |e| e.mount_point.include?("alternate") }
        subject.delete_if { |e| e.device.include?("fritz") }

        devices =
          ["/dev/disk/by-label/swap",
           "/dev/disk/by-label/Ubuntu",
           "/dev/disk/by-label/work",
           "home_nas:/share/sh",
           "home_nas:/share/work",
           "/dev/disk/by-label/Win-Boot",
           "/dev/disk/by-label/Win-App"]
        expect(subject.devices).to eq devices
      end

      it "can add entries in the correct order" do
        entry = subject.create_entry("LABEL=logs", "/var/log", "xfs")
        subject.add_entry(entry)

        entry = subject.create_entry("LABEL=var", "/var", "ext2")
        entry.comment_before = ["", "# Data that keep growing"]
        # This should go before /var/log; add_entry is expected to move it there.
        subject.add_entry(entry)

        devices =
          ["/dev/disk/by-label/swap",
           "/dev/disk/by-label/Ubuntu",
           "/dev/disk/by-label/work",
           "home_nas:/share/sh",
           "home_nas:/share/work",
           "/dev/disk/by-label/Win-Boot",
           "/dev/disk/by-label/Win-App",
           "LABEL=var",
           "LABEL=logs"]
        expect(subject.devices).to eq devices
      end

      it "correctly escapes blank characters in device names" do
        win = subject.select { |e| e.device.include?("Win-") }
        win.each { |e| e.device.gsub!(/Win-/, "Win ") }

        # Using to_s and not Entry.format here to make sure the columns are
        # updated (populated) from the fields which Entry.to_s enforces, but
        # Entry.format does not (for efficiency).

        expect(win[0].to_s).to include "/Win\\040Boot"
        expect(win[1].to_s).to include "/Win\\040App"
      end

      it "writes the result to file correctly" do
        subject.write(save_as_name)

        # If this fails:
        #   diff -u data/fstab/demo-fstab-2-expected data/fstab/demo-fstab-2-generated
        #
        expect(FileUtils.cmp(save_as_name, modified_reference_name)).to be true

        # Delete the written file if the test passed
        File.delete(save_as_name) if File.exist?(save_as_name)
      end
    end
  end
end
