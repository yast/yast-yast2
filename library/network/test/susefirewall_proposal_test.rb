#!/usr/bin/env rspec

top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"

Yast.import "SuSEFirewall"
Yast.import "SuSEFirewallServices"
Yast.import "SuSEFirewallProposal"
Yast.import "Linuxrc"

describe Yast::SuSEFirewallProposal do
  describe "#ProposeFunctions" do
    before(:each) do
      allow(Yast::SuSEFirewall).to receive(:GetAllNonDialUpInterfaces).and_return(["eth44", "eth55"])
      allow(Yast::SuSEFirewall).to receive(:GetZonesOfInterfaces).and_return(["EXT"])
      allow(Yast::SuSEFirewallServices).to receive(:IsKnownService).and_return(true)
      allow(Yast::SuSEFirewallProposal).to receive(:ServiceEnabled).and_return(true)
    end

    context "when iscsi is used" do
      it "proposes opening iscsi-target firewall service and full firewall initialization on boot" do
        allow(Yast::Linuxrc).to receive(:useiscsi).and_return("initial")

        expect(Yast::SuSEFirewall).to receive(:full_init_on_boot).and_return(true)
        expect(Yast::SuSEFirewall).to receive(:SetServicesForZones).with(["service:iscsitarget"], ["EXT"], true).and_return(true)

        Yast::SuSEFirewallProposal.ProposeFunctions
      end
    end
  end
end
