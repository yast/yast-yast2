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

require_relative "../test_helper"
require "y2firewall/firewalld"

Yast.import "PackageSystem"
Yast.import "Service"

describe Y2Firewall::Firewalld do
  let(:firewalld) { described_class.instance }

  describe "#installed?" do
    it "returns true it the firewalld is installed" do
      allow(Yast::PackageSystem).to receive("Installed")
        .with(described_class::PACKAGE).and_return true
      expect(firewalld.installed?).to eq(true)
    end
  end

  describe "#enabled?" do
    it "returns true if the firewalld service is enable" do
      allow(Yast::Service).to receive("Enabled")
        .with(described_class::SERVICE).and_return(false)

      expect(firewalld.enabled?).to eq(false)
    end
  end

  describe "#restart" do
    it "returns false if the service is not installed" do
      allow(firewalld).to receive("installed?").and_return false

      firewalld.restart
    end

    it "restarts the firewalld service" do
      expect(Yast::Service).to receive("Restart").with(described_class::SERVICE)

      firewalld.restart
    end
  end

  describe "#start" do
    it "returns false if the service is not installed" do
      allow(firewalld).to receive("installed?").and_return false

      firewalld.start
    end

    it "returns false if the service is not running" do
      allow(firewalld).to receive("running?").and_return false

      firewalld.start
    end
    it "starts the firewalld service" do
      expect(Yast::Service).to receive("Start").with(described_class::SERVICE)

      firewalld.start
    end
  end

  describe "#stop" do
    before do
      allow(firewalld).to receive("installed?").and_return true
      allow(firewalld).to receive("running?").and_return true
    end

    it "returns false if the service is not installed" do
      allow(firewalld).to receive("installed?").and_return false

      firewalld.stop
    end

    it "returns false if the service is not running" do
      allow(firewalld).to receive("running?").and_return false

      firewalld.stop
    end

    it "stops the firewalld service" do
      expect(Yast::Service).to receive("Stop").with(described_class::SERVICE)

      firewalld.stop
    end
  end

  describe "#api" do
    it "returns an Y2Firewall::Firewalld::Api instance" do
      expect(firewalld.api).to be_a Y2Firewall::Firewalld::Api
    end
  end

  describe "#running" do
    it "returns true if the service is running" do
      expect(firewalld.api).to receive(:running?).and_return(true)

      firewalld.running?
    end
  end
end
