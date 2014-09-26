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

FW_PACKAGE = "SuSEfirewall2"

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
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_true
        # Not selected and not installed
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_false
        # Not selected, but installed
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_true
      end
    end

    context "while on a running system (normal configuration)" do
      it "returns whether SuSEfirewall2 was or could have been installed" do
        expect(Yast::Stage).to receive(:stage).and_return("normal").at_least(:once)
        expect(Yast::Mode).to receive(:mode).and_return("normal").at_least(:once)

        # Value is cached
        expect(Yast::PackageSystem).to receive(:CheckAndInstallPackages).and_return(true, false).twice

        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_true
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_true
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_true

        reset_SuSEFirewallIsInstalled_cache

        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_false
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_false
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_false
      end
    end

    context "while in AutoYast config" do
      it "returns whether SuSEfirewall2 is installed" do
        expect(Yast::Stage).to receive(:stage).and_return("normal").at_least(:once)
        expect(Yast::Mode).to receive(:mode).and_return("autoinst_config").at_least(:once)

        # Value is cached
        expect(Yast::PackageSystem).to receive(:Installed).and_return(false, true).twice

        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_false
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_false
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_false

        reset_SuSEFirewallIsInstalled_cache

        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_true
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_true
        expect(Yast::SuSEFirewall.SuSEFirewallIsInstalled).to be_true
      end
    end
  end
end
