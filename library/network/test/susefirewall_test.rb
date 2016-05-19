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

# Instantiate an SF2 object
FakeFirewall = Yast::FirewallClass.create(:sf2)
FakeFirewall.main

describe FakeFirewall do

  describe "#SuSEFirewallIsInstalled" do
    before(:each) do
      reset_SuSEFirewallIsInstalled_cache
    end

    context "while in inst-sys" do
      it "returns whether SuSEfirewall2 is selected for installation or already installed" do
        expect(Yast::Stage).to receive(:stage).and_return("initial").at_least(:once)

        # Value is not cached
        expect(Yast::Pkg).to receive(:IsSelected).and_return(true, false, false).exactly(3).times
        # Fallback: if not selected, checks whether the package is installed
        expect(Yast::PackageSystem).to receive(:Installed).and_return(false, true).twice

        # Selected
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
        # Not selected and not installed
        expect(subject.SuSEFirewallIsInstalled).to eq(false)
        # Not selected, but installed
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
      end
    end

    context "while on a running system (normal configuration)" do
      it "returns whether SuSEfirewall2 was or could have been installed" do
        expect(Yast::Stage).to receive(:stage).and_return("normal").at_least(:once)
        expect(Yast::Mode).to receive(:mode).and_return("normal").at_least(:once)

        # Value is cached
        expect(Yast::PackageSystem).to receive(:CheckAndInstallPackages).and_return(true, false).twice

        expect(subject.SuSEFirewallIsInstalled).to eq(true)
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
        expect(subject.SuSEFirewallIsInstalled).to eq(true)

        reset_SuSEFirewallIsInstalled_cache

        expect(subject.SuSEFirewallIsInstalled).to eq(false)
        expect(subject.SuSEFirewallIsInstalled).to eq(false)
        expect(subject.SuSEFirewallIsInstalled).to eq(false)
      end
    end

    context "while in AutoYast config" do
      it "returns whether SuSEfirewall2 is installed" do
        expect(Yast::Stage).to receive(:stage).and_return("normal").at_least(:once)
        expect(Yast::Mode).to receive(:mode).and_return("autoinst_config").at_least(:once)

        # Value is cached
        expect(Yast::PackageSystem).to receive(:Installed).and_return(false, true).twice

        expect(subject.SuSEFirewallIsInstalled).to eq(false)
        expect(subject.SuSEFirewallIsInstalled).to eq(false)
        expect(subject.SuSEFirewallIsInstalled).to eq(false)

        reset_SuSEFirewallIsInstalled_cache

        expect(subject.SuSEFirewallIsInstalled).to eq(true)
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
        expect(subject.SuSEFirewallIsInstalled).to eq(true)
      end
    end
  end

  describe "#full_init_on_boot" do
    it "sets whether SuSEfirewall2_init should do the full init on boot and returns the current state" do
      expect(subject.full_init_on_boot(true)).to eq(true)
      expect(subject.GetModified()).to eq(true)
      expect(subject.full_init_on_boot(false)).to eq(false)
      expect(subject.GetModified()).to eq(true)
    end
  end

  describe "#SetSupportRoute" do
    context "when enabling routing" do
      it "sets FW_ROUTE and FW_STOP_KEEP_ROUTING_STATE to 'yes'" do
        subject.SetSupportRoute(true)
        settings = subject.Export
        expect(settings["FW_ROUTE"]).to eq("yes")
        expect(settings["FW_STOP_KEEP_ROUTING_STATE"]).to eq("yes")
      end
    end

    context "when disabling routing" do
      it "sets FW_ROUTE and FW_STOP_KEEP_ROUTING_STATE to 'no'" do
        subject.SetSupportRoute(false)
        settings = subject.Export
        expect(settings["FW_ROUTE"]).to eq("no")
        expect(settings["FW_STOP_KEEP_ROUTING_STATE"]).to eq("no")
      end
    end
  end

  describe "#Read" do
    before do
      subject.main # Resets module configuration

      allow(Yast::FileUtils).to receive(:Exists)
        .with(Yast::SuSEFirewall2Class::CONFIG_FILE)
        .and_return(package_installed)
      allow(subject).to receive(:SuSEFirewallIsInstalled)
        .and_return(config_exists)
    end

    let(:package_installed) { true }
    let(:config_exists) { true }

    context "when package and config file are available" do
      it "reads current configuration" do
        expect(subject).to receive(:ConvertToServicesDefinedByPackages)
        expect(Yast::NetworkInterfaces).to receive(:Read)
        expect(subject).to receive(:ReadCurrentConfiguration)
        expect(subject.Read).to eq(true)
      end
    end

    context "when configuration does not exist" do
      let(:config_exists) { false }

      it "empties firewall config and returns false" do
        expect(subject.Read).to eq(false)
        expect(subject.GetStartService).to eq(false)
        expect(subject.GetEnableService).to eq(false)
      end
    end

    context "when the package is not installed" do
      let(:package_installed) { false }

      it "empties firewall config and returns false" do
        expect(subject.Read).to eq(false)
        expect(subject.GetStartService).to eq(false)
        expect(subject.GetEnableService).to eq(false)
      end
    end

    context "when configuration was already read" do
      before do
        allow(subject).to receive(:ConvertToServicesDefinedByPackages)
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
    before { subject.main }

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
