#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Mode"
Yast.import "PackageSystem"
Yast.import "Pkg"
Yast.import "SuSEFirewall"
Yast.import "Stage"

def reset_SuSEFirewallIsInstalled_cache
  Yast::SuSEFirewall.needed_packages_installed = nil
end

describe Yast::SuSEFirewall do
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
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(true)
        # Not selected and not installed
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(false)
        # Not selected, but installed
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(true)
      end
    end

    context "while on a running system (normal configuration)" do
      it "returns whether SuSEfirewall2 was or could have been installed" do
        expect(Yast::Stage).to receive(:stage).and_return("normal").at_least(:once)
        expect(Yast::Mode).to receive(:mode).and_return("normal").at_least(:once)

        # Value is cached
        expect(Yast::PackageSystem).to receive(:CheckAndInstallPackages).and_return(true, false).twice

        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(true)
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(true)
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(true)

        reset_SuSEFirewallIsInstalled_cache

        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(false)
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(false)
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(false)
      end
    end

    context "while in AutoYast config" do
      it "returns whether SuSEfirewall2 is installed" do
        expect(Yast::Stage).to receive(:stage).and_return("normal").at_least(:once)
        expect(Yast::Mode).to receive(:mode).and_return("autoinst_config").at_least(:once)

        # Value is cached
        expect(Yast::PackageSystem).to receive(:Installed).and_return(false, true).twice

        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(false)
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(false)
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(false)

        reset_SuSEFirewallIsInstalled_cache

        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(true)
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(true)
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to eq(true)
      end
    end
  end

  describe "#full_init_on_boot" do
    it "sets whether SuSEfirewall2_init should do the full init on boot and returns the current state" do
      expect(Yast::SuSEFirewall.full_init_on_boot(true)).to eq(true)
      expect(Yast::SuSEFirewall.GetModified()).to eq(true)
      expect(Yast::SuSEFirewall.full_init_on_boot(false)).to eq(false)
      expect(Yast::SuSEFirewall.GetModified()).to eq(true)
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
    before { subject.main }

    let(:package_installed) { true }
    let(:config_exists) { true }

    before do
      allow(Yast::FileUtils).to receive(:Exists)
        .with(Yast::SuSEFirewallClass::CONFIG_FILE)
        .and_return(package_installed)
      allow(subject).to receive(:SuSEFirewallIsInstalled)
        .and_return(config_exists)
    end

    context "when configuration does not exist" do
      let(:config_exists) { false }

      it "empties firewall config and returns false" do
        expect(subject.Read).to eql(false)
        expect(subject.GetStartService).to eq(false)
        expect(subject.GetEnableService).to eq(false)
      end
    end

    context "when the package is not installed" do
      let(:package_installed) { false }

      it "empties firewall config and returns false" do
        expect(subject.Read).to eql(false)
        expect(subject.GetStartService).to eq(false)
        expect(subject.GetEnableService).to eq(false)
      end
    end

    context "when packages and config file are available" do
      before do
        allow(subject).to receive(:ConvertToServicesDefinedByPackages)
        allow(Yast::NetworkInterfaces).to receive(:Read)
      end

      around do |example|
        old_mode = Yast::Mode.mode
        Yast::Mode.SetMode(mode)
        example.run
        Yast::Mode.SetMode(old_mode)
      end

      context "during autoinstallation mode" do
        let(:mode) { "autoinstallation" }

        it "reads the default configuration" do
          expect(subject).to receive(:ReadDefaultConfiguration)
          expect(subject.Read).to eql(true)
        end
      end

      context "during normal mode" do
        let(:mode) { "normal" }

        it "reads the default configuration" do
          expect(subject).to receive(:ReadCurrentConfiguration)
          expect(subject.Read).to eql(true)
        end
      end

      context "during installation mode" do
        let(:mode) { "installation" }

        it "reads the default configuration" do
          expect(subject).to receive(:ReadCurrentConfiguration)
          expect(subject.Read).to eql(true)
        end
      end

    end
  end
end
