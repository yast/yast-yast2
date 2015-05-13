#!/usr/bin/env rspec

top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"

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
end
