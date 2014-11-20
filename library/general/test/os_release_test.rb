#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "OSRelease"
Yast.import "FileUtils"
Yast.import "Misc"

DATA_DIR = File.join(File.expand_path(File.dirname(__FILE__)), "data")

describe Yast::OSRelease do
  describe "#ReleaseInformation" do
    context "when product name contains code name, architecture, etc." do
      it "returns product name if release file exists" do
        Yast::FileUtils.stub(:Exists).and_return(true)
        Yast::Misc.stub(:CustomSysconfigRead).and_return("openSUSE 13.1 (Bottle) (x86_64)")
        expect(Yast::OSRelease.ReleaseInformation("/mnt")).to eq "openSUSE 13.1"
      end
    end

    context "when the os-release file doesn't exist" do
      it "throws exception Yast::OSReleaseFileMissingError" do
        Yast::FileUtils.stub(:Exists).and_return(false)
        expect { Yast::OSRelease.ReleaseInformation("/mnt") }.to raise_error(
          Yast::OSReleaseFileMissingError
        )
      end
    end

    context "while working with custom os-release file" do
      it "returns full product name" do
        stub_const("Yast::OSReleaseClass::OS_RELEASE_PATH", "os-release_SLES_12_Beta5")
        expect(Yast::OSRelease.ReleaseInformation(DATA_DIR)).to eq("SUSE Linux Enterprise Server 12")

        stub_const("Yast::OSReleaseClass::OS_RELEASE_PATH", "os-release_openSUSE_13.1_GM")
        # cuts out code name, architecture, etc.
        expect(Yast::OSRelease.ReleaseInformation(DATA_DIR)).to eq("openSUSE 13.1")
      end
    end
  end

  describe "#ReleaseName" do
    it "returns a release name" do
      stub_const("Yast::OSReleaseClass::OS_RELEASE_PATH", "os-release_SLES_12_Beta5")
      expect(Yast::OSRelease.ReleaseName(DATA_DIR)).to eq("SLES")

      stub_const("Yast::OSReleaseClass::OS_RELEASE_PATH", "os-release_openSUSE_13.1_GM")
      expect(Yast::OSRelease.ReleaseName(DATA_DIR)).to eq("openSUSE")
    end
  end

  describe "#ReleaseVersion" do
    it "returns a release version" do
      stub_const("Yast::OSReleaseClass::OS_RELEASE_PATH", "os-release_SLES_12_Beta5")
      expect(Yast::OSRelease.ReleaseVersion(DATA_DIR)).to eq("12")

      stub_const("Yast::OSReleaseClass::OS_RELEASE_PATH", "os-release_openSUSE_13.1_GM")
      expect(Yast::OSRelease.ReleaseVersion(DATA_DIR)).to eq("13.1")
    end
  end
end
