#!/usr/bin/env rspec
# encoding: utf-8
#
# Copyright (c) [2017] SUSE LLC
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
require "y2firewall/firewalld/zone"

describe Y2Firewall::Firewalld::Zone do
  describe ".known_zones" do
    it "returns a hash with known zone names and descriptions" do
      expect(described_class.known_zones).to be_a(Hash)
      expect(described_class.known_zones).to include "public"
      expect(described_class.known_zones["dmz"]).to eq(N_("Demilitarized Zone"))
    end
  end

  describe "#initialize" do
    context "when :name is specified" do
      subject { described_class.new(name: "test") }
      it "uses the :name" do
        expect(subject.name).to eq("test")
      end
    end

    context "when :name is not specified" do
      let(:api) { instance_double("Y2Firewall::Firewalld::Api", default_zone: "default") }

      it "uses the default zone name" do
        allow_any_instance_of(Y2Firewall::Firewalld).to receive(:api).and_return(api)

        expect(subject.name).to eq("default")
      end
    end
  end

  describe "#modified?" do
    subject { described_class.new(name: "test") }
    let(:api) { instance_double("Y2Firewall::Firewalld::Api", masquerade_enabled?: true) }

    before do
      allow_any_instance_of(Y2Firewall::Firewalld).to receive(:api).and_return(api)
      allow(subject).to receive(:current_services).and_return(["ssh"])
      allow(subject).to receive(:current_interfaces).and_return(["eth0", "eth1"])
      allow(subject).to receive(:current_ports).and_return(["80/tcp", "443/tcp"])
      allow(subject).to receive(:current_protocols).and_return([])
      allow(subject).to receive(:current_sources).and_return([])
    end

    context "when the zone was modified since read" do
      it "returns true" do
        subject.read
        expect(subject.interfaces).to eq(["eth0", "eth1"])
        subject.interfaces = ["eth0"]
        expect(subject.modified?).to eq(true)
        subject.read
        expect(subject.modified?).to eq(false)
        subject.remove_interface("eth1")
        expect(subject.modified?).to eq(true)
      end
    end

    context "when the zone was not modified since read" do
      it "returns false" do
        expect(subject.modified?).to eq(false)
      end
    end
  end

  describe "#export" do
    subject { described_class.new(name: "test") }

    before do
      allow(subject).to receive(:interfaces).and_return(["eth0", "eth1"])
      allow(subject).to receive(:services).and_return(["ssh", "samba"])
      allow(subject).to receive(:ports).and_return(["80/tcp", "443/tcp"])
      allow(subject).to receive(:protocols).and_return(["esp"])
      allow(subject).to receive(:sources).and_return([])
      allow(subject).to receive(:masquerade).and_return(true)
    end

    it "dumps a hash with the zone configuration" do
      config = subject.export

      expect(config).to be_a(Hash)
      expect(config["interfaces"]).to eql(["eth0", "eth1"])
      expect(config["services"]).to eql(["ssh", "samba"])
      expect(config["ports"]).to eql(["80/tcp", "443/tcp"])
      expect(config["protocols"]).to eql(["esp"])
      expect(config["sources"]).to eql([])
      expect(config["masquerade"]).to eql(true)
    end
  end
end
