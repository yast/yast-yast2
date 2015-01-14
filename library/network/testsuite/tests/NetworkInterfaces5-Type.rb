# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2002 - 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# ***************************************************************************
# bnc#704999
module Yast
  class NetworkInterfaces5TypeClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "Assert"
      Yast.import "NetworkInterfaces"

      @mybond = {
        "BOOTPROTO"       => "dhcp",
        "BONDING_MASTER"  => "yes",
        "BONDING_SLAVE_0" => "eth0",
        "BONDING_SLAVE_1" => "eth1"
      }

      @mybridged = {
        "BOOTPROTO"    => "dhcp",
        "BRIDGE"       => "yes",
        "BRIDGE_PORTS" => "eth0 tap0"
      }

      @myvirt = { "BOOTPROTO" => "static", "TUNNEL" => "tap" }

      DUMP("NetworkInterfaces::GetTypeFromIfcfg")
      TEST(lambda do
        Assert.Equal("bond", NetworkInterfaces.GetTypeFromIfcfg(@mybond))
      end, [], nil)
      TEST(lambda do
        Assert.Equal("br", NetworkInterfaces.GetTypeFromIfcfg(@mybridged))
      end, [], nil)
      TEST(lambda do
        Assert.Equal("tap", NetworkInterfaces.GetTypeFromIfcfg(@myvirt))
      end, [], nil) 

      # EOF

      nil
    end
  end
end

Yast::NetworkInterfaces5TypeClient.new.main
