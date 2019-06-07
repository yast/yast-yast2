#!/usr/bin/env rspec
# typed: false

require_relative "test_helper"

describe "SCR" do
  describe ".proc.cmdline" do
    describe "Read" do
      let(:data_dir) { File.join(File.dirname(__FILE__), "data") }
      let(:expected_list) { %w(biosdevname=1 initrd=initrd install=hd:/// splash=silent) }
      let(:read_list) { Yast::SCR.Read(path(".proc.cmdline")).sort }

      around do |example|
        change_scr_root(File.join(data_dir, chroot), &example)
      end

      context "processing a simple file" do
        let(:chroot) { "cmdline-simple" }

        it "parses it correctly" do
          expect(read_list).to eq(expected_list)
        end
      end

      context "processing a file with two separators" do
        let(:chroot) { "cmdline-twoseparators" }

        it "parses it correctly" do
          expect(read_list).to eq(expected_list)
        end
      end

      context "processing a file with several lines" do
        let(:chroot) { "cmdline-newlines" }

        it "parses it correctly" do
          expect(read_list).to eq(expected_list)
        end
      end
    end
  end
end
