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
  class AddressClient < Client
    def main
      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "tmpdir" => "/tmp" } }
      TESTSUITE_INIT([@READ], nil)

      Yast.import "Address"

      DUMP("Address::Check")
      TEST(->() { Address.Check(nil) }, [@READ], nil)
      TEST(->() { Address.Check("") }, [@READ], nil)
      TEST(->() { Address.Check("1.2.3.4") }, [@READ], nil)
      TEST(->() { Address.Check("::1") }, [@READ], nil)

      nil
    end
  end
end

Yast::AddressClient.new.main
