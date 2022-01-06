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
require "installation/autoinst_issues/missing_value"

describe Installation::AutoinstIssues::MissingValue do
  subject(:issue) { described_class.new("foo", "bar") }

  describe "#message" do
    it "returns a description of the issue" do
      expect(issue.message).to match(/Missing element 'bar'/)
    end
  end

  describe "#severity" do
    it "returns :warn as default" do
      expect(issue.severity).to eq(:warn)
    end
  end
end
