#!/usr/bin/env rspec
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

require_relative "../test_helper"
require "y2firewall/firewalld"

Yast.import "PackageSystem"
Yast.import "Service"

describe Y2Firewall::Firewalld do
  let(:firewalld) { described_class.clone.instance }
  let(:known_zones) { %w[dmz drop external home internal public trusted work] }
  let(:known_services) { %w[http https samba ssh] }
  let(:empty_zones) { known_zones.map { |z| Y2Firewall::Firewalld::Zone.new(name: z) } }
  let(:installed?) { true }
  before do
    allow(firewalld).to receive(:installed?).and_return(installed?)
    allow_any_instance_of(Y2Firewall::Firewalld::Api).to receive(:running?).and_return(false)
  end

  describe "#installed?" do
    before do
      allow(firewalld).to receive(:installed?).and_call_original
    end

    it "returns false it the firewalld is not installed" do
      allow(Yast::PackageSystem).to receive("Installed")
        .with(described_class::PACKAGE).and_return(false)

      expect(firewalld.installed?).to eq(false)
    end

    it "returns true it the firewalld is installed" do
      allow(Yast::PackageSystem).to receive("Installed")
        .with(described_class::PACKAGE).and_return true

      expect(firewalld.installed?).to eq(true)
    end
  end

  describe "#enabled?" do
    before do
      allow(firewalld).to receive(:installed?).and_return(true)
    end

    it "returns true if the firewalld service is enable" do
      allow(Yast::Service).to receive("Enabled")
        .with(described_class::SERVICE).and_return(true)

      expect(firewalld.enabled?).to eq(true)
    end

    it "returns false if the firewalld service is disable" do
      allow(Yast::Service).to receive("Enabled")
        .with(described_class::SERVICE).and_return(false)

      expect(firewalld.enabled?).to eq(false)
    end
  end

  describe "#restart" do
    let(:installed) { false }

    before do
      allow(firewalld).to receive("installed?").and_return(installed)
    end

    context "when firewalld service is not installed" do
      it "returns false" do
        expect(Yast::Service).to_not receive("Restart")

        expect(firewalld.restart).to eq(false)
      end
    end

    context "when firewalld service is installed" do
      let(:installed) { true }

      it "restarts the firewalld service" do
        expect(Yast::Service).to receive("Restart").with(described_class::SERVICE)

        firewalld.restart
      end
    end
  end

  describe "#start" do
    let(:installed) { false }
    let(:running) { false }

    before do
      allow(firewalld).to receive("installed?").and_return(installed)
      allow(firewalld).to receive("running?").and_return(running)
    end

    context "when firewalld service is not installed" do
      it "returns false" do
        expect(Yast::Service).to_not receive("Start")

        firewalld.start
      end
    end

    context "when firewalld service is installed" do
      let(:installed) { true }

      context "and the service is already running" do
        let(:running) { true }
        it "returns false" do
          expect(Yast::Service).to_not receive("Start")

          expect(firewalld.start).to eq(false)
        end
      end

      context "and the service is not running" do
        it "starts firewalld service" do
          expect(Yast::Service).to receive("Start").with(described_class::SERVICE)

          firewalld.start
        end
      end
    end
  end

  describe "#stop" do
    let(:installed) { false }
    let(:running) { false }

    before do
      allow(firewalld).to receive("installed?").and_return(installed)
      allow(firewalld).to receive("running?").and_return(running)
    end

    context "when firewalld service is not installed" do
      it "returns false" do
        expect(Yast::Service).to_not receive("Stop")

        firewalld.stop
      end
    end

    context "when firewalld service is installed" do
      let(:installed) { true }

      context "and firewalld service is not running" do
        it "returns false" do
          expect(Yast::Service).to_not receive("Stop")

          expect(firewalld.stop).to eq(false)
        end
      end

      context "and firewalld service is running" do
        let(:running) { true }

        it "stops firewalld service" do
          expect(Yast::Service).to receive("Stop").with(described_class::SERVICE)

          firewalld.stop
        end
      end
    end
  end

  describe "#running" do
    it "returns true if the service is running" do
      expect(firewalld.api).to receive(:running?).and_return(true)

      expect(firewalld.running?).to eq(true)
    end
  end

  describe "#api" do
    it "returns an Y2Firewall::Firewalld::Api instance" do
      expect(firewalld.api).to be_a Y2Firewall::Firewalld::Api
    end
  end

  describe "#system_service" do
    let(:service) { Yast2::SystemService.build(Y2Firewall::Firewalld::SERVICE) }
    before do
      allow(Yast2::SystemService).to receive(:find).and_return(service)
    end

    context "if the firewalld service is found" do
      it "returns the firewalld Yast2::SystemService object" do
        expect(firewalld.system_service).to be_a Yast2::SystemService
      end
    end

    context "if the firewalld service is not found" do
      let(:service) { nil }

      it "returns nil" do
        expect(firewalld.system_service).to eq(nil)
      end
    end
  end

  describe "#read" do
    let(:zones_definition) do
      ["dmz",
       "  target: default",
       "  interfaces: ",
       "  ports: ",
       "  protocols:",
       "  sources:",
       "",
       "external (active)",
       "  target: default",
       "  interfaces: eth0",
       "  services: ssh samba",
       "  ports: 5901/tcp 5901/udp",
       "  protocols:",
       "  sources:"]
    end

    let(:api) do
      instance_double(Y2Firewall::Firewalld::Api,
        log_denied_packets: "off",
        default_zone:       "dmz",
        list_all_zones:     zones_definition,
        zones:              known_zones,
        services:           known_services)
    end

    before do
      allow(Y2Firewall::Firewalld::Api).to receive(:new).and_return(api)
    end

    it "returns false if firewalld is not installed" do
      allow(firewalld).to receive(:installed?).and_return(false)

      expect(firewalld.read).to eq(false)
    end

    it "resets the firewalld api instance" do
      expect(Y2Firewall::Firewalld::Api).to receive(:new).twice.and_return(:first, api)
      api = firewalld.api
      firewalld.read
      expect(firewalld.api).to_not eq(api)
    end

    it "stores the list of available zone names" do
      expect { firewalld.read }.to change { firewalld.current_zone_names }.from([]).to(known_zones)
    end

    it "stores the list of available service names" do
      expect { firewalld.read }.to change { firewalld.current_service_names }.from([]).to(known_services)
    end

    it "initializes the list of zones parsing the firewalld summary" do
      firewalld.read

      external = firewalld.find_zone("external")
      expect(external.ports).to eq(["5901/tcp", "5901/udp"])
    end

    it "initializes global options with the current firewalld config" do
      firewalld.read

      expect(firewalld.log_denied_packets).to eq("off")
      expect(firewalld.default_zone).to eq("dmz")
    end
  end

  describe "#find_zone" do
    it "returns the Y2Firewall::Firewalld::Zone with the given name" do
      firewalld.zones = empty_zones
      zone = firewalld.find_zone("external")

      expect(zone).to be_a(Y2Firewall::Firewalld::Zone)
      expect(zone.name).to eq("external")
    end

    it "returns nil if no zone match the given name" do
      firewalld.zones = []

      expect(firewalld.find_zone("test")).to eq(nil)
    end
  end

  describe "#modified?" do
    let(:api) do
      instance_double(Y2Firewall::Firewalld::Api, log_denied_packets: "off",
                      default_zone: "public", zones: known_zones, services: ["http"])
    end

    let(:modified_zone) { false }

    before do
      allow(firewalld).to receive("api").and_return api
      firewalld.zones = empty_zones
      firewalld.current_zone_names = known_zones
      empty_zones.each do |zone|
        allow(zone).to receive(:modified?).and_return(modified_zone)
      end
      firewalld.log_denied_packets = "all"
      firewalld.untouched!
    end

    context "when some of the attributes have been modified since read" do
      it "returns true" do
        firewalld.default_zone = "external"
        expect(firewalld.modified?).to eq(true)
      end
    end

    context "when no attribute has been modified since read" do
      it "returns false" do
        expect(firewalld.modified?).to eq(false)
      end
    end
  end

  describe "#write_only" do
    let(:api) do
      Y2Firewall::Firewalld::Api.new
    end
    let(:api) do
      instance_double(Y2Firewall::Firewalld::Api, log_denied_packets: "on",
                      default_zone: "public", zones: known_zones, services: ["http"])
    end

    before do
      firewalld.zones = empty_zones
      firewalld.current_zone_names = known_zones
      empty_zones.each do |zone|
        allow(zone).to receive(:modified?).and_return(false)
      end

      allow(firewalld).to receive("read?").and_return(true)
      allow(firewalld).to receive("api").and_return api
      allow(firewalld).to receive(:apply_zones_changes!)
      allow(api).to receive(:modify_default_zone)
      allow(api).to receive(:modify_log_denied_packets)
    end

    it "enforces a read of the configuration if not read before" do
      allow(firewalld).to receive("read?").and_return(false)
      expect(firewalld).to receive("read")

      firewalld.write_only
    end

    it "applies in firewalld all the changes done in the object since read" do
      firewalld.log_denied_packets = "unicast"
      firewalld.default_zone = "drop"

      expect(api).to receive(:modify_default_zone).with("drop")
      expect(api).to receive(:modify_log_denied_packets).with("unicast")

      firewalld.write_only
    end

    it "only apply changes to the modified zones" do
      expect(firewalld).to receive(:apply_zones_changes!).and_call_original
      dmz = firewalld.find_zone("dmz")
      allow(dmz).to receive(:modified?).and_return(true)
      expect(dmz).to receive(:apply_changes!)
      external = firewalld.find_zone("external")
      expect(external).to_not receive(:apply_changes!)

      firewalld.write_only
    end

    it "returns true" do
      expect(firewalld.write_only).to eq(true)
    end
  end

  describe "#write" do
    it "writes the configuration" do
      allow(firewalld).to receive(:reload)
      expect(firewalld).to receive(:write_only)

      firewalld.write
    end

    it "reloads firewalld" do
      allow(firewalld).to receive(:write_only).and_return(true)
      expect(firewalld).to receive(:reload)

      firewalld.write
    end
  end

  describe "#modified_from_default" do
    context "when the given resource directoy does not exist" do
      it "returns an empty array" do
        expect(firewalld.modified_from_default("not_existent")).to eq([])
      end
    end

    it "returns a list of the modified items" do
      expect(firewalld.modified_from_default("zones", target_root: DATA_PATH)).to eq(["internal"])
    end
  end
end
