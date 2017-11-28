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

require_relative "../../test_helper"
require "y2firewall/firewalld/zone"

describe Y2Firewall::Firewalld::Zone do
  describe ".known_zones" do
    it "returns a hash with known zone names and descriptions" do
      expect(described_class.known_zones).to be_a(Hash)
      expect(described_class.known_zones).to include "public"
      expect(described_class.known_zones["dmz"]).to eq(N_("Demilitarized Zone"))
    end
  end
end
