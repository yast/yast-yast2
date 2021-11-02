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

require_relative "../test_helper"
require "y2packager/software_search"
require "y2packager/backend"

describe Y2Packager::SoftwareSearch do
  subject(:search) { described_class.new(backend) }

  let(:backend) do
    instance_double(Y2Packager::Backend)
  end

  describe "#with" do
    it "sets conditions" do
      search.with(name: "yast2-packager")
      expect(search.conditions).to eq(name: "yast2-packager")
    end
  end

  describe "#named" do
    it "sets a condition on the name" do
      search.named("yast2")
      expect(search.conditions).to eq(name: "yast2")
    end
  end

  describe "#including" do
    it "adds a property to the list of properties to include" do
      expect(search.properties).to_not include(:description)
      search.including(:description)
      expect(search.properties).to include(:description)
    end
  end

  describe "#excluding" do
    it "adds a property to the list of properties to exclude" do
      expect(search.properties).to include(:name)
      search.excluding(:name)
      expect(search.properties).to_not include(:name)
    end
  end

  describe "#to_a" do
    let(:package) { double("yast2") }

    it "asks the backend an returns the result" do
      search.with(name: "SLES")

      expect(backend).to receive(:search)
        .with(
          conditions: { name: "SLES" },
          properties: array_including(:kind, :name, :version, :arch, :source)
        )
        .and_return([package])
      expect(search.to_a).to eq([package])
    end
  end
end
