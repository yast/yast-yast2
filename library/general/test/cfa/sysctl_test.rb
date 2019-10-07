#!/usr/bin/env rspec

# Copyright (c) [2019] SUSE LLC
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
require "cfa/sysctl"

describe CFA::Sysctl do
  subject(:sysctl) { described_class.new(file_handler: file_handler) }

  let(:yast_conf_path) { "sysctl-yast.conf" }
  let(:file_handler) { File }

  SYSCTL_CONF_VALUES = {
    ".etc.sysctl_conf.\"net.ipv4.ip_forward\""          => "0",
    ".etc.sysctl_conf.\"net.ipv6.conf.all.forwarding\"" => "0",
    ".etc.sysctl_conf.\"kernel.sysrq\""                 => "0",
    ".etc.sysctl_conf.\"net.ipv4.tcp_syncookies\""      => "1"
  }.freeze

  before do
    allow(Yast::SCR).to receive(:Read) do |path|
      SYSCTL_CONF_VALUES[path.to_s]
    end
    allow(Yast::TargetFile).to receive(:write).with("/etc/sysctl.conf", anything)
    stub_const("CFA::Sysctl::PATH", File.join(GENERAL_DATA_PATH, yast_conf_path))
    sysctl.load
  end

  describe "#raw_forward_ipv4" do
    it "returns IPv4 forwarding raw value" do
      expect(sysctl.raw_forward_ipv4).to eq("1")
    end

    context "when the value is not defined" do
      let(:yast_conf_path) { "empty" }

      it "returns the value from sysctl.conf" do
        expect(sysctl.raw_forward_ipv4).to eq("0")
      end
    end
  end

  describe "#raw_forward_ipv6" do
    it "returns IPv6 forwarding raw value" do
      expect(sysctl.raw_forward_ipv6).to eq("1")
    end

    context "when the value is not defined" do
      let(:yast_conf_path) { "empty" }

      it "returns the value from sysctl.conf" do
        expect(sysctl.raw_forward_ipv6).to eq("0")
      end
    end
  end

  describe "#forward_ipv4=" do
    it "sets the forward_ipv4 value" do
      expect { sysctl.forward_ipv4 = false }.to change { sysctl.forward_ipv4 }.from(true).to(false)
    end
  end

  describe "#forward_ipv6=" do
    it "sets the forward_ipv6 value" do
      expect { sysctl.forward_ipv6 = false }.to change { sysctl.forward_ipv6 }.from(true).to(false)
    end
  end

  describe "#kernel_sysrq" do
    it "returns kernel.sysrq value" do
      expect(sysctl.kernel_sysrq).to eq("1")
    end

    context "when the value is not defined" do
      let(:yast_conf_path) { "empty" }

      it "returns the value from sysctl.conf" do
        expect(sysctl.kernel_sysrq).to eq("0")
      end
    end
  end

  describe "#kernel_sysrq=" do
    it "sets the kernel.sysrq value" do
      expect { sysctl.kernel_sysrq = "0" }.to change { sysctl.kernel_sysrq }.from("1").to("0")
    end
  end

  describe "#save" do
    before do
      allow(Yast::SCR).to receive(:Write)
      allow(Yast::TargetFile).to receive(:read).with("/etc/sysctl.conf")
        .and_return("# Some comment\nkernel.sysrq=1")
    end

    it "writes changes to configuration file" do
      expect(file_handler).to receive(:write)
        .with(CFA::Sysctl::PATH, /.+ip_forward = 1.+forwarding = 1/m)
      sysctl.save
    end

    it "removes the old values from /etc/sysctl.conf" do
      expect(Yast::TargetFile).to receive(:write).with("/etc/sysctl.conf", "# Some comment\n")
      sysctl.save
    end

    it "does not update missing values in /etc/sysctl.conf" do
      expect(Yast::SCR).to_not receive(:Write)
        .with(Yast::Path.new(".etc.sysctl_conf.\"net.ipv4.conf.all.forwarding\""), anything)
      sysctl.save
    end

    it "does not try to update unchanged values in /etc/sysctl.conf" do
      expect(Yast::SCR).to_not receive(:Write)
        .with(Yast::Path.new(".etc.sysctl_conf.\"net.ipv4.tcp_syncookies\""), anything)
      sysctl.save
    end
  end

  describe "#forward_ipv4?" do
    before { sysctl.forward_ipv4 = value }

    context "when forwarding for IPv4 is enabled" do
      let(:value) { true }

      it "returns true" do
        expect(sysctl.forward_ipv4?).to eq(true)
      end
    end

    context "when forwarding for IPv4 is disabled" do
      let(:value) { false }

      it "returns false" do
        expect(sysctl.forward_ipv4?).to eq(false)
      end
    end
  end

  describe "#forward_ipv6?" do
    before { sysctl.forward_ipv6 = value }

    context "when forwarding for IPv6 is enabled" do
      let(:value) { true }

      it "returns true" do
        expect(sysctl.forward_ipv6?).to eq(true)
      end
    end

    context "when forwarding for IPv6 is disabled" do
      let(:value) { false }

      it "returns false" do
        expect(sysctl.forward_ipv6?).to eq(false)
      end
    end
  end

  describe "#tcp_syncookies?" do
    before { sysctl.tcp_syncookies = value }

    context "when TCP syncookies are enabled" do
      let(:value) { true }

      it "returns true" do
        expect(sysctl.tcp_syncookies?).to eq(true)
      end
    end

    context "when TCP syncookies are disabled" do
      let(:value) { false }

      it "returns false" do
        expect(sysctl.tcp_syncookies?).to eq(false)
      end
    end
  end

  describe "#disable_ipv6?" do
    before { sysctl.disable_ipv6 = value }

    context "when IPv6 is disabled" do
      let(:value) { true }

      it "returns true" do
        expect(sysctl.disable_ipv6?).to eq(true)
      end
    end

    context "when IPv6 is not disabled" do
      let(:value) { false }

      it "returns false" do
        expect(sysctl.disable_ipv6?).to eq(false)
      end
    end
  end
end
