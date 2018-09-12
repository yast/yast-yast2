#!/usr/bin/env rspec
# encoding: utf-8
#
# Copyright (c) 2018 SUSE LLC
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
require "y2firewall/firewalld/api"
require "y2firewall/firewalld/zone"

describe Y2Firewall::Firewalld::Zone do
  let(:firewalld) { Y2Firewall::Firewalld.instance }
  let(:api) { instance_double("Y2Firewall::Firewalld::Api", default_zone: "default") }

  before do
    allow(firewalld).to receive(:installed?).and_return(true)
    allow(firewalld).to receive(:api).and_return(api)
  end

  describe "#initialize" do
    context "when :name is specified" do
      subject { described_class.new(name: "test") }
      it "uses the :name" do
        expect(subject.name).to eq("test")
      end
    end

    context "when :name is not specified" do
      it "uses the default zone name" do
        expect(subject.name).to eq("default")
      end
    end
  end

  describe "#modified?" do
    subject { described_class.new(name: "test") }
    let(:api) { instance_double("Y2Firewall::Firewalld::Api", masquerade_enabled?: true) }

    before do
      allow(firewalld).to receive(:api).and_return(api)
      subject.relations.each do |r|
        allow(subject).to receive(:public_send).with("current_#{r}").and_return([])
      end
      allow(subject).to receive(:public_send).with("current_services").and_return(["ssh"])
      allow(subject).to receive(:public_send).with("current_interfaces").and_return(["eth0", "eth1"])
      allow(subject).to receive(:public_send).with("current_ports").and_return(["80/tcp", "443/tcp"])
      allow(subject).to receive(:public_send).with(:interfaces).and_call_original
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

  describe "#reload!" do
    it "forces a reload of the firewalld configuration" do
      expect(api).to receive(:reload)

      subject.reload!
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

  describe "#untouched!" do
    subject { described_class.new(name: "test") }

    it "marks the zone as untouched or not modified" do
      subject.interfaces = ["eth0", "eth1"]
      expect(subject.modified?).to eq(true)
      subject.untouched!
      expect(subject.modified?).to eq(false)
      expect(subject.interfaces).to eq(["eth0", "eth1"])
    end
  end

  describe "#add_interface!" do
    subject { described_class.new(name: "test") }

    it "calls the API changing the specified interface to this zone" do
      expect(api).to receive(:change_interface).with("test", "eth0")

      subject.add_interface!("eth0")
    end
  end

  describe "#add_source!" do
    subject { described_class.new(name: "test") }

    it "calls the API changing the specified source to this zone" do
      expect(api).to receive(:change_source).with("test", "192.168.1.0/24")

      subject.add_source!("192.168.1.0/24")
    end
  end

  describe "#service_open?" do
    it "returns whether the service is allowed or not in the zone" do
      allow(subject).to receive(:services).and_return(["ssh", "vnc"])

      expect(subject.service_open?("ssh")).to eql(true)
      expect(subject.service_open?("samba")).to eql(false)
    end
  end

  describe "#full_name" do
    subject { described_class.new(name: "block") }

    it "returns the zone known full name" do
      expect(subject.full_name).to eq("Block Zone")
    end
  end

  describe "#apply_changes!" do
    context "when the zone has not been modified" do
      it "returns true" do
        allow(subject).to receive(:modified?).and_return(false)
        expect(subject.apply_changes!).to eql(true)
      end
    end

    context "when the zone has been modified" do
      subject { described_class.new(name: "test") }

      it "applies all the changes done in its relations" do
        subject.services = ["ssh"]
        expect(subject).to receive(:apply_relations_changes!)
        subject.apply_changes!
      end

      it "applies all the changes done in its attributes" do
        subject.target = "ACCEPT"
        expect(subject).to receive(:apply_attributes_changes!)
        subject.apply_changes!
      end

      it "applies the masquerading modifications if it was modified" do
        expect(api).to receive(:add_masquerade)
        subject.masquerade = true
        subject.apply_changes!
      end

      it "sets the zone as not modified once applied all the changes" do
        subject.modified!(:false_value)
        expect(subject.modified?).to eql(true)
        subject.apply_changes!
        expect(subject.modified?).to eql(false)
      end

      it "returns true when applied all the changes" do
        expect(subject.apply_changes!).to eql(true)
      end
    end
  end
end
