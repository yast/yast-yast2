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
  class HostnameClient < Client
    def main
      Yast.include self, "testsuite.rb"
      @READ = { "target" => { "tmpdir" => "/tmp" } }
      TESTSUITE_INIT([@READ], nil)
      Yast.import "Hostname"

      DUMP("Hostname::Check")
      TEST(->() { Hostname.Check(nil) }, [], nil)
      TEST(->() { Hostname.Check("") }, [], nil)
      TEST(->() { Hostname.Check("A_B87126") }, [], nil)
      TEST(->() { Hostname.Check("ahoj.joha") }, [], nil)
      TEST(->() { Hostname.Check("ahoj joha") }, [], nil)
      TEST(lambda do
        Hostname.Check(
          "ABC-012345678901234567890123456789012345678901234567890123456789"
        )
      end, [], nil)
      TEST(->() { Hostname.Check("----------") }, [], nil)
      DUMP("----------")
      TEST(->() { Hostname.Check("8abc") }, [], nil)
      TEST(->() { Hostname.Check("ahoj") }, [], nil)
      TEST(->() { Hostname.Check("aHoJ") }, [], nil)
      TEST(->() { Hostname.Check("A-B87126") }, [], nil)
      TEST(->() { Hostname.Check("A0123456789") }, [], nil)
      TEST(lambda do
        Hostname.Check(
          "AB-012345678901234567890123456789012345678901234567890123456789"
        )
      end, [], nil)
      TEST(->() { Hostname.Check("abc-") }, [], nil)
      TEST(->() { Hostname.Check("123") }, [], nil)

      DUMP("Hostname::CheckFQ")
      TEST(->() { Hostname.CheckFQ("www.blah.com") }, [], nil)
      TEST(->() { Hostname.CheckFQ("123.com") }, [], nil)

      DUMP("Hostname::CheckDomain")
      TEST(->() { Hostname.CheckDomain(nil) }, [], nil)
      TEST(->() { Hostname.CheckDomain("") }, [], nil)
      TEST(->() { Hostname.CheckDomain("ww.asda.") }, [], nil)
      TEST(->() { Hostname.CheckDomain(".asd.asd.com") }, [], nil)
      TEST(->() { Hostname.CheckDomain("www.a sd.com") }, [], nil)
      TEST(->() { Hostname.CheckDomain("dsf.234") }, [], nil)
      TEST(->() { Hostname.CheckDomain("dsf.4com") }, [], nil)
      TEST(->() { Hostname.CheckDomain("asd-.com") }, [], nil)
      TEST(->() { Hostname.CheckDomain("----------") }, [], nil)
      DUMP("----------")
      TEST(->() { Hostname.CheckDomain("A.B") }, [], nil)
      TEST(->() { Hostname.CheckDomain("www.blah.com") }, [], nil)
      TEST(->() { Hostname.CheckDomain("as.cca.da3.cdd222.cd-2s.com") }, [], nil)
      TEST(->() { Hostname.CheckDomain("www.a-sd.com") }, [], nil)
      TEST(->() { Hostname.CheckDomain("asdf.2234-dsf.com") }, [], nil)
      TEST(->() { Hostname.CheckDomain("12-34.56-78.com") }, [], nil)
      TEST(->() { Hostname.CheckDomain("123.com") }, [], nil)
      TEST(->() { Hostname.CheckDomain("4com") }, [], nil)
      TEST(->() { Hostname.CheckDomain("doncom") }, [], nil)

      DUMP("Hostname::SplitFQ")
      TEST(->() { Hostname.SplitFQ("ftp.suse.cz") }, [], nil)
      TEST(->() { Hostname.SplitFQ("123.com") }, [], nil)
      TEST(->() { Hostname.SplitFQ("beholder") }, [], nil)

      nil
    end
  end
end

Yast::HostnameClient.new.main
