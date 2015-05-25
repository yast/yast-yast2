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
    it "proposes full firewall initialization on boot" do
      expect(Yast::SuSEFirewall).to receive(:full_init_on_boot).and_return(true)

      Yast::SuSEFirewallProposal.propose_iscsi
    end
  end

  describe "#EnableFallbackPorts" do
    before(:each) do
      allow(Yast::SuSEFirewall).to receive(:GetKnownFirewallZones).and_return(["EXT", "INT", "DMZ"])
    end

    context "when opening ports in known firewall zones" do
      it "opens given ports in firewall in given zones" do
        expect(Yast::SuSEFirewall).to receive(:AddService).with(/port.*/, "TCP", /(EXT|DMZ)/).exactly(4).times

        Yast::SuSEFirewallProposal.EnableFallbackPorts(["port1","port2"], ["EXT", "DMZ"])
      end
    end

    context "when opening ports in unknown firewall zones" do
      it "throws an exception" do
        expect {
          Yast::SuSEFirewallProposal.EnableFallbackPorts(["port1","port2"], ["UNKNOWN_ZONE1", "UZ2"])
        }.to raise_error(/UNKNOWN_ZONE1.*UZ2/)
      end
    end
  end

  describe "#OpenServiceInInterfaces" do
    let(:network_interfaces) { ["eth-x", "eth-y"] }
    let(:interfaces_zones) { ["ZONE1", "ZONE2"] }
    let(:all_zones) { ["ZONE1", "ZONE2", "ZONE3"] }
    let(:firewall_service) { "service:fw_service_x" }
    let(:fallback_ports) { ["p1", "p2", "p3"] }

    before(:each) do
      # Default behavior: Interfaces are assigned to zones, there are more known zones,
      # given firewall service exists
      allow(Yast::SuSEFirewall).to receive(:GetZonesOfInterfaces).and_return(interfaces_zones)
      allow(Yast::SuSEFirewall).to receive(:GetKnownFirewallZones).and_return(all_zones)
      allow(Yast::SuSEFirewallServices).to receive(:IsKnownService).and_return(true)
    end

    context "when network interfaces are assigned to some zone(s)" do
      it "open service in firewall in zones that include given interfaces" do
        expect(Yast::SuSEFirewall).to receive(:SetServicesForZones).with([firewall_service], interfaces_zones, true)
        Yast::SuSEFirewallProposal.OpenServiceInInterfaces(firewall_service, fallback_ports, network_interfaces)
      end
    end

    context "when network interfaces are not assigned to any zone" do
      it "opens service in firewall in all zones" do
        allow(Yast::SuSEFirewall).to receive(:GetZonesOfInterfaces).and_return([])
        expect(Yast::SuSEFirewall).to receive(:SetServicesForZones).with([firewall_service], all_zones, true)
        Yast::SuSEFirewallProposal.OpenServiceInInterfaces(firewall_service, fallback_ports, network_interfaces)
      end
    end

    context "when given firewall service is known" do
      it "opens service in firewall in zones that include given interfaces" do
        expect(Yast::SuSEFirewall).to receive(:SetServicesForZones).with([firewall_service], interfaces_zones, true)
        Yast::SuSEFirewallProposal.OpenServiceInInterfaces(firewall_service, fallback_ports, network_interfaces)
      end
    end

    context "when given service is unknown" do
      it "opens given fallback ports in zones that include given interfaces" do
        allow(Yast::SuSEFirewallServices).to receive(:IsKnownService).and_return(false)
        expect(Yast::SuSEFirewallProposal).to receive(:EnableFallbackPorts).with(fallback_ports, interfaces_zones)
        Yast::SuSEFirewallProposal.OpenServiceInInterfaces(firewall_service, fallback_ports, network_interfaces)
      end
    end
  end
end
