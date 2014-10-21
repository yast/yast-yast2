#!/usr/bin/env rspec

top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"

Yast.import "SuSEFirewallServices"
Yast.import "SCR"

# Path to a test data - service file - mocking the default data path
SERVICES_DATA_PATH = File.join(
  File.expand_path(File.dirname(__FILE__)),
  "data",
  Yast::SuSEFirewallServicesClass::SERVICES_DIR
)

# Adjusts SuSEFirewallServices to read data from test-directory
def setup_data_dir
  stub_const("Yast::SuSEFirewallServicesClass::SERVICES_DIR", SERVICES_DATA_PATH)
end

describe Yast::SuSEFirewallServices do
  describe "#ServiceDefinedByPackage" do
    it "distinguishes whether service is defined by package" do
      expect(Yast::SuSEFirewallServices.ServiceDefinedByPackage("service:dns-server")).to be_true
      expect(Yast::SuSEFirewallServices.ServiceDefinedByPackage("dns-server")).to be_false
    end
  end

  describe "#GetFilenameFromServiceDefinedByPackage" do
    it "returns a file name (service name) taken from the service name if service is defined by package" do
      expect(Yast::SuSEFirewallServices.GetFilenameFromServiceDefinedByPackage("service:dns-server")).to eq "dns-server"
    end

    it "returns nil if service is not defined by package" do
      expect(Yast::SuSEFirewallServices.GetFilenameFromServiceDefinedByPackage("dns-server")).to be_nil
    end
  end

  describe "#GetMetadataAgent" do
    it "returns non-empty agent definition" do
      expect(Yast::SuSEFirewallServices.GetMetadataAgent("dns-server")).not_to be_nil
    end
  end

  describe "#service_details" do
    it "returns non-empty service definition" do
      Yast::SuSEFirewallServices.stub(:all_services).and_return({
        "service:dns-server"  => Yast::SuSEFirewallServicesClass::DEFAULT_SERVICE.merge({"tcp_ports" => ["a", "b"]}),
        "service:dhcp-server" => Yast::SuSEFirewallServicesClass::DEFAULT_SERVICE.merge({"udp_ports" => ["x", "y"]}),
      })
      expect(Yast::SuSEFirewallServices.service_details("service:dns-server")).not_to be_nil
      expect(Yast::SuSEFirewallServices.service_details("service:dns-server")["tcp_ports"]).to eq(["a", "b"])
    end

    it "throws an exception SuSEFirewalServiceNotFound if service does not exist" do
      Yast::SuSEFirewallServices.stub(:all_services).and_return({})
      expect { Yast::SuSEFirewallServices.service_details("undefined_service") }.to raise_error(
        Yast::SuSEFirewalServiceNotFound, /undefined_service/
      )
    end
  end

  describe "#all_services" do
    it "reads all services from disk and returns them" do
      setup_data_dir

      # Listing services directly from test-dir
      services_on_disk = Dir.entries(SERVICES_DATA_PATH).reject{
        |s| Yast::SuSEFirewallServicesClass::IGNORED_SERVICES.include?(s)
      }
      services_on_disk.map!{
        |s| Yast::SuSEFirewallServicesClass::DEFINED_BY_PKG_PREFIX + s
      }

      services = Yast::SuSEFirewallServices.all_services
      expect(services.keys.sort).to eq(services_on_disk.sort)
      # Just to make sure nobody removes service files without changing the test-case
      expect(services.size).to be >= 7
    end
  end

  describe "#IsKnownService" do
    it "returns whether service exists" do
      setup_data_dir

      expect(Yast::SuSEFirewallServices.IsKnownService("service:bind")).to be_true
      expect(Yast::SuSEFirewallServices.IsKnownService("service:no-bind")).to be_false
    end

    it "does not throw an exception if service does not exist" do
      expect {
        expect(Yast::SuSEFirewallServices.IsKnownService("unknown-service"))
      }.not_to raise_error
    end
  end

  describe "#GetListOfServicesAddedByPackage" do
    it "return list of known services" do
      expect(Yast::SuSEFirewallServices.GetListOfServicesAddedByPackage.size).to be >= 7
    end
  end

  context "while getting detailed info about a particular service" do
    before(:each) do
      setup_data_dir
    end

    describe "#GetNeededTCPPorts" do
      it "returns list of TCP ports required by a service" do
        expect(Yast::SuSEFirewallServices.GetNeededTCPPorts("service:special-service")).to eq(["port_1", "port_44", "port_2"])
      end
    end

    describe "#GetNeededUDPPorts" do
      it "returns list of UDP ports required by a service" do
        expect(Yast::SuSEFirewallServices.GetNeededUDPPorts("service:special-service")).to eq(["zzz", "bbb", "aaa"])
      end
    end

    describe "#GetNeededRPCPorts" do
      it "returns list of RPC ports required by a service" do
        expect(Yast::SuSEFirewallServices.GetNeededRPCPorts("service:special-service")).to eq([])
      end
    end

    describe "#GetNeededIPProtocols" do
      it "returns list of IP protocols required by a service" do
        expect(Yast::SuSEFirewallServices.GetNeededIPProtocols("service:special-service")).to eq(["ICMP", "HMP", "DDP", "RSVP"])
      end
    end

    describe "#GetDescription" do
      it "returns service description" do
        expect(Yast::SuSEFirewallServices.GetDescription("service:special-service")).to include("parsed")
      end
    end

    describe "#GetNeededBroadcastPorts" do
      it "returns list of broadcast ports required by a service" do
        expect(Yast::SuSEFirewallServices.GetNeededBroadcastPorts("service:special-service")).to eq(["port_x", "port_z"])
      end
    end

    describe "#GetNeededPortsAndProtocols" do
      it "returns hash of ports and protocols required by a service" do
        service_details = Yast::SuSEFirewallServices.GetNeededPortsAndProtocols("service:special-service")

        expect(service_details.is_a?(Hash)).to be_true

        expect(service_details["tcp_ports"]).not_to       be_empty
        expect(service_details["udp_ports"]).not_to       be_empty
        expect(service_details["ip_protocols"]).not_to    be_empty
        expect(service_details["broadcast_ports"]).not_to be_empty

        expect(service_details["rpc_ports"]).to be_empty
      end
    end
  end

  describe "#SetNeededPortsAndProtocols" do
    it "sets and writes new settings to a service definition file" do
      setup_data_dir
      Yast::SCR.stub(:Write).and_return true

      new_set_of_ports = ["new", "set", "of", "ports"]

      service_definition = Yast::SuSEFirewallServices.GetNeededPortsAndProtocols("service:special-service")
      expect(service_definition["tcp_ports"]).not_to eq(new_set_of_ports)
      service_definition["tcp_ports"] = new_set_of_ports

      expect(Yast::SuSEFirewallServices.SetNeededPortsAndProtocols("service:special-service", service_definition)).to be_true
      expect(Yast::SuSEFirewallServices.GetNeededPortsAndProtocols("service:special-service")).to eq(service_definition)
    end
  end

  context "while adjusting and checking the Modified flag" do
    before(:each) do
      Yast::SuSEFirewallServices.ResetModified
    end

    describe "#GetModified" do
      it "returns the default Modified flag" do
        expect(Yast::SuSEFirewallServices.GetModified()).to be_false
      end
    end

    describe "#SetModified" do
      it "sets the Modified flag" do
        Yast::SuSEFirewallServices.SetModified
        expect(Yast::SuSEFirewallServices.GetModified()).to be_true
      end
    end

    describe "#ResetModified" do
      it "resets the Modified flag to default" do
        Yast::SuSEFirewallServices.SetModified
        Yast::SuSEFirewallServices.ResetModified
        expect(Yast::SuSEFirewallServices.GetModified()).to be_false
      end
    end
  end

  describe "#OLD_SERVICES" do
    it "returns hash of old services definitions for conversion" do
      old_services = Yast::SuSEFirewallServices.OLD_SERVICES
      expect(old_services.size).to be >= 1
      expect(old_services.is_a?(Hash)).to be_true
    end
  end

end
