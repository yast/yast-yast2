#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2021] SUSE LLC
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
require "yast2/issues/issue"

describe Yast2::Issues::Issue do
  describe "#new" do
    subject(:issue) do
      described_class.new(
        "Something went wrong", location: "file:/etc/hosts", severity: :fatal
      )
    end

    it "creates an issue" do
      expect(issue.message).to eq("Something went wrong")
      expect(issue.location.to_s).to eq("/etc/hosts")
      expect(issue.severity).to eq(:fatal)
    end

    context "when a severity is not given" do
      subject(:issue) { described_class.new("Something went wrong") }

      it "sets the severity to :warn" do
        expect(issue.severity).to eq(:warn)
      end
    end
  end

  describe "#fatal?" do
    context "when severity is :fatal" do
      subject(:issue) { described_class.new("Something went wrong", severity: :fatal) }

      it "returns true" do
        expect(issue.fatal?).to eq(true)
      end
    end


    context "when severity is :fatal" do
      subject(:issue) { described_class.new("Something went wrong", severity: :warn) }

      it "returns false" do
        expect(issue.fatal?).to eq(false)
      end
    end
  end
end
