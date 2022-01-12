#!/usr/bin/env rspec
# Copyright (c) [2020] SUSE LLC
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
require "installation/autoinst_issues/invalid_value"

describe Installation::AutoinstIssues::InvalidValue do
  subject(:issue) do
    described_class.new("firewall", "interfaces", "eth0",
      "This interface has been defined for more than one zone.", :fatal)
  end

  describe "#message" do
    it "includes relevant information" do
      message = issue.message
      expect(message).to include "interfaces"
      expect(message).to include "eth0"
    end
  end

  describe "#severity which has been set to :fatal while initialization" do
    it "returns :fatal" do
      expect(issue.severity).to eq(:fatal)
    end
  end
end
