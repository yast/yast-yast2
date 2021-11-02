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
require "y2packager/software_manager"

describe Y2Packager::SoftwareManager do
  subject(:software) do
    described_class.new([backend])
  end

  let(:backend) do
    instance_double(Y2Packager::LibzyppBackend, repositories: [repo])
  end

  let(:repo) do
    instance_double(Y2Packager::Repository)
  end

  describe ".current" do
    before { described_class.reset }

    it "creates a SoftwareManagement instance" do
      expect(described_class.current).to be_a(Y2Packager::SoftwareManager)
    end

    context "when called twice" do
      it "returns the same instance" do
        software0 = described_class.current
        software1 = described_class.current
        expect(software0).to be(software1)
      end
    end
  end

  describe "#repositories" do
    it "returns repositories from all backends" do
      expect(software.repositories).to eq([repo])
    end
  end

  describe "#probe" do
    it "calls the probe method of each backend" do
      expect(backend).to receive(:probe)
      software.probe
    end
  end
end
