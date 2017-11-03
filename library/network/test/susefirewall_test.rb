#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Mode"
Yast.import "PackageSystem"
Yast.import "Pkg"
Yast.import "SuSEFirewall"
Yast.import "Stage"

def reset_SuSEFirewallIsInstalled_cache
  FakeFirewall.needed_packages_installed = nil
end

# Instantiate an Firewalld object
FakeFirewall = Yast::SuSEFirewalldClass.new

describe FakeFirewall do

  describe "#SuSEFirewallIsSelectedOrInstalled" do
    context "while in inst-sys" do
      it "returns whether SuSEfirewalld is selected for installation or already installed" do
        expect(Yast::Stage).to receive(:stage).and_return("initial").at_least(:once)

        # Value is not cached
        expect(Yast::Pkg).to receive(:IsSelected).and_return(true, false, false).exactly(3).times
        # Fallback: if not selected, checks whether the package is installed
        expect(subject).to receive(:SuSEFirewallIsInstalled).and_return(false, true).twice

        # Selected
        expect(subject.SuSEFirewallIsSelectedOrInstalled).to eq(true)
        # Not selected and not installed
        expect(subject.SuSEFirewallIsSelectedOrInstalled).to eq(false)
        # Not selected, but installed
        expect(subject.SuSEFirewallIsSelectedOrInstalled).to eq(true)
      end
    end

    context "while on a running system or AutoYast config" do
      it "returns whether SuSEfirewalld was or could have been installed" do
        expect(Yast::Stage).to receive(:stage).and_return("normal").twice

        expect(subject).to receive(:SuSEFirewallIsInstalled).and_return(false, true).twice

        expect(subject.SuSEFirewallIsSelectedOrInstalled).to eq(false)
        expect(subject.SuSEFirewallIsSelectedOrInstalled).to eq(true)
      end
    end
  end

  describe "#SuSEFirewallIsInstalled" do
    before(:each) do
      reset_SuSEFirewallIsInstalled_cache
    end

    context "while in inst-sys" do
      it "returns whether SuSEfirewalld is installed or not" do
        expect(Yast::Mode).to receive(:mode).and_return("installation").twice

        # Checks whether the package is installed
        expect(Yast::PackageSystem).to receive(:Installed).and_return(false, true).twice

        expect(subject.SuSEFirewallIsInstalled).to eq(false)
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
        # Value is cached if true
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
      end
    end

    context "while on a running system (normal configuration)" do
      it "returns whether SuSEfirewalld was or could have been installed" do
        expect(Yast::Mode).to receive(:mode).and_return("normal").at_least(:once)

        # Value is cached
        expect(Yast::PackageSystem).to receive(:CheckAndInstallPackages).and_return(true, false).twice

        expect(subject.SuSEFirewallIsInstalled).to eq(true)
        # Value is cached if true
        expect(subject.SuSEFirewallIsInstalled).to eq(true)

        reset_SuSEFirewallIsInstalled_cache

        expect(subject.SuSEFirewallIsInstalled).to eq(false)
      end
    end

    context "while in AutoYast config" do
      it "returns whether SuSEfirewalld is installed" do
        expect(Yast::Mode).to receive(:mode).and_return("autoinst_config").at_least(:once)

        expect(Yast::PackageSystem).to receive(:Installed).and_return(false, true).twice

        expect(subject.SuSEFirewallIsInstalled).to eq(false)
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
        # Value is cached if true
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
      end
    end
  end

  describe "#Read" do
    before do
      allow(subject).to receive(:SuSEFirewallIsInstalled)
        .and_return(package_installed)
    end

    let(:package_installed) { true }
    let(:config_exists) { true }

    context "when package and config file are available" do
      it "reads current configuration" do
        expect(subject).to receive(:ReadCurrentConfiguration)
        expect(Yast::NetworkInterfaces).to receive(:Read)
        expect(subject.Read).to eq(true)
      end
    end

    context "when configuration was already read" do
      before do
        allow(Yast::NetworkInterfaces).to receive(:Read)
        subject.Read
      end

      it "does not read it again" do
        expect(Yast::NetworkInterfaces).to_not receive(:Read)
        subject.Read
      end
    end
  end

  describe "#Import" do
    it "imports given settings" do
      subject.Import("start_firewall" => true, "enable_firewall" => false)
      expect(subject.GetStartService).to eq(true)
      expect(subject.GetEnableService).to eq(false)
    end

    context "given a configuration" do
      before do
        subject.Import("start_firewall" => true, "enable_firewall" => false)
      end

      context "when a setting is not given" do
        it "leaves that setting untouched" do
          subject.Import("enable_firewall" => true)
          expect(subject.GetStartService).to eq(true) # Untouched setting
          expect(subject.GetEnableService).to eq(true)
        end
      end

      context "when nil is passed" do
        it "leaves settings untouched" do
          subject.Import(nil)
          expect(subject.GetStartService).to eq(true)
          expect(subject.GetEnableService).to eq(false)
        end
      end

      context "when an empty hash is passed" do
        it "leaves settings untouched" do
          subject.Import({})
          expect(subject.GetStartService).to eq(true)
          expect(subject.GetEnableService).to eq(false)
        end
      end
    end
  end
end
