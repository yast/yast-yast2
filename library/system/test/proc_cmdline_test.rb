#!/usr/bin/env rspec

top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"

Yast.import "SCR"

DEFAULT_DATA_DIR = File.join(File.expand_path(File.dirname(__FILE__)), "data")

def set_root_path(directory)
  root = File.join(DEFAULT_DATA_DIR, directory)
  desc = Yast::WFM.SCROpen("chroot=#{root}:scr", false)
  Yast::WFM.SCRSetDefault(desc)
end

describe "SCR" do
  describe ".proc.cmdline" do
    describe "Read" do
      let(:expected_list) { %w(biosdevname=1 initrd=initrd install=hd:/// splash=silent) }
      let(:read_list) { Yast::SCR.Read(Yast::Path.new(".proc.cmdline")).sort }

      it "parses correctly simple files" do
        set_root_path("cmdline-simple")
        expect(read_list).to eq(expected_list)
      end

      it "parses correctly files with two separators" do
        set_root_path("cmdline-twoseparators")
        expect(read_list).to eq(expected_list)
      end

      it "parses correctly files with several lines" do
        set_root_path("cmdline-newlines")
        expect(read_list).to eq(expected_list)
      end
    end
  end
end
