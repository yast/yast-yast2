#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "SuSEFirewall"
Yast.import "SuSEFirewallServices"
Yast.import "SuSEFirewallProposal"
Yast.import "Linuxrc"

describe Yast::SuSEFirewallProposal do
  describe "#ProposeFunctions" do
    context "when iscsi is used" do
      it "calls the iscsi proposal" do
        allow(Yast::Linuxrc).to receive(:useiscsi).and_return(true)
        expect(Yast::SuSEFirewallProposal).to receive(:propose_iscsi).and_return(nil)

        Yast::SuSEFirewallProposal.ProposeFunctions
      end
    end

    context "when iscsi is not used" do
      it "does not call the iscsi proposal" do
        allow(Yast::Linuxrc).to receive(:useiscsi).and_return(false)
        expect(Yast::SuSEFirewallProposal).not_to receive(:propose_iscsi)

        Yast::SuSEFirewallProposal.ProposeFunctions
      end
    end
  end

  describe "#propose_iscsi" do
    before(:each) do
      allow(Yast::SuSEFirewall).to receive(:GetAllNonDialUpInterfaces).and_return(["eth44", "eth55"])
      allow(Yast::SuSEFirewall).to receive(:GetZonesOfInterfaces).and_return(["EXT"])
      allow(Yast::SuSEFirewallServices).to receive(:IsKnownService).and_return(true)
      allow(Yast::SuSEFirewallProposal).to receive(:ServiceEnabled).and_return(true)
    end

    it "proposes opening iscsi-target firewall service and full firewall initialization on boot" do
      expect(Yast::SuSEFirewall).to receive(:full_init_on_boot).and_return(true)
      expect(Yast::SuSEFirewall).to receive(:SetServicesForZones).with(["service:iscsitarget"], ["EXT"], true).and_return(true)

      Yast::SuSEFirewallProposal.propose_iscsi
    end
  end
end
