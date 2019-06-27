#!/usr/bin/env rspec
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
require "y2firewall/firewalld/interface"

describe Y2Firewall::Firewalld::Interface do
  subject(:iface) { described_class.new("eth0") }
  subject(:unknown_iface) { described_class.new("virbr0") }

  before do
    allow(Yast::NetworkInterfaces).to receive(:List).with("")
      .and_return(["eth0", "lo", "wlan0"])
  end

  describe ".known" do
    it "returns an object for each known interface except 'lo'" do
      expect(described_class.known).to contain_exactly(
        an_object_having_attributes(name: "eth0"),
        an_object_having_attributes(name: "wlan0")
      )
    end
  end

  describe ".unknown" do
    let(:public_zone) do
      instance_double(Y2Firewall::Firewalld::Zone, interfaces: ["eth0", "eth1", "wlan0"])
    end

    before do
      allow(Y2Firewall::Firewalld.instance).to receive(:zones)
        .and_return([public_zone])
    end

    it "returns an object for each unknown interface enabled in some firewalld zone" do
      expect(described_class.unknown).to contain_exactly(
        an_object_having_attributes(name: "eth1")
      )
    end
  end

  describe "#name" do
    it "returns the interface name" do
      expect(iface.name).to eq("eth0")
    end
  end

  describe "#id" do
    it "returns the name as a symbol" do
      expect(iface.id).to eq(:eth0)
    end
  end

  describe "#device_name" do
    DEVICE_NAME = "Some Device Name".freeze

    before do
      allow(Yast::NetworkInterfaces).to receive(:GetValue).with("eth0", "NAME")
        .and_return(DEVICE_NAME)
    end

    context "when the interface is known" do
      it "returns the device name" do
        expect(iface.device_name).to eq(DEVICE_NAME)
      end
    end

    context "when the interface is not known" do
      it "returns the translated 'Unknown' string" do
        expect(unknown_iface.device_name).to eq("Unknown")
      end
    end
  end

  describe "#zone" do
    let(:public_zone) do
      instance_double(Y2Firewall::Firewalld::Zone, interfaces: ["eth1"])
    end

    let(:dmz_zone) do
      instance_double(Y2Firewall::Firewalld::Zone, interfaces: ["eth0"])
    end

    before do
      allow(Y2Firewall::Firewalld.instance).to receive(:zones)
        .and_return([public_zone, dmz_zone])
    end

    it "returns the zone where the interface belongs to" do
      expect(iface.zone).to eq(dmz_zone)
    end
  end

  describe "#known?" do
    context "when the interface is known" do
      it "returns true" do
        expect(iface.known?).to eql(true)
      end
    end

    context "when the interface is unknown" do
      it "returns false" do
        expect(unknown_iface.known?).to eql(false)
      end
    end
  end

  describe "#zone=" do
    let(:public_zone) { Y2Firewall::Firewalld::Zone.new(name: "public") }
    let(:dmz_zone) { Y2Firewall::Firewalld::Zone.new(name: "dmz") }

    before do
      allow(Y2Firewall::Firewalld.instance).to receive(:zones)
        .and_return([public_zone, dmz_zone])
      public_zone.interfaces = ["eth1"]
      dmz_zone.interfaces = ["eth0"]
    end

    it "removes the interface from the zones that include the interface" do
      iface.zone = "public"
      expect(dmz_zone.interfaces).to be_empty
    end

    it "adds the interface to the given zone" do
      expect(public_zone.interfaces).to_not include("eth0")
      iface.zone = "public"
      expect(public_zone.interfaces).to include("eth0")
    end
  end
end
