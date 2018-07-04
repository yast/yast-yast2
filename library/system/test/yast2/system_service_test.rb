#!/usr/bin/env rspec
# encoding: utf-8

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

require_relative "../test_helper"
require "yast2/system_service"

describe Yast2::SystemService do
  subject(:system_service) { described_class.new(service) }

  let(:service) do
    double("service", enabled?: true, name: "cups", active?: active?, enable: nil)
  end
  let(:socket) { double("socket", enabled?: true) }
  let(:active?) { true }

  before do
    allow(service).to receive(:socket).and_return(socket)
  end

  describe ".find" do
    let(:systemd_service) { instance_double(Yast::SystemdService) }

    before do
      allow(Yast::SystemdService).to receive(:find).with("cups").and_return(systemd_service)
    end

    it "finds a systemd service" do
      system_service = described_class.find("cups")
      expect(system_service).to be_a(described_class)
      expect(system_service.service).to eq(systemd_service)
    end
  end

  describe ".find_many" do
    let(:apparmor) { instance_double(Yast::SystemdService) }
    let(:cups) { instance_double(Yast::SystemdService) }

    before do
      allow(Yast::SystemdService).to receive(:find_many).with(["apparmor", "cups"])
        .and_return([apparmor, cups])
    end

    it "finds a set of systemd services" do
      system_services = described_class.find_many(["apparmor", "cups"])
      expect(system_services).to be_all(Yast2::SystemService)
      expect(system_services.map(&:service)).to eq([apparmor, cups])
    end

    context "when some service is not found" do
      before do
        allow(Yast::SystemdService).to receive(:find_many).with(["apparmor", "cups"])
          .and_return([nil, cups])
      end

      it "ignores the not found service" do
        system_services = described_class.find_many(["apparmor", "cups"])
        expect(system_services.map(&:service)).to eq([cups])
      end
    end
  end

  describe "#start_mode" do
    context "when the service is enabled" do
      it "returns :on_boot" do
        expect(system_service.start_mode).to eq(:on_boot)
      end
    end

    context "when the service is disabled" do
      let(:service) { double("service", enabled?: false) }

      context "but the associated socket is enabled" do
        it "returns :on_demand" do
          expect(system_service.start_mode).to eq(:on_demand)
        end
      end

      context "and the socket is disabled" do
        let(:socket) { double("socket", enabled?: false) }

        it "returns :manual" do
          expect(system_service.start_mode).to eq(:manual)
        end
      end

      context "and there is no socket" do
        let(:socket) { nil }

        it "returns :manual" do
          expect(system_service.start_mode).to eq(:manual)
        end
      end
    end
  end

  describe "#start_mode=" do
    before do
      allow(service).to receive(:enable)
    end

    it "sets the wanted start_mode" do
      expect { system_service.start_mode = :on_demand }.to change { system_service.start_mode }
        .from(:on_boot).to(:on_demand)
    end

    context "when an invalid value is given" do
      it "raises an error" do
        expect { system_service.start_mode = :other }.to raise_error(ArgumentError)
      end
    end

    context "when the wanted start_mode is the same than the current one" do
      it "ignores the change" do
        system_service.start_mode = :on_boot
        expect(system_service.changed?).to eq(false)
      end
    end
  end

  describe "#start_modes" do
    before do
      allow(service).to receive(:socket).and_return(socket)
    end

    context "when an associated socket exists" do
      let(:socket) { double("socket", disable: true) }

      it "returns :on_boot, :on_demand and :manual" do
        expect(system_service.start_modes).to eq([:on_boot, :manual, :on_demand])
      end
    end

    context "when no associated socket exists" do
      let(:socket) { nil }

      it "returns :on_boot and :manual" do
        expect(system_service.start_modes).to eq([:on_boot, :manual])
      end
    end
  end

  describe "#active=" do
    context "when set to true" do
      let(:active?) { false }

      it "sets #active to true" do
        expect { system_service.active = true }.to change { system_service.active }
          .from(false).to(true)
      end

      context "and the service is already active" do
        let(:active?) { true }

        it "ignores the change" do
          system_service.active = true
          expect(system_service.changed?).to eq(false)
        end
      end
    end

    context "when set to false" do
      let(:active?) { true }

      it "sets #active to false" do
        expect { system_service.active = false }.to change { system_service.active }
          .from(true).to(false)
      end

      context "and the service is already inactive" do
        let(:active?) { false }

        it "ignores the change" do
          system_service.active = false
          expect(system_service.changed?).to eq(false)
        end
      end
    end
  end

  describe "#active" do
    context "when service is active" do
      let(:active?) { true }

      it "returns true" do
        expect(system_service.active).to eq(true)
      end
    end

    context "when service is inactive" do
      let(:active?) { false }

      it "returns false" do
        expect(system_service.active).to eq(false)
      end
    end

    context "when an active value was given" do
      before do
        system_service.active = false
      end

      it "returns the given value" do
        expect(system_service.active).to eq(false)
      end
    end
  end

  describe "#save=" do
    let(:socket) { double("socket", disable: true) }
    let(:start_mode) { :on_boot }

    before do
      system_service.start_mode = start_mode
    end

    context "when start_mode was changed to :on_boot" do
      let(:service) { double("service", enabled?: false, name: "cups") }
      let(:socket) { double("socket", enabled?: true) }
      let(:start_mode) { :on_boot }

      it "enables the service to start on boot" do
        expect(service).to receive(:enable)
        expect(socket).to receive(:disable)
        system_service.save
      end
    end

    context "when start_mode was changed to :on_demand" do
      let(:start_mode) { :on_demand }

      it "enables the socket" do
        expect(service).to receive(:disable)
        expect(socket).to receive(:enable)
        system_service.save
      end
    end

    context "when start_mode was changed to :manual" do
      let(:start_mode) { :manual }

      it "disables the service and the socket" do
        expect(service).to receive(:disable)
        expect(socket).to receive(:disable)
        system_service.save
      end
    end

    context "when active is set to true" do
      before { system_service.active = true }

      context "and the service is already active" do
        let(:active?) { true }

        it "does not try to activate the service again" do
          expect(service).to_not receive(:start)
          system_service.save
        end
      end

      context "and the service is inactive" do
        let(:active?) { false }

        it "tries to activate the service" do
          expect(service).to receive(:start)
          system_service.save
        end

        it "does not active the service if the status must be ignored" do
          expect(service).to_not receive(:start)
          system_service.save(ignore_status: true)
        end
      end
    end

    context "when active is set to false" do
      before { system_service.active = false }

      context "and the service is active" do
        let(:active?) { true }

        it "tries to stop the service" do
          expect(service).to receive(:stop)
          system_service.save
        end

        it "does not stop the service if the status must be ignored" do
          expect(service).to_not receive(:start)
          system_service.save(ignore_status: true)
        end
      end

      context "and the service is inactive" do
        let(:active?) { false }

        it "does not try to stop the service again" do
          expect(service).to_not receive(:stop)
          system_service.save
        end
      end
    end
  end

  describe "#changed?" do
    context "when some change was made" do
      before do
        system_service.active = false
      end

      it "returns true" do
        expect(system_service.changed?).to eq(true)
      end
    end

    context "when no changes were made" do
      it "returns false" do
        expect(system_service.changed?).to eq(false)
      end
    end
  end

  describe "#search_terms" do
    before do
      allow(service).to receive(:id).and_return("cups.service")
    end

    context "when the service does not have an associated socket" do
      let(:socket) { nil }

      it "returns only the service full name" do
        expect(system_service.search_terms).to contain_exactly("cups.service")
      end
    end

    context "when the service has an associated socket" do
      let(:socket) { instance_double(Yast::SystemdSocket, id: "cups.socket") }

      it "returns the service and socket full names" do
        expect(system_service.search_terms).to contain_exactly("cups.service", "cups.socket")
      end
    end
  end
end
