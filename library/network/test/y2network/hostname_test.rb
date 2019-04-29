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
require "y2network/hostname"

describe Y2Network::Hostname do
  let(:hostname) { described_class.new(fqdn: "server.example.org")}

  describe "#short" do
    it "returns the short part of the hostname" do
      expect(hostname.short).to eq("server")
    end
  end

  describe "#fqdn" do
    it "returns the hostname FQDN" do
      expect(hostname.fqdn).to eq("server.example.org")
    end
  end

  describe "#domain" do
    it "returns the domain part of the Hostname" do
      expect(hostname.domain).to eq("example.org")
    end
  end
end

