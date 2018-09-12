#!/usr/bin/env rspec
# encoding: utf-8
#
# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../../test_helper"
require "y2firewall/firewalld"
require "y2firewall/firewalld/service"

describe Y2Firewall::Firewalld::Service do
  let(:firewalld) { Y2Firewall::Firewalld.instance }
  let(:api) { Y2Firewall::Firewalld::Api.new(mode: :offline) }
  let(:installed?) { true }
  let(:service) { described_class.new(name: "service") }

  before do
    allow(firewalld).to receive(:find_service).with("service")
    allow(firewalld).to receive(:api).and_return(api)
    allow(firewalld).to receive(:installed?).and_return(installed?)
  end

  def mock_read_service
    allow(api).to receive(:service_short).and_return("Test service")
    allow(api).to receive(:service_description).and_return("Test service long description")
    allow(api).to receive(:service_ports).and_return(["80/tcp", "53/udp"])
    allow(api).to receive(:service_protocols).and_return(["gre", "igmp"])
    allow(api).to receive(:service_supported?).with(service.name).and_return(true)
  end

  describe ".modify_ports" do
    subject { described_class }

    context "when firewalld is not installed" do
      let(:installed?) { false }

      it "returns false" do
        expect(subject.modify_ports(name: "service", tcp_ports: ["80", "8080"])).to eq(false)
      end
    end

    context "when firewalld is installed" do
      before do
        allow(service).to receive(:ports=)
        allow(service).to receive(:apply_changes!)
        allow(firewalld).to receive(:find_service).with("service").and_return(service)
      end

      it "looks for the the service with the name given if exists" do
        expect(firewalld).to receive(:find_service).with("service").and_return(service)

        subject.modify_ports(name: "service", tcp_ports: ["80"])
      end

      it "modifies the service tcp and udp ports" do
        expect(service).to receive(:ports=).with(["80/tcp", "8080/tcp", "53/udp"])
        expect(service).to receive(:apply_changes!)

        subject.modify_ports(name: "service", tcp_ports: ["80", "8080"], udp_ports: ["53"])
      end
    end
  end

  describe "#create!" do
    it "creates a new service definition for this service" do
      expect(api).to receive(:create_service).with(service.name)

      service.create!
    end
  end

  describe "#supported?" do
    it "returns true if a service definition for the service name exists" do
      expect(api).to receive(:service_supported?).with(service.name).and_return(true)

      expect(service.supported?).to eql(true)
    end

    it "returns false if there is no service definition for this service" do
      new_service = described_class.new(name: "new_service")
      expect(api).to receive(:service_supported?).with("new_service").and_return(false)
      expect(new_service.supported?).to eql(false)
    end
  end

  describe "#read" do
    before do
      mock_read_service
    end

    it "returns false if the service is not supported" do
      allow(api).to receive(:service_supported?).with(service.name).and_return(false)

      expect(service.read).to eql(false)
    end

    it "initializes the service using the api for each attribute or relation" do
      service.read
      expect(service.tcp_ports).to eql(["80"])
      expect(service.short).to eql("Test service")
      expect(service.description).to eql("Test service long description")
    end

    it "marks the service as not modified once read" do
      service.read
      expect(service.modified?).to eql(false)
    end

    it "returns true when read" do
      expect(service.read).to eql(true)
    end
  end

  describe "#apply_changes!" do
    let(:modified) { true }

    before do
      allow(service).to receive(:modified?).and_return(modified)
      allow(service).to receive(:apply_attributes_changes!)
      allow(service).to receive(:apply_relations_changes!)
    end

    context "when the service has been modified" do
      it "returns false if the service is not defined yet" do
        allow(api).to receive(:service_supported?).with(service.name).and_return(false)
        expect(service.apply_changes!).to eql(false)
      end

      it "writes the modified services attributes" do
        mock_read_service
        service.read
        service.short = "short Modified"
        service.add_port("137/tcp")
        service.add_protocol("bgp")

        expect(service).to receive(:apply_attributes_changes!)
        expect(service).to receive(:apply_relations_changes!)
        service.apply_changes!
      end

      it "marks the service as not modified once written" do
        allow(service).to receive(:modified?).and_call_original
        mock_read_service
        service.read
        service.short = "short Modified"
        expect(service.modified?).to eql(true)
        service.apply_changes!
        expect(service.modified?).to eql(false)
      end
    end

    context "when the service has not been modified" do
      let(:modified) { false }

      it "does not do any API call" do
        expect(service).to_not receive(:api)

        service.apply_changes!
      end

      it "returns true" do
        expect(service.apply_changes!).to eql(true)
      end
    end
  end

  describe "#tcp_ports" do
    before do
      mock_read_service
    end

    it "returns a list with the allowed tcp ports" do
      service.read
      expect(service.tcp_ports).to eql(["80"])
    end
  end

  describe "#udp_ports" do
    before do
      mock_read_service
    end

    it "returns a list with the allowed udp ports" do
      service.read
      expect(service.udp_ports).to eql(["53"])
    end
  end
end
