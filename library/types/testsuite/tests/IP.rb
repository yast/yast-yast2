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
module Yast
  class IPClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "IP"

      DUMP("IP::Check4")
      TEST(lambda { IP.Check4(nil) }, [], nil)
      TEST(lambda { IP.Check4("") }, [], nil)
      TEST(lambda { IP.Check4("A.1.2.3") }, [], nil)
      TEST(lambda { IP.Check4("1.2.3") }, [], nil)
      TEST(lambda { IP.Check4("1..2.34") }, [], nil)
      TEST(lambda { IP.Check4("1. .2.34") }, [], nil)
      TEST(lambda { IP.Check4("255.255.256.255") }, [], nil)
      TEST(lambda { IP.Check4("127") }, [], nil)
      TEST(lambda { IP.Check4("----------") }, [], nil)
      TEST(lambda { IP.Check4("127.0.0.1") }, [], nil)
      TEST(lambda { IP.Check4("255.255.255.0") }, [], nil)
      TEST(lambda { IP.Check4("255.255.255.255") }, [], nil)
      TEST(lambda { IP.Check4("192.168.0.1") }, [], nil)
      TEST(lambda { IP.Check4("195.113.31.123") }, [], nil)
      TEST(lambda { IP.Check4("255.0.0.1") }, [], nil)
      TEST(lambda { IP.Check4("10.20.1.29") }, [], nil)
      TEST(lambda { IP.Check4("1.2.3.4") }, [], nil)
      TEST(lambda { IP.Check4("0.0.0.0") }, [], nil)

      DUMP("IP::Check6")
      TEST(lambda { IP.Check6(nil) }, [], nil)
      TEST(lambda { IP.Check6("") }, [], nil)
      TEST(lambda { IP.Check6("----------") }, [], nil)
      TEST(lambda { IP.Check6("1:1:1:01:1:1:1:1") }, [], nil)
      TEST(lambda { IP.Check6("fec0:1:2:0:200:1cff:feb5:a7ea") }, [], nil)
      TEST(lambda { IP.Check6("fe80::200:1cff:feb5:a7ea") }, [], nil)
      TEST(lambda { IP.Check6("fe80::1cb5:a7ea") }, [], nil)

      TEST(lambda { IP.Check6("1:2:3:4:5:6:7:8") }, [], nil)
      TEST(lambda { IP.Check6("::3:4:5:6:7:8") }, [], nil)
      TEST(lambda { IP.Check6("1:2:3:4:5:6::") }, [], nil)
      TEST(lambda { IP.Check6("1:2::4:5:6:7:8") }, [], nil)
      TEST(lambda { IP.Check6("1::3:4:5:6:7:8") }, [], nil)
      TEST(lambda { IP.Check6("1:2:3:4:5:6::8") }, [], nil)
      TEST(lambda { IP.Check6("1:2:3::8") }, [], nil)
      TEST(lambda { IP.Check6("::1") }, [], nil)
      TEST(lambda { IP.Check6("::1:2") }, [], nil)
      TEST(lambda { IP.Check6("1:2::") }, [], nil)
      TEST(lambda { IP.Check6("1::") }, [], nil)

      TEST(lambda { IP.Check6("0::") }, [], nil)
      TEST(lambda { IP.Check6("0000::") }, [], nil)
      TEST(lambda { IP.Check6("0:1::") }, [], nil)
      TEST(lambda { IP.Check6("1:0::") }, [], nil)
      TEST(lambda { IP.Check6("1:0::0") }, [], nil)

      TEST(lambda { IP.Check6("fe80::200:1cff:feb5:5433") }, [], nil)

      TEST(lambda { IP.Check6(":2:3:4:5:6:7:8") }, [], nil)
      TEST(lambda { IP.Check6("1:2:3:4:5:6:7:") }, [], nil)
      TEST(lambda { IP.Check6("1::3:4::6:7:8") }, [], nil)
      TEST(lambda { IP.Check6("1:2:3:4:5:6:7:8:9") }, [], nil)
      TEST(lambda { IP.Check6("1:2:3:4::5:6:7:8:9") }, [], nil)

      DUMP("IP::UndecorateIPv6")
      TEST(IP.UndecorateIPv6("fe80::219:d1ff:feac:fd10"), [], nil)
      TEST(IP.UndecorateIPv6("[::1]"), [], nil)
      TEST(IP.UndecorateIPv6("fe80::3%eth0"), [], nil)
      TEST(IP.UndecorateIPv6("[fe80::3%eth0]"), [], nil)


      DUMP("IP::ToInteger")
      TEST(lambda { IP.ToInteger("0.0.0.0") }, [], nil)
      TEST(lambda { IP.ToInteger("127.0.0.1") }, [], nil)
      TEST(lambda { IP.ToInteger("192.168.110.23") }, [], nil)
      TEST(lambda { IP.ToInteger("10.20.1.29") }, [], nil)

      DUMP("IP::ToString")
      TEST(lambda { IP.ToString(0) }, [], nil)
      TEST(lambda { IP.ToString(2130706433) }, [], nil)
      TEST(lambda { IP.ToString(3232263703) }, [], nil)
      TEST(lambda { IP.ToString(169083165) }, [], nil)

      DUMP("IP::ToHex")
      TEST(lambda { IP.ToHex("0.0.0.0") }, [], nil)
      TEST(lambda { IP.ToHex("10.10.0.1") }, [], nil)
      TEST(lambda { IP.ToHex("192.168.1.1") }, [], nil)
      TEST(lambda { IP.ToHex("255.255.255.255") }, [], nil)

      DUMP("IP::ComputeNetwork")
      TEST(lambda { IP.ComputeNetwork("127.0.0.1", "255.0.0.0") }, [], nil)
      TEST(lambda { IP.ComputeNetwork("192.168.110.23", "255.255.255.0") }, [], nil)
      TEST(lambda { IP.ComputeNetwork("10.20.1.29", "255.255.240.0") }, [], nil)

      DUMP("IP::ComputeBroadcast")
      TEST(lambda { IP.ComputeBroadcast("127.0.0.1", "255.0.0.0") }, [], nil)
      TEST(lambda { IP.ComputeBroadcast("192.168.110.23", "255.255.255.0") }, [], nil)
      TEST(lambda { IP.ComputeBroadcast("10.20.1.29", "255.255.240.0") }, [], nil)

      DUMP("IP::CheckNetwork4 -> true")
      TEST(lambda { IP.CheckNetwork4("192.168.0.1") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("192.168.0.255") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("192.168.0.1/20") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("192.168.0.255/32") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("192.168.0.1/255.240.0.0") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("192.168.0.255/255.255.255.255") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("192.168.0.1/0") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("172.55.0.0/1") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("0/0") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("255.255.255.255/255.255.255.255") }, [], nil)

      DUMP("IP::CheckNetwork4 -> false")
      TEST(lambda { IP.CheckNetwork4("") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("172.55.0.0/33") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("256.168.0.255") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("172.55.0.0/125.85.5.5") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("192.168.0.255/5.5.5") }, [], nil)
      TEST(lambda { IP.CheckNetwork4("192.168.0.255/255.255.0.255") }, [], nil)

      DUMP("IP::CheckNetwork6 -> true")
      TEST(lambda { IP.CheckNetwork6("FE80:0000:0000:0000:0202:B3FF:FE1E:8329") }, [], nil)
      TEST(lambda { IP.CheckNetwork6("2001:db8:0::1") }, [], nil)
      TEST(lambda { IP.CheckNetwork6("2000::/3") }, [], nil)
      TEST(lambda { IP.CheckNetwork6("2001:db8:0::1/56") }, [], nil)
      TEST(lambda { IP.CheckNetwork6("2001:db8:0::1/64") }, [], nil)
      TEST(lambda { IP.CheckNetwork6("2001:db8:0::1/ffff::0") }, [], nil)
      TEST(lambda { IP.CheckNetwork6("2001:db8:0::1/ffff:ffff::0") }, [], nil)
      TEST(lambda { IP.CheckNetwork6("::1/128") }, [], nil)
      TEST(lambda { IP.CheckNetwork6("0/0") }, [], nil)

      DUMP("IP::CheckNetwork6 -> false")
      TEST(lambda { IP.CheckNetwork6("") }, [], nil)
      TEST(lambda do
        IP.CheckNetwork6("FE80:0000:0000:0000:0202:B3FF:FE1E:8329:0000")
      end, [], nil)
      TEST(lambda { IP.CheckNetwork6("2001:db8:0::xyz") }, [], nil)
      TEST(lambda { IP.CheckNetwork6("::1/257") }, [], nil)
      TEST(lambda { IP.CheckNetwork6("::1/") }, [], nil)
      TEST(lambda { IP.CheckNetwork6("2001:db8:0::1/ffff:xyz::0") }, [], nil)

      DUMP("IP::CheckNetwork -> true")
      TEST(lambda { IP.CheckNetwork("192.168.0.1") }, [], nil)
      TEST(lambda { IP.CheckNetwork("172.55.0.0/1") }, [], nil)
      TEST(lambda { IP.CheckNetwork("2001:db8:0::1") }, [], nil)
      TEST(lambda { IP.CheckNetwork("2001:db8:0::1/ffff::0") }, [], nil)

      DUMP("IP::CheckNetwork -> false")
      TEST(lambda { IP.CheckNetwork("256.168.0.255") }, [], nil)
      TEST(lambda { IP.CheckNetwork("192.168.0.255/5.5.5") }, [], nil)
      TEST(lambda { IP.CheckNetwork("2001:db8:0::xyz") }, [], nil)
      TEST(lambda { IP.CheckNetwork("2001:db8:0::1/ffff:xyz::0") }, [], nil)

      nil
    end
  end
end

Yast::IPClient.new.main
