#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "FirewalldWrapper"

describe Yast::FirewalldWrapper do
  let(:firewalld) { Y2Firewall::Firewalld.instance }
  let(:external) { Y2Firewall::Firewalld::Zone.new(name: "external") }
  let(:zones) { [external] }

  before do
    allow(subject).to receive(:firewalld).and_return(firewalld)
    allow(firewalld).to receive(:zones).and_return(zones)
    allow(firewalld).to receive(:installed?).and_return(true)
    external.interfaces = ["eth0"]
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
end
