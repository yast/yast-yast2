#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "PackageSystem"
Yast.import "PackagesUI"

describe "Yast::PackageSystem" do
  subject(:system) { Yast::PackageSystem }

  describe "#Install" do
    let(:package) { "ruby" }
    let(:package_installed) { "ruby-2.5-lp150.1.5.x86_64" }
    let(:output) { package_installed }
    let(:execute) { instance_double(Yast::Execute, stdout: output) }

    before do
      allow(Yast::Execute).to receive(:on_target).and_return(execute)
    end

    context "when some package provides the given package" do
      it "returns true" do
        expect(system.Installed("ruby")).to be(true)
      end
    end

    context "when no package provides the given package" do
      let(:output) { nil }

      it "returns false" do
        expect(system.Installed("ruby")).to be(false)
      end
    end
  end

  describe "DoInstallAndRemove" do
    let(:lock_free) { true }
    let(:result) { [1, [], [], [], []] }

    before do
      allow(Yast::PackageLock).to receive(:Check).and_return(lock_free)
      allow(system).to receive(:EnsureSourceInit)
      allow(system).to receive(:EnsureTargetInit)
      allow(Yast::Pkg).to receive(:PkgGetLicensesToConfirm).and_return([])
      allow(Yast::Pkg).to receive(:PkgSolve).and_return(true)
      allow(system).to receive(:SelectPackages).and_return(true)
      allow(Yast::Pkg).to receive(:IsAnyResolvable).with(:package, :to_install).and_return(true)
      allow(Yast::Pkg).to receive(:PkgCommit).with(0).and_return(result)
      allow(system).to receive(:InstalledAll).and_return(true)
    end

    context "when package system is locked" do
      let(:lock_free) { false }

      it "returns false" do
        expect(system.DoInstallAndRemove(["pkg1"], ["pkg2"])).to eq(false)
      end
    end

    context "when update messages are received" do
      let(:result) { [1, [], [], [], [message]] }
      let(:message) do
        {
          "solvable"         => "dummy-package",
          "text"             => "Some dummy text.",
          "installationPath" => "/var/adm/update-message/dummy-package-1.0",
          "currentPath"      => "/var/adm/update-message/dummy-package-1.0"
        }
      end

      it "shows the update messages" do
        expect(Yast::PackagesUI).to receive(:show_update_messages).with(result)
        expect(system.DoInstallAndRemove(["pkg1"], ["pkg2"])).to eq(true)
      end
    end
  end
end
