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
end
