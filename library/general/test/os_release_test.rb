#! /usr/bin/env rspec

top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"

Yast.import "OSRelease"
Yast.import "FileUtils"
Yast.import "Misc"

describe Yast::OSRelease do
  describe "#ReleaseInformation" do
    it "returns product name if release file exists" do
      Yast::FileUtils.stub(:Exists).and_return(true)
      Yast::Misc.stub(:CustomSysconfigRead).and_return("openSUSE 13.1 (Bottle) (x86_64)")
      expect(Yast::OSRelease.ReleaseInformation("/mnt")).to eq "openSUSE 13.1"
    end

    it "throws exception Yast::OSReleaseFileMissingError if release file does not exist" do
      Yast::FileUtils.stub(:Exists).and_return(false)
      expect { Yast::OSRelease.ReleaseInformation("/mnt") }.to raise_error(
        Yast::OSReleaseFileMissingError
      )
    end
  end
end
