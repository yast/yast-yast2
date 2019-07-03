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

require_relative "test_helper"

Yast.import "Desktop"

describe Yast::Desktop do
  describe "#Modules" do
    around { |e| change_scr_root(DESKTOP_DATA_PATH, &e) }

    before do
      Yast::Desktop.Read(["Name"])
    end

    it "returns modules information using the short name as key" do
      expect(Yast::Desktop.Modules).to eq(
        {
          "add-on"           => { "Name" => "YaST Add-On Products"},
          "lan"              => { "Name" => "YaST Network" },
          "services-manager" => { "Name" => "YaST Services Manager" }
        }
      )
    end
  end
end
