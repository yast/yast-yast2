#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "PackageSystem"
Yast.import "PackagesUI"

describe "Yast::PackageSystem" do
  subject(:system) { Yast::PackageSystem }

  describe "#Install" do
    let(:package) { "ruby" }
    let(:package_installed) { "ruby-2.5-lp150.1.5.x86_64" }
    let(:output) { [package_installed, 0] }
    let(:execute) { instance_double(Yast::Execute, on_target!: output) }

    before do
      allow(Yast::Execute).to receive(:stdout).and_return(execute)
    end

    context "when some package provides the given package" do
      it "returns true" do
        expect(system.Installed("ruby")).to be(true)
      end
    end

    context "when no package provides the given package" do
      let(:output) { ["no package provides ruby\n", 1] }

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

  describe "#CheckAndInstallPackages" do
    let(:installed) { false }

    before do
      allow(subject).to receive(:InstalledAll).and_return(installed)
    end

    context "when given packages are not installed" do
      let(:installed) { false }

      it "install the packages" do
        expect(subject).to receive(:InstallAll).with(["pkg1"]).and_return(true)
        expect(subject.CheckAndInstallPackages(["pkg1"])).to eq(true)
      end
    end

    context "when given packages are installed" do
      let(:installed) { true }

      it "does not install the packages again" do
        expect(subject).to_not receive(:InstallAll)
        expect(subject.CheckAndInstallPackages(["pkg1"])).to eq(true)
      end
    end

    context "when running in config mode" do
      before do
        allow(Yast::Mode).to receive(:config).and_return(true)
      end

      it "does not install the packages" do
        expect(subject).to_not receive(:InstallAll)
        expect(subject.CheckAndInstallPackages(["pkg1"])).to eq(true)
      end
    end
  end

  describe "#CheckAndInstallPackagesInteractive" do
    let(:canceled) { false }

    before do
      allow(subject).to receive(:LastOperationCanceled).and_return(canceled)
    end

    it "installs the given package" do
      expect(subject).to receive(:CheckAndInstallPackages).with(["pkg1"]).and_return(true)
      expect(subject.CheckAndInstallPackagesInteractive(["pkg1"])).to eq(true)
    end

    context "when the packages cannot be installed" do
      before do
        allow(subject).to receive(:CheckAndInstallPackages).and_return(false)
      end

      context "when the last operation was canceled" do
        let(:canceled) { true }

        it "reports the error when running on commandline" do
          allow(Yast::Mode).to receive(:commandline).and_return(true)

          expect(Yast::Report).to receive(:Error)
          subject.CheckAndInstallPackagesInteractive(["pkg1"])
        end

        it "reports the error when not running on commandline" do
          allow(Yast::Mode).to receive(:commandline).and_return(false)

          expect(Yast::Popup).to receive(:ContinueCancel)
          subject.CheckAndInstallPackagesInteractive(["pkg1"])
        end
      end

      context "when the last operation was not canceled" do
        let(:canceled) { false }

        it "reports the error when running on commandline" do
          allow(Yast::Mode).to receive(:commandline).and_return(true)

          expect(Yast::Report).to receive(:Error)
          subject.CheckAndInstallPackagesInteractive(["pkg1"])
        end

        it "reports the error when not running on commandline" do
          allow(Yast::Mode).to receive(:commandline).and_return(false)

          expect(Yast::Popup).to receive(:ContinueCancel)
          subject.CheckAndInstallPackagesInteractive(["pkg1"])
        end
      end
    end
  end
end
