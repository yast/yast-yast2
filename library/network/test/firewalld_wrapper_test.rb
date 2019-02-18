#!/usr/bin/env rspec

require_relative "test_helper"
require "y2firewall/firewalld/interface"

Yast.import "FirewalldWrapper"

describe Yast::FirewalldWrapper do
  let(:firewalld) { Y2Firewall::Firewalld.instance }
  let(:external) { Y2Firewall::Firewalld::Zone.new(name: "external") }
  let(:interface) { Y2Firewall::Firewalld::Interface.new("eth0") }
  let(:zones) { [external] }

  before do
    allow(subject).to receive(:firewalld).and_return(firewalld)
    allow(firewalld).to receive(:zones).and_return(zones)
    allow(firewalld).to receive(:installed?).and_return(true)
    allow(Yast::NetworkInterfaces).to receive(:List).with("").and_return([])
    external.interfaces = ["eth0"]
    external.services = ["dhcp"]
  end

  describe "#read" do
    it "calls firewalld.read" do
      expect(firewalld).to receive(:read)

      subject.read
    end
  end

  describe "#write" do
    it "calls firewalld.write" do
      expect(firewalld).to receive(:write)

      subject.write
    end
  end

  describe "#is_enabled" do
    it "calls firewalld.enabled?" do
      expect(firewalld).to receive(:enabled?)

      subject.is_enabled
    end
  end

  describe "#is_modified" do
    it "calls firewalld.modified?" do
      expect(firewalld).to receive(:modified?)

      subject.is_modified
    end
  end

  describe "#add_port" do
    before do
      allow(external).to receive(:add_port).and_return(true)
    end

    it "returns false if the port is not a port, a valid range or an alias" do
      expect(subject.add_port("asdasd", "TCP", "eth0")).to eq(false)
      expect(subject.add_port("8080:8070", "TCP", "eth0")).to eq(false)
      expect(subject.add_port("ssh", "TCP", "eth0")).to eq(true)
    end

    it "returns false if the protocol is not supported" do
      expect(subject.add_port("ssh", "RCP", "eth0")).to eq(false)
      expect(subject.add_port("ssh", "TCP", "eth0")).to eq(true)
    end

    context "when the interface belongs to a known zone" do
      it "add the given port to the zone" do
        expect(external).to receive(:add_port).with("80/tcp")

        subject.add_port("80", "TCP", "eth0")
      end
    end

    context "when the interface does not belong to a known zone" do
      it "do nothing" do
        expect(external).to_not receive(:add_port)

        subject.add_port("80", "TCP", "eth1")
      end
    end
  end

  describe "#remove_port" do
    before do
      allow(external).to receive(:remove_port).and_return(true)
    end

    it "returns false if the port is not a port, a valid range or an alias" do
      expect(subject.remove_port("asdasd", "TCP", "eth0")).to eq(false)
      expect(subject.remove_port("8080:8070", "TCP", "eth0")).to eq(false)
      expect(subject.remove_port("ssh", "TCP", "eth0")).to eq(true)
    end

    it "returns false if the protocol is not supported" do
      expect(subject.remove_port("ssh", "RCP", "eth0")).to eq(false)
      expect(subject.remove_port("ssh", "TCP", "eth0")).to eq(true)
    end

    context "when the interface belongs to a known zone" do
      it "remove the given port from the zone" do
        allow(external).to receive(:ports).and_return(["80/tcp", "8080/tcp"])
        expect(external).to receive(:remove_port).with("80/tcp")

        subject.remove_port("80", "TCP", "eth0")
      end
    end

    context "when the interface does not belong to a known zone" do
      it "do nothing" do
        expect(external).to_not receive(:remove_port)

        subject.remove_port("80", "TCP", "eth1")
      end
    end
  end

  describe "#zone_name_of_interface" do
    context "interface cannot be found" do
      it "returns nil" do
        expect(subject.zone_name_of_interface("wrong_interface")).to eq(nil)
      end
    end

    context "interface is available" do
      it "returns interface zone name" do
        expect(subject.zone_name_of_interface("eth0")).to eq(external.name)
      end
    end
  end

  describe "#is_service_in_zone" do
    context "zone cannot be found" do
      it "returns false" do
        allow(firewalld).to receive(:find_zone).and_return(nil)
        expect(subject.is_service_in_zone("service", "wrong_zone")).to eq(false)
      end
    end

    context "zone is available" do
      it "returns false if service cannot be found" do
        allow(firewalld).to receive(:zones).and_return(zones)
        expect(subject.is_service_in_zone("wrong_service", "wrong_zone")).to eq(false)
      end

      it "returns true if service can be found" do
        allow(firewalld).to receive(:zones).and_return(zones)
        expect(subject.is_service_in_zone(external.services.first, "wrong_zone")).to eq(false)
      end
    end
  end

  describe "#all_known_interfaces" do
    context "interfaces are available" do
      it "returns all interfaces" do
        expect(Y2Firewall::Firewalld::Interface).to receive(:known).and_return([interface])
        expect(subject.all_known_interfaces).to eq([{ "id" => "eth0", "zone" => "external", "name" => "Unknown" }])
      end
    end
  end

  describe "#modify_interface_services" do
    context "interface has no zone" do
      it "do not set services" do
        expect_any_instance_of(Y2Firewall::Firewalld::Zone).not_to receive(:add_service)
        expect_any_instance_of(Y2Firewall::Firewalld::Zone).not_to receive(:remove_service)
        subject.modify_interface_services(["service:dhcp-server"], ["wrong_interface"], true)
      end
    end

    context "interface has a zone" do
      it "set services" do
        expect_any_instance_of(Y2Firewall::Firewalld::Zone).to receive(:add_service)
        expect_any_instance_of(Y2Firewall::Firewalld::Zone).not_to receive(:remove_service)
        subject.modify_interface_services(["service:dhcp-server"], ["eth0"], true)
      end

      it "unset services" do
        expect_any_instance_of(Y2Firewall::Firewalld::Zone).not_to receive(:add_service)
        expect_any_instance_of(Y2Firewall::Firewalld::Zone).to receive(:remove_service)
        subject.modify_interface_services(["service:dhcp-server"], ["eth0"], false)
      end
    end
  end
end
