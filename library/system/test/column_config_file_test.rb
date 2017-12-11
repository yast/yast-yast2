#!/usr/bin/rspec
#
# Unit test for ColumnConfigFile
#
# (c) 2017 Stefan Hundhammer <Stefan.Hundhammer@gmx.de>
#     Donated to the YaST project
#
# Original project: https://github.com/shundhammer/ruby-commented-config-file
#
# License: GPL V2
#

require_relative "test_helper"
require "yast2/column_config_file"

describe ColumnConfigFile do
  # rubocop:disable Lint/AmbiguousRegexpLiteral

  context "Parser" do
    describe "#parse" do
      context "Demo /etc/fstab with header and footer comments" do
        before(:all) do
          @file = described_class.new
          @file.read(TEST_DATA + "fstab/demo-fstab")
        end
        subject { @file }

        it "Has the correct header comments" do
          header = subject.header_comments
          expect(header.size).to eq 15
          expect(header[0]).to match /static file system information/
          expect(header[-2]).to match /mount point.*type.*dump.*pass/
          expect(header[-1]).to match /^\s*$/
        end

        it "Has the correct footer comments" do
          footer = subject.footer_comments
          expect(footer.size).to eq 1
          expect(footer[0]).to match /^\s*$/
        end

        it "Has the correct number of entries" do
          expect(subject.size).to eq 9
        end

        it "The first entry ('swap') is correct" do
          entry = subject.first
          expect(entry.columns.size).to eq 6

          expect(entry.columns[0]).to eq "/dev/disk/by-label/swap"
          expect(entry.columns[1]).to eq "none"
          expect(entry.columns[2]).to eq "swap"
          expect(entry.columns[3]).to eq "sw"
          expect(entry.columns[4]).to eq "0"
          expect(entry.columns[5]).to eq "0"

          expect(entry.comment_before.size).to eq 1
          expect(entry.comment_before.first).to match /Linux disk/
        end

        it "The root filesystem entry is correct" do
          entry = subject.entries[2]
          expect(entry.columns.size).to eq 6

          expect(entry.columns[0]).to eq "/dev/disk/by-label/Ubuntu"
          expect(entry.columns[1]).to eq "/"
          expect(entry.columns[2]).to eq "ext4"
          expect(entry.columns[3]).to eq "errors=remount-ro"
          expect(entry.columns[4]).to eq "0"
          expect(entry.columns[5]).to eq "1"

          expect(entry.comment_before?).to eq false
          expect(entry.line_comment?).to eq false
        end

        it "The last entry ('fritz.nas') is correct" do
          entry = subject.last
          expect(entry.columns.size).to eq 6

          expect(entry.columns[0]).to eq "//fritz.box/fritz.nas/"
          expect(entry.columns[1]).to eq "/fritz.nas"
          expect(entry.columns[2]).to eq "cifs"
          expect(entry.columns[3]).to match /^credentials.*forcegid$/
          expect(entry.columns[4]).to eq "0"
          expect(entry.columns[5]).to eq "0"
        end
      end
    end
  end

  context "Formatter" do
    describe("#format_lines") do
      def read_twice(filename)
        orig = File.read(filename).chomp
        file = described_class.new
        file.read(filename)
        file.max_column_widths = [45, 25, 7, 30, 1, 1]
        file.pad_columns = true
        formatted = file.to_s
        [orig, formatted]
      end

      it "reproduces exactly the original format with header and footer" do
        orig, formatted = read_twice(TEST_DATA + "fstab/demo-fstab")
        expect(formatted).to eq orig
      end

      it "reproduces exactly the original format without header or footer" do
        orig, formatted = read_twice(TEST_DATA + "fstab/demo-fstab-no-header")
        expect(formatted).to eq orig
      end
    end
  end
end
