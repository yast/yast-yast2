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

require_relative "../../test_helper"
require "yast2/cfa/sysctl"

describe Yast2::CFA::Sysctl do
  subject(:sysctl) { described_class.new(file_handler: file_handler) }

  let(:old_forward_ipv4) { "0" }
  let(:old_forward_ipv6) { "0" }
  let(:yast_conf_path) { "sysctl-yast.conf" }
  let(:file_handler) { File }

  SYSCTL_CONF_VALUES = {
    ".etc.sysctl_conf.\"net.ipv4.ip_forward\""          => "0",
    ".etc.sysctl_conf.\"net.ipv6.conf.all.forwarding\"" => "0",
    ".etc.sysctl_conf.\"kernel.sysrq\""                 => "0",
    ".etc.sysctl_conf.\"net.ipv4.tcp_syncookies\""      => "0"
  }.freeze

  before do
    allow(Yast::SCR).to receive(:Read) do |path|
      SYSCTL_CONF_VALUES[path.to_s] or raise("path not defined: #{path}")
    end
    stub_const("Yast2::CFA::Sysctl::PATH", File.join(GENERAL_DATA_PATH, yast_conf_path))
    sysctl.load
  end

  describe "#forward_ipv4" do
    it "returns IPv4 forwarding value" do
      expect(sysctl.forward_ipv4).to eq("1")
    end

    context "when the value is not defined" do
      let(:yast_conf_path) { "empty" }

      it "returns the value from sysctl.conf" do
        expect(sysctl.forward_ipv4).to eq("0")
      end
    end
  end

  describe "#forward_ipv6" do
    it "returns IPv6 forwarding value" do
      expect(sysctl.forward_ipv6).to eq("1")
    end

    context "when the value is not defined" do
      let(:yast_conf_path) { "empty" }

      it "returns the value from sysctl.conf" do
        expect(sysctl.forward_ipv6).to eq("0")
      end
    end
  end

  describe "#forward_ipv4=" do
    it "sets the forward_ipv4 value" do
      expect { sysctl.forward_ipv4 = "0" }.to change { sysctl.forward_ipv4 }.from("1").to("0")
    end
  end

  describe "#forward_ipv6=" do
    it "sets the forward_ipv6 value" do
      expect { sysctl.forward_ipv6 = "0" }.to change { sysctl.forward_ipv6 }.from("1").to("0")
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
    end

    it "writes changes to configuration file" do
      expect(file_handler).to receive(:write)
        .with(Yast2::CFA::Sysctl::PATH, /.+ip_forward = 1.+forwarding = 1/m)
      sysctl.save
    end

    it "removes the old values from /etc/sysctl.conf" do
      expect(Yast::SCR).to receive(:Write)
        .with(Yast::Path.new(".etc.sysctl_conf.\"net.ipv4.ip_forward\""), nil)
      expect(Yast::SCR).to receive(:Write)
        .with(Yast::Path.new(".etc.sysctl_conf.\"net.ipv6.conf.all.forwarding\""), nil)
      expect(Yast::SCR).to receive(:Write)
        .with(Yast::Path.new(".etc.sysctl_conf"), nil)
      sysctl.save
    end
  end
end
