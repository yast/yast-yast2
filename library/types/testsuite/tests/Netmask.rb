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
  class NetmaskClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "Netmask"

      DUMP("Netmask::Check4")
      TEST(lambda { Netmask.Check4("128.0.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("192.0.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("224.0.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("240.0.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("248.0.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("252.0.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("254.0.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.0.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.128.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.192.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.224.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.240.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.248.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.252.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.254.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.0.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.128.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.192.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.224.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.240.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.248.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.252.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.254.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.255.0") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.255.128") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.255.192") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.255.224") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.255.240") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.255.248") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.255.252") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.255.254") }, [], nil)
      TEST(lambda { Netmask.Check4("255.255.255.255") }, [], nil)
      TEST(lambda { Netmask.Check4("1.2.3.4") }, [], nil)
      TEST(lambda { Netmask.Check4("1.A.3.4") }, [], nil)
      TEST(lambda { Netmask.Check4("0.0.0.0") }, [], nil)

      TEST(lambda { Netmask.CheckPrefix4(nil) }, [], nil)
      TEST(lambda { Netmask.CheckPrefix4("") }, [], nil)
      TEST(lambda { Netmask.CheckPrefix4("33") }, [], nil)
      TEST(lambda { Netmask.CheckPrefix4("0") }, [], nil)
      TEST(lambda { Netmask.CheckPrefix4("24") }, [], nil)
      TEST(lambda { Netmask.CheckPrefix4("32") }, [], nil)

      DUMP("Netmask::Check6")
      TEST(lambda { Netmask.Check6(nil) }, [], nil)
      TEST(lambda { Netmask.Check6("") }, [], nil)
      TEST(lambda { Netmask.Check6("345") }, [], nil)
      TEST(lambda { Netmask.Check6("128") }, [], nil)

      @i = nil
      DUMP("Netmask::FromBits")
      @i = 32
      while Ops.greater_or_equal(@i, 0)
        TEST(lambda { Netmask.FromBits(@i) }, [], nil)
        @i = Ops.subtract(@i, 1)
      end

      # this test relies on the previous one
      DUMP("Netmask::ToBits")
      @i = 32
      while Ops.greater_or_equal(@i, 0)
        TEST(lambda { Netmask.ToBits(Netmask.FromBits(@i)) }, [], nil)
        @i = Ops.subtract(@i, 1)
      end
      TEST(lambda { Netmask.ToBits("") }, [], nil)

      nil
    end
  end
end

Yast::NetmaskClient.new.main
