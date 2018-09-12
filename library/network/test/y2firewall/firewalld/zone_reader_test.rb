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
require "y2firewall/firewalld/zone_reader"

describe Y2Firewall::Firewalld::ZoneReader do
  describe "#read" do
    subject { described_class.new(zone_names, zones_definition) }
    let(:zone_names) { ["public", "dmz"] }
    let(:zones_definition) do
      [
        "dmz",
        "  target: default",
        "  icmp-block-inversion: no",
        "  interfaces: ",
        "  sources: ",
        "  services: ",
        "  ports: ",
        "  protocols: ",
        "  masquerade: no",
        "  forward-ports: ",
        "  source-ports: ",
        "  icmp-blocks: ",
        "  rich rules: ",
        "\t",
        "",
        "public (active)",
        "  summary: Public",
        "  description: For use in public areas. You do not trust the other" \
        " computers on networks to not harm your computer." \
        " Only selected incoming connections are accepted.",
        "  target: default",
        "  icmp-block-inversion: no",
        "  interfaces: eth0 ens3",
        "  sources: 192.168.0.0/24 192.168.1.0/24 192.168.2.0/24",
        "  services: ssh iscsi-target",
        "  ports: 123/udp 21/udp 111/tcp 111/udp 1123/udp 530/udp 530/tcp",
        "  protocols: ",
        "  masquerade: yes",
        "  forward-ports: port=2222:proto=tcp:toport=22:toaddr=",
        "        port=9080:proto=tcp:toport=80:toaddr=",
        "  source-ports: ",
        "  icmp-blocks: echo-request echo-reply",
        "  rich rules: ",
        "        rule service name=\"http\" accept",
        "        rule service name=\"https\" accept",
        "        rule service name=\"ssh\" accept",
        "\t"
      ]
    end

    context "when no zone is configured" do
      let(:zone_names) { [] }

      it "returns an empty array" do
        expect(subject.read).to eq([])
      end
    end

    context "when some zone is configured" do
      it "returns an array of Y2Firewall::Firewalld::Zone" do
        zones = subject.read
        expect(zones.size).to eq(2)
        expect(zones).to all(be_an(Y2Firewall::Firewalld::Zone))
      end

      it "initializes each zone based on the zone definition" do
        zones = subject.read

        public_zone = zones.find { |z| z.name == "public" }
        expect(public_zone.target).to eq("default")
        expect(public_zone.short).to eq("Public")
        expect(public_zone.description).to include("You do not trust the other computers")
        expect(public_zone.services).to eq(["ssh", "iscsi-target"])
        expect(public_zone.interfaces).to eq(["eth0", "ens3"])
        expect(public_zone.ports).to include("123/udp", "530/udp")
        expect(public_zone.masquerade).to eq(true)
        expect(public_zone.sources).to eq(["192.168.0.0/24", "192.168.1.0/24", "192.168.2.0/24"])
        dmz_zone = zones.find { |z| z.name == "dmz" }
        expect(dmz_zone.masquerade).to eq(false)
        expect(dmz_zone.services).to be_empty
      end
    end
  end
end
