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

      DUMP("IP::UndecorateIPv6")
      TEST(IP.UndecorateIPv6("fe80::219:d1ff:feac:fd10"), [], nil)
      TEST(IP.UndecorateIPv6("[::1]"), [], nil)
      TEST(IP.UndecorateIPv6("fe80::3%eth0"), [], nil)
      TEST(IP.UndecorateIPv6("[fe80::3%eth0]"), [], nil)

      DUMP("IP::ComputeNetwork")
      TEST(->() { IP.ComputeNetwork("127.0.0.1", "255.0.0.0") }, [], nil)
      TEST(->() { IP.ComputeNetwork("192.168.110.23", "255.255.255.0") }, [], nil)
      TEST(->() { IP.ComputeNetwork("10.20.1.29", "255.255.240.0") }, [], nil)

      DUMP("IP::ComputeBroadcast")
      TEST(->() { IP.ComputeBroadcast("127.0.0.1", "255.0.0.0") }, [], nil)
      TEST(->() { IP.ComputeBroadcast("192.168.110.23", "255.255.255.0") }, [], nil)
      TEST(->() { IP.ComputeBroadcast("10.20.1.29", "255.255.240.0") }, [], nil)

      DUMP("IP::CheckNetwork4 -> true")
      TEST(->() { IP.CheckNetwork4("192.168.0.1") }, [], nil)
      TEST(->() { IP.CheckNetwork4("192.168.0.255") }, [], nil)
      TEST(->() { IP.CheckNetwork4("192.168.0.1/20") }, [], nil)
      TEST(->() { IP.CheckNetwork4("192.168.0.255/32") }, [], nil)
      TEST(->() { IP.CheckNetwork4("192.168.0.1/255.240.0.0") }, [], nil)
      TEST(->() { IP.CheckNetwork4("192.168.0.255/255.255.255.255") }, [], nil)
      TEST(->() { IP.CheckNetwork4("192.168.0.1/0") }, [], nil)
      TEST(->() { IP.CheckNetwork4("172.55.0.0/1") }, [], nil)
      TEST(->() { IP.CheckNetwork4("0/0") }, [], nil)
      TEST(->() { IP.CheckNetwork4("255.255.255.255/255.255.255.255") }, [], nil)

      DUMP("IP::CheckNetwork4 -> false")
      TEST(->() { IP.CheckNetwork4("") }, [], nil)
      TEST(->() { IP.CheckNetwork4("172.55.0.0/33") }, [], nil)
      TEST(->() { IP.CheckNetwork4("256.168.0.255") }, [], nil)
      TEST(->() { IP.CheckNetwork4("172.55.0.0/125.85.5.5") }, [], nil)
      TEST(->() { IP.CheckNetwork4("192.168.0.255/5.5.5") }, [], nil)
      TEST(->() { IP.CheckNetwork4("192.168.0.255/255.255.0.255") }, [], nil)

      DUMP("IP::CheckNetwork6 -> true")
      TEST(->() { IP.CheckNetwork6("FE80:0000:0000:0000:0202:B3FF:FE1E:8329") }, [], nil)
      TEST(->() { IP.CheckNetwork6("2001:db8:0::1") }, [], nil)
      TEST(->() { IP.CheckNetwork6("2000::/3") }, [], nil)
      TEST(->() { IP.CheckNetwork6("2001:db8:0::1/56") }, [], nil)
      TEST(->() { IP.CheckNetwork6("2001:db8:0::1/64") }, [], nil)
      TEST(->() { IP.CheckNetwork6("2001:db8:0::1/ffff::0") }, [], nil)
      TEST(->() { IP.CheckNetwork6("2001:db8:0::1/ffff:ffff::0") }, [], nil)
      TEST(->() { IP.CheckNetwork6("::1/128") }, [], nil)
      TEST(->() { IP.CheckNetwork6("0/0") }, [], nil)

      DUMP("IP::CheckNetwork6 -> false")
      TEST(->() { IP.CheckNetwork6("") }, [], nil)
      TEST(lambda do
        IP.CheckNetwork6("FE80:0000:0000:0000:0202:B3FF:FE1E:8329:0000")
      end, [], nil)
      TEST(->() { IP.CheckNetwork6("2001:db8:0::xyz") }, [], nil)
      TEST(->() { IP.CheckNetwork6("::1/257") }, [], nil)
      TEST(->() { IP.CheckNetwork6("::1/") }, [], nil)
      TEST(->() { IP.CheckNetwork6("2001:db8:0::1/ffff:xyz::0") }, [], nil)

      DUMP("IP::CheckNetwork -> true")
      TEST(->() { IP.CheckNetwork("192.168.0.1") }, [], nil)
      TEST(->() { IP.CheckNetwork("172.55.0.0/1") }, [], nil)
      TEST(->() { IP.CheckNetwork("2001:db8:0::1") }, [], nil)
      TEST(->() { IP.CheckNetwork("2001:db8:0::1/ffff::0") }, [], nil)

      DUMP("IP::CheckNetwork -> false")
      TEST(->() { IP.CheckNetwork("256.168.0.255") }, [], nil)
      TEST(->() { IP.CheckNetwork("192.168.0.255/5.5.5") }, [], nil)
      TEST(->() { IP.CheckNetwork("2001:db8:0::xyz") }, [], nil)
      TEST(->() { IP.CheckNetwork("2001:db8:0::1/ffff:xyz::0") }, [], nil)

      nil
    end
  end
end

Yast::IPClient.new.main
