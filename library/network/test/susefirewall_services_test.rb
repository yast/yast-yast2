#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "SuSEFirewallServices"
Yast.import "SCR"

# Path to a test data - service file - mocking the default data path
SERVICES_DATA_PATH =
  Yast::SuSEFirewalldServicesClass::SERVICES_DIRECTORIES.map do |services_dir|
    File.join(DATA_PATH, services_dir)
  end

def setup_data_dir
end

FakeFirewallServices = Yast::SuSEFirewalldServicesClass.new

describe FakeFirewallServices do
  before do
    stub_const("Yast::SuSEFirewalldServicesClass::SERVICES_DIR", SERVICES_DATA_PATH)
  end

#  around do |example|
#    change_scr_root(DATA_PATH, &example)
#  end

  describe "#ServiceDefinedByPackage" do
    it "distinguishes whether service is defined by package" do
      expect(subject.ServiceDefinedByPackage("service:dns-server")).to eq(true)
      expect(subject.ServiceDefinedByPackage("dns-server")).to eq(false)
    end
  end

  describe "#GetFilenameFromServiceDefinedByPackage" do
    it "returns a file name (service name) taken from the service name if service is defined by package" do
      expect(subject.GetFilenameFromServiceDefinedByPackage("service:dns-server")).to eq "dns-server"
    end

    it "returns nil if service is not defined by package" do
      expect(subject.GetFilenameFromServiceDefinedByPackage("dns-server")).to be_nil
    end
  end

  describe "#GetMetadataAgent" do
    it "returns non-empty agent definition" do
      expect(subject.GetMetadataAgent("dns-server")).not_to be_nil
    end
  end

  describe "#service_details" do
    it "returns non-empty service definition" do
      allow(subject).to receive(:all_services).and_return(
        "service:dns-server"  => Yast::SuSEFirewallServicesClass::DEFAULT_SERVICE.merge("tcp_ports" => ["a", "b"]),
        "service:dhcp-server" => Yast::SuSEFirewallServicesClass::DEFAULT_SERVICE.merge("udp_ports" => ["x", "y"])
      )
      expect(subject.service_details("service:dns-server")).not_to be_nil
      expect(subject.service_details("service:dns-server")["tcp_ports"]).to eq(["a", "b"])
    end

    it "throws an exception SuSEFirewalServiceNotFound if service does not exist" do
      allow(subject).to receive(:all_services).and_return({})
      expect { subject.service_details("undefined_service") }.to raise_error(
        Yast::SuSEFirewalServiceNotFound, /undefined_service/
      )
    end
  end

  describe "#all_services", :skip => true do
    it "reads all services from disk and returns them" do
      # Listing services directly from test-dir
      services_on_disk = SERVICES_DATA_PATH.map {|p| Dir.entries(p)}.flatten.reject do |s|
        Yast::SuSEFirewalldServicesClass::IGNORED_SERVICES.include?(s)
      end.map {|s| s.gsub(".xml","") }
      services_on_disk.map! do |s|
        Yast::SuSEFirewalldServicesClass::DEFINED_BY_PKG_PREFIX + s
      end

      services = subject.all_services
      expect(services.keys.sort).to eq(services_on_disk.sort)
      # Just to make sure nobody removes service files without changing the test-case
      expect(services.size).to be >= 7
    end
  end

  describe "#IsKnownService" do
    before do
      allow(subject).to receive(:all_services).and_return({
        "service:dns-server"  => Yast::SuSEFirewallServicesClass::DEFAULT_SERVICE.merge("tcp_ports" => ["a", "b"]),
        "service:dhcp-server" => Yast::SuSEFirewallServicesClass::DEFAULT_SERVICE.merge("udp_ports" => ["x", "y"])
      })
    end

    it "returns whether service exists" do
      expect(subject.IsKnownService("service:dns-server")).to eq(true)
      expect(subject.IsKnownService("service:no-bind")).to eq(false)
    end

    it "does not throw an exception if service does not exist" do
      expect { subject.IsKnownService("unknown-service") }.not_to raise_error
    end
  end

  describe "#GetListOfServicesAddedByPackage" do
    before do
      allow(subject).to receive(:all_services).and_return({
        "service:dns-server"  => Yast::SuSEFirewallServicesClass::DEFAULT_SERVICE.merge("tcp_ports" => ["a", "b"]),
        "service:dhcp-server" => Yast::SuSEFirewallServicesClass::DEFAULT_SERVICE.merge("udp_ports" => ["x", "y"])
      })
    end

    it "return list of known services" do
      expect(subject.GetListOfServicesAddedByPackage.size).to be >= 2
    end
  end

  context "while getting detailed info about a particular service" do
    before do
      allow(subject).to receive(:all_services).and_return({
        "service:special-service"  => Yast::SuSEFirewallServicesClass::DEFAULT_SERVICE
          .merge("tcp_ports" => ["port_1", "port_2"], "udp_ports" => ["zzz", "bbb", "aaa"])
      })
    end

    describe "#GetNeededTCPPorts" do
      it "returns list of TCP ports required by a service" do
        expect(subject.GetNeededTCPPorts("service:special-service")).to eq(["port_1", "port_2"])
      end
    end

    describe "#GetNeededUDPPorts" do
      it "returns list of UDP ports required by a service" do
        expect(subject.GetNeededUDPPorts("service:special-service")).to eq(["zzz", "bbb", "aaa"])
      end
    end

    describe "#GetNeededRPCPorts", :skip do
      it "returns list of RPC ports required by a service" do
        expect(subject.GetNeededRPCPorts("service:special-service")).to eq([])
      end
    end

    describe "#GetNeededIPProtocols", :skip do
      it "returns list of IP protocols required by a service" do
        expect(subject.GetNeededIPProtocols("service:special-service")).to eq(["ICMP", "HMP", "DDP", "RSVP"])
      end
    end

    describe "#GetDescription", :skip do
      it "returns service description" do
        expect(subject.GetDescription("service:special-service")).to include("parsed")
      end
    end

    describe "#GetNeededBroadcastPorts", :skip do
      it "returns list of broadcast ports required by a service" do
        expect(subject.GetNeededBroadcastPorts("service:special-service")).to eq(["port_x", "port_z"])
      end
    end

    describe "#GetNeededPortsAndProtocols" do
      before do
       allow(subject).to receive(:all_services).and_return({
          "service:special-service"  => Yast::SuSEFirewallServicesClass::DEFAULT_SERVICE
            .merge("tcp_ports" => ["port_1", "port_2"], "udp_ports" => ["zzz", "bbb", "aaa"])
        })
      end

      it "returns hash of ports and protocols required by a service" do
        service_details = subject.GetNeededPortsAndProtocols("service:special-service")

        expect(service_details.is_a?(Hash)).to eq(true)

        expect(service_details["tcp_ports"]).not_to be_empty
        expect(service_details["udp_ports"]).not_to be_empty

        expect(service_details["rpc_ports"]).to be_empty
      end
    end
  end

  describe "#SetNeededPortsAndProtocols", :skip do
    it "sets and writes new settings to a service definition file" do
      allow(Yast::SCR).to receive(:Write).and_return true

      new_set_of_ports = ["new", "set", "of", "ports"]

      service_definition = subject.GetNeededPortsAndProtocols("service:special-service")
      expect(service_definition["tcp_ports"]).not_to eq(new_set_of_ports)
      service_definition["tcp_ports"] = new_set_of_ports

      expect(subject.SetNeededPortsAndProtocols("service:special-service", service_definition)).to eq(true)
      expect(subject.GetNeededPortsAndProtocols("service:special-service")).to eq(service_definition)
    end
  end

  context "while adjusting and checking the Modified flag" do
    before(:each) do
      subject.ResetModified
    end

    describe "#GetModified" do
      it "returns the default Modified flag" do
        expect(subject.GetModified()).to eq(false)
      end
    end

    describe "#SetModified" do
      it "sets the Modified flag" do
        subject.SetModified
        expect(subject.GetModified()).to eq(true)
      end
    end

    describe "#ResetModified" do
      it "resets the Modified flag to default" do
        subject.SetModified
        subject.ResetModified
        expect(subject.GetModified()).to eq(false)
      end
    end
  end
end
