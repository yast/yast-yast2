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

  let(:service) { double("service", enabled?: true, name: "cups") }
  let(:socket) { double("socket", enabled?: true) }

  before do
    allow(system_service).to receive(:socket).and_return(socket)
  end

  describe ".find" do
    let(:systemd_service) { instance_double(Yast::SystemdServiceClass::Service) }

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
    let(:apparmor) { instance_double(Yast::SystemdServiceClass::Service) }
    let(:cups) { instance_double(Yast::SystemdServiceClass::Service) }

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
    let(:socket) { double("socket", disable: true) }

    context "when :on_boot mode is given" do
      it "enables the service to start on boot" do
        expect(service).to receive(:enable)
        expect(socket).to receive(:disable)
        system_service.start_mode = :on_boot
      end
    end

    context "when :on_demand mode is given" do
      it "enables the socket" do
        expect(service).to receive(:disable)
        expect(socket).to receive(:enable)
        system_service.start_mode = :on_demand
      end
    end

    context "when :manual mode is given" do
      it "disables the service and the socket" do
        expect(service).to receive(:disable)
        expect(socket).to receive(:disable)
        system_service.start_mode = :manual
      end
    end

    context "when an invalid value is given" do
      it "raises an error" do
        expect { system_service.start_mode = :other }.to raise_error(ArgumentError)
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
        expect(system_service.start_modes).to eq([:on_boot, :on_demand, :manual])
      end
    end

    context "when no associated socket exists" do
      let(:socket) { nil }

      it "returns :on_boot and :manual" do
        expect(system_service.start_modes).to eq([:on_boot, :manual])
      end
    end
  end

  describe "#socket?" do
    before do
      allow(system_service).to receive(:socket).and_return(socket)
    end

    context "when there is an associated socket" do
      let(:socket) { double("socket") }

      it "returns true" do
        expect(system_service.socket?).to eq(true)
      end
    end

    context "when there is no associated socket" do
      let(:socket) { nil }

      it "returns false" do
        expect(system_service.socket?).to eq(false)
      end
    end
  end
end
