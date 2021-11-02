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
require "y2packager/installation_package_map"

describe Y2Packager::InstallationPackageMap do
  describe "#packages_map" do
    before do
      allow(Yast::Pkg).to receive(:PkgQueryProvides).with("system-installation()").and_return(
        # the first is the old product which will be removed from the system
        [["openSUSE-release", :CAND, :NONE], ["openSUSE-release", :CAND, :CAND]]
      )
      allow(Yast::Pkg).to receive(:Resolvables).with({ name: "openSUSE-release", kind: :package },
        [:dependencies, :status]).and_return(
          [
            {
              # emulate an older system with no "system-installation()" provides
              "deps"   => [],
              # put the removed product first so we can check it is skipped
              "status" => :removed
            },
            {
              # in reality there are many more dependencies, but they are irrelevant for this test
              "deps"   => [{ "provides" => "system-installation() = openSUSE" }],
              "status" => :selected
            }
          ]
        )
    end

    it "prefers the data from the new available product instead of the old installed one" do
      expect(subject.for("openSUSE")).to eq("openSUSE-release")
      # expect(described_class.installation_package_mapping).to eq("openSUSE" => "openSUSE-release")
    end
  end
end
