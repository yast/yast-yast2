# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "test_helper"

Yast.import "Package"
Yast.import "Mode"

describe Yast::Package do
  subject { Yast::Package }

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

  describe "#DoInstall" do
    it "installs the given packages" do
      expect(subject).to receive(:DoInstallAndRemove).with(["yast2"], [])
      subject.DoInstall(["yast2"])
    end
  end

  describe "#DoRemove" do
    it "removes the given packages" do
      expect(subject).to receive(:DoInstallAndRemove).with([], ["ntpd"])
      subject.DoRemove(["ntpd"])
    end
  end

  context "when not running in config mode" do
    before do
      allow(Yast::Mode).to receive(:config).and_return(false)
    end

    it "delegates #Installed to PackageSystem" do
      expect(Yast::PackageSystem).to receive(:Installed)
      subject.Installed("yast2")
    end

    it "delegates #PackageInstalled to PackageSystem" do
      expect(Yast::PackageSystem).to receive(:PackageInstalled)
      subject.PackageInstalled("yast2")
    end

    it "delegates #Available to PackageSystem" do
      expect(Yast::PackageSystem).to receive(:Available)
      subject.Available("yast2")
    end

    it "delegates #PackageAvailable to PackageSystem" do
      expect(Yast::PackageSystem).to receive(:PackageAvailable)
      subject.PackageAvailable("yast2")
    end

    it "delegates #DoInstallAndRemove to PackageSystem" do
      expect(Yast::PackageSystem).to receive(:DoInstallAndRemove)
      subject.DoInstallAndRemove(["yast2"], ["ntpd"])
    end

    it "delegates #InstallKernel to PackageSystem" do
      expect(Yast::PackageSystem).to receive(:InstallKernel)
      subject.InstallKernel([])
    end
  end

  context "when running in config mode" do
    before do
      allow(Yast::Mode).to receive(:config).and_return(true)
    end

    it "delegates #Installed to PackageAI" do
      expect(Yast::PackageAI).to receive(:Installed)
      subject.Installed("yast2")
    end

    it "delegates #PackageInstalled to PackageAI" do
      expect(Yast::PackageAI).to receive(:PackageInstalled)
      subject.PackageInstalled("yast2")
    end

    it "delegates #Available to PackageAI" do
      expect(Yast::PackageAI).to receive(:Available)
      subject.Available("yast2")
    end

    it "delegates #PackageAvailable to PackageAI" do
      expect(Yast::PackageAI).to receive(:PackageAvailable)
      subject.PackageAvailable("yast2")
    end

    it "delegates #DoInstallAndRemove to PackageAI" do
      expect(Yast::PackageAI).to receive(:DoInstallAndRemove)
      subject.DoInstallAndRemove(["yast2"], ["ntpd"])
    end

    it "delegates #InstallKernel to PackageAI" do
      expect(Yast::PackageAI).to receive(:InstallKernel)
      subject.InstallKernel([])
    end
  end

  describe "#AvailableAll" do
    let(:available) { ["yast2", "autoyast2"] }

    before do
      allow(subject).to receive(:Available) do |pkg|
        available.include?(pkg)
      end
    end

    context "when the given packages are available" do
      it "returns true" do
        expect(subject.AvailableAll(["yast2", "autoyast2"])).to eq(true)
      end
    end

    context "when any of the given packages is not available" do
      it "returns false" do
        expect(subject.AvailableAll(["yast2", "unknown"])).to eq(false)
      end
    end
  end

  describe "#AvailableAny" do
    let(:available) { ["yast2", "autoyast2"] }

    before do
      allow(subject).to receive(:Available) do |pkg|
        available.include?(pkg)
      end
    end

    context "when any of the given packages is available" do
      it "returns true" do
        expect(subject.AvailableAny(["yast2", "unknown"])).to eq(true)
      end
    end

    context "when none of the given packages is available" do
      it "returns false" do
        expect(subject.AvailableAny(["unknown"])).to eq(false)
      end
    end
  end

  describe "#InstalledAll" do
    let(:installed) { ["yast2", "autoyast2"] }

    before do
      allow(subject).to receive(:Installed) do |pkg|
        installed.include?(pkg)
      end
    end

    context "when the given packages are installed" do
      it "returns true" do
        expect(subject.InstalledAll(["yast2", "autoyast2"])).to eq(true)
      end
    end

    context "when any of the given packages is not installed" do
      it "returns false" do
        expect(subject.InstalledAll(["yast2", "unknown"])).to eq(false)
      end
    end

    context "when the target is set" do
      it "asks for packages in the corresponding backend" do
        expect(subject).to receive(:Installed).with("yast2", target: :system)
        subject.InstalledAll(["yast2"], target: :system)
      end
    end
  end

  describe "#InstalledAny" do
    let(:installed) { ["yast2", "autoyast2"] }

    before do
      allow(subject).to receive(:Installed) do |pkg|
        installed.include?(pkg)
      end
    end

    context "when any of the given packages is installed" do
      it "returns true" do
        expect(subject.InstalledAny(["yast2", "unknown"])).to eq(true)
      end
    end

    context "when none of the given packages is installed" do
      it "returns false" do
        expect(subject.InstalledAny(["unknown"])).to eq(false)
      end
    end

    context "when the target is set" do
      it "asks for packages in the corresponding backend" do
        expect(subject).to receive(:Installed).with("yast2", target: :system)
        subject.InstalledAny(["yast2"], target: :system)
      end
    end
  end

  describe "#DoInstallAndRemove" do
    let(:backend) do
      double("backend", DoInstallAndRemove: result)
    end

    let(:result) { true }
    let(:toinstall) { ["yast2"] }
    let(:toremove) { ["dummy"] }

    before do
      allow(subject).to receive(:backend).and_return(backend)
      allow(subject).to receive(:InstalledAll).with(toinstall).and_return(true)
    end

    it "delegates in the backend" do
      expect(backend).to receive(:DoInstallAndRemove).with(toinstall, toremove)
      subject.DoInstallAndRemove(toinstall, toremove)
    end

    it "returns true on success" do
      expect(subject.DoInstallAndRemove(toinstall, toremove)).to eq(true)
    end

    context "when the installation fails" do
      let(:result) { false }

      it "returns false" do
        expect(subject.DoInstallAndRemove(toinstall, toremove)).to eq(false)
      end
    end

    context "when not all packages are installed" do
      before do
        allow(subject).to receive(:InstalledAll).with(toinstall).and_return(false)
      end

      it "returns false" do
        expect(subject.DoInstallAndRemove(toinstall, toremove)).to eq(false)
      end
    end
  end

  describe "#PackageDialog" do
    let(:installed_pkg) { "wicked" }
    let(:uninstalled_pkg) { "firewalld" }
    let(:packages) { [installed_pkg, uninstalled_pkg] }
    let(:commandline) { false }
    let(:interactive) { false }
    let(:confirm) { false }

    before do
      allow(subject).to receive(:Installed).with(installed_pkg).and_return(true)
      allow(subject).to receive(:Installed).with(uninstalled_pkg).and_return(false)
      allow(Yast::Mode).to receive(:commandline).and_return(commandline)
      allow(Yast::CommandLine).to receive(:Interactive).and_return(interactive)
      allow(Yast::Popup).to receive(:AnyQuestionRichText).and_return(confirm)
    end

    context "when installing packages" do
      let(:confirm) { false }

      it "displays a pop-up asking for confirmation" do
        expect(Yast::Popup).to receive(:AnyQuestionRichText).with(
          "", /to be installed:<p>#{uninstalled_pkg}/, Integer, Integer,
          Yast::Label.InstallButton, Yast::Label.CancelButton, :focus_yes
        )
        subject.PackageDialog(packages, true, nil)
      end

      context "and the user confirms" do
        let(:confirm) { true }
        let(:success) { true }

        before do
          allow(subject).to receive(:DoInstall).with([uninstalled_pkg]).and_return(success)
        end

        it "installs the packages" do
          expect(subject).to receive(:DoInstall).with([uninstalled_pkg])
          subject.PackageDialog(packages, true, nil)
        end

        context "and the packages are installed" do
          it "returns true" do
            expect(subject.PackageDialog(packages, true, nil)).to eq(true)
          end
        end

        context "and the packages could not be installed" do
          let(:success) { false }

          it "returns false" do
            expect(subject.PackageDialog(packages, true, nil)).to eq(false)
          end
        end
      end

      context "and the user cancels" do
        let(:confirm) { false }

        it "does not try to install the packages" do
          expect(subject).to_not receive(:DoInstall)
          subject.PackageDialog(packages, true, nil)
        end
      end
    end

    context "when removing packages" do
      let(:confirm) { false }

      context "and not running on command line mode" do
        it "displays a pop-up asking for confirmation" do
          expect(Yast::Popup).to receive(:AnyQuestionRichText).with(
            "", /to be removed:<p>#{installed_pkg}/, Integer, Integer,
            /Uninstall/, Yast::Label.CancelButton, :focus_yes
          )
          subject.PackageDialog(packages, false, nil)
        end
      end

      context "and running on interactive command line mode" do
        let(:interactive) { true }
        let(:commandline) { true }

        it "displays a message asking for confirmation" do
          expect(Yast::CommandLine).to receive(:Print).with(/to be removed: #{installed_pkg}/)
          expect(Yast::CommandLine).to receive(:YesNo).and_return(false)
          subject.PackageDialog(packages, false, nil)
        end
      end

      context "and the user confirms" do
        let(:confirm) { true }
        let(:success) { true }

        before do
          allow(subject).to receive(:DoRemove).with([installed_pkg]).and_return(success)
        end

        it "removes the packages" do
          expect(subject).to receive(:DoRemove).with([installed_pkg])
          subject.PackageDialog(packages, false, nil)
        end

        context "and the packages are removed" do
          it "returns true" do
            expect(subject.PackageDialog(packages, false, nil)).to eq(true)
          end

        end

        context "and the packages could not be removed" do
          let(:success) { false }

          it "returns false" do
            expect(subject.PackageDialog(packages, false, nil)).to eq(false)
          end
        end
      end

      context "and the user cancels" do
        let(:confirm) { false }

        it "does not try to remove the packages" do
          expect(subject).to_not receive(:DoRemove)
          subject.PackageDialog(packages, false, nil)
        end
      end
    end

    context "when a custom message is given" do
      it "displays the given message" do
        expect(Yast::Popup).to receive(:AnyQuestionRichText).with(
          "", "Should I install random packages?", any_args
        )
        subject.PackageDialog(packages, true, "Should I install random packages?")
      end
    end
  end

  describe "#Installed" do
    context "when the target is set to :system" do
      it "delegates to the PackageSystem module" do
        expect(Yast::PackageSystem).to receive(:Installed).with("firewalld")
        subject.Installed("firewalld", target: :system)
      end
    end

    context "when the target is set to :system" do
      it "delegates to the PackageAI module" do
        expect(Yast::PackageAI).to receive(:Installed).with("firewalld")
        subject.Installed("firewalld", target: :autoinst)
      end
    end
  end

  describe "#PackageInstalled" do
    context "when the target is set to :system" do
      it "delegates to the PackageSystem module" do
        expect(Yast::PackageSystem).to receive(:PackageInstalled).with("firewalld")
        subject.PackageInstalled("firewalld", target: :system)
      end
    end

    context "when the target is set to :system" do
      it "delegates to the PackageAI module" do
        expect(Yast::PackageAI).to receive(:PackageInstalled).with("firewalld")
        subject.PackageInstalled("firewalld", target: :autoinst)
      end
    end
  end

  describe "#InstallMsg" do
    it "asks to install a single package using a custom message" do
      expect(subject).to receive(:PackageDialog).with(["firewalld"], true, "Install?")
      subject.InstallMsg("firewalld", "Install?")
    end
  end

  describe "#Install" do
    it "asks to install a single package using the default message" do
      expect(subject).to receive(:PackageDialog).with(["firewalld"], true, nil)
      subject.Install("firewalld")
    end
  end

  describe "#InstallAllMsg" do
    it "asks to install a set of package using a custom message" do
      expect(subject).to receive(:PackageDialog).with(["firewalld", "yast2"], true, "Install?")
      subject.InstallAllMsg(["firewalld", "yast2"], "Install?")
    end
  end

  describe "#RemoveMsg" do
    it "asks to install a single package using a custom message" do
      expect(subject).to receive(:PackageDialog).with(["firewalld"], false, "Remove?")
      subject.RemoveMsg("firewalld", "Remove?")
    end
  end

  describe "#Remove" do
    it "asks to install a single package using the default message" do
      expect(subject).to receive(:PackageDialog).with(["firewalld"], false, nil)
      subject.Remove("firewalld")
    end
  end

  describe "#RemoveAllMsg" do
    it "asks to install a set of package using a custom message" do
      expect(subject).to receive(:PackageDialog).with(["firewalld", "yast2"], false, "Remove?")
      subject.RemoveAllMsg(["firewalld", "yast2"], "Remove?")
    end
  end

  describe "#IsTransactionalSystem" do
    before do
      # reset cache
      subject.instance_variable_set(:@transactional, nil)
    end

    it "returns false if system is not transactional" do
      allow(Yast::SCR).to receive(:Read).and_return(
        [{
          "file"    => "/",
          "freq"    => 0,
          "mntops"  => "rw,relatime",
          "passno"  => 0,
          "spec"    => "/dev/nvme0n1p2",
          "vfstype" => "ext4"
        }]
      )

      expect(subject.IsTransactionalSystem).to eq false
    end

    it "returns true if system is transactional" do
      allow(Yast::SCR).to receive(:Read).and_return(
        [{
          "file"    => "/",
          "freq"    => 0,
          "mntops"  => "ro,seclabel,relatime,subvolid=244,subvol=/@/.snapshots/8/snapshot",
          "passno"  => 0,
          "spec"    => "/dev/vda3",
          "vfstype" => "ext4"
        }]
      )

      expect(subject.IsTransactionalSystem).to eq true
    end
  end
end
