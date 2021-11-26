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

require_relative "test_helper"

Yast.import "PackageAI"

describe Yast::PackageAI do
  subject { Yast::PackageAI }

  before do
    Yast::PackagesProposal.ResetAll
  end

  describe "#DoInstallAndRemove" do
    it "updates the packages proposal according to the given lists" do
      subject.DoInstallAndRemove(["yast2"], ["ntpd"])

      expect(Yast::PackagesProposal.GetResolvables("autoyast", :package)).to eq(["yast2"])
      expect(Yast::PackagesProposal.GetTaboos("autoyast")).to eq(["ntpd"])
    end
  end
end
