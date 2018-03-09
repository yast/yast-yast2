#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "SuSEFirewall"
Yast.import "SuSEFirewallServices"
Yast.import "SuSEFirewallProposal"
Yast.import "Linuxrc"

describe Yast::SuSEFirewallProposal do
  subject { Yast::SuSEFirewallProposal }

  describe "#EnableFallbackPorts" do
    let(:fallback_ports) { ["port1", "port2"] }

    before(:each) do
      allow(Yast::SuSEFirewall).to receive(:GetKnownFirewallZones).and_return(["EXT", "INT", "DMZ"])
    end

    context "when opening ports in known firewall zones" do
      it "opens given ports in firewall in given zones" do
        expect(Yast::SuSEFirewall).to receive(:AddService).with(/port.*/, "TCP", /(EXT|DMZ)/).exactly(4).times

        subject.EnableFallbackPorts(fallback_ports, ["EXT", "DMZ"])
      end
    end

    context "when opening ports in unknown firewall zones" do
      it "throws an exception" do
        method_call = proc { subject.EnableFallbackPorts(fallback_ports, ["UNKNOWN_ZONE1", "UZ2"]) }
        expect { method_call.call }.to raise_error(/UNKNOWN_ZONE1.*UZ2/)
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
        subject.OpenServiceInInterfaces(firewall_service, fallback_ports, network_interfaces)
      end
    end

    context "when network interfaces are not assigned to any zone" do
      it "opens service in firewall in all zones" do
        allow(Yast::SuSEFirewall).to receive(:GetZonesOfInterfaces).and_return([])
        expect(Yast::SuSEFirewall).to receive(:SetServicesForZones).with([firewall_service], all_zones, true)
        subject.OpenServiceInInterfaces(firewall_service, fallback_ports, network_interfaces)
      end
    end

    context "when given firewall service is known" do
      it "opens service in firewall in zones that include given interfaces" do
        expect(Yast::SuSEFirewall).to receive(:SetServicesForZones).with([firewall_service], interfaces_zones, true)
        subject.OpenServiceInInterfaces(firewall_service, fallback_ports, network_interfaces)
      end
    end

    context "when given service is unknown" do
      it "opens given fallback ports in zones that include given interfaces" do
        allow(Yast::SuSEFirewallServices).to receive(:IsKnownService).and_return(false)
        expect(subject).to receive(:EnableFallbackPorts).with(fallback_ports, interfaces_zones)
        subject.OpenServiceInInterfaces(firewall_service, fallback_ports, network_interfaces)
      end
    end
  end
end
