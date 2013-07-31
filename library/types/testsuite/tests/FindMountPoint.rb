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
  class FindMountPointClient < Client
    def main
      Yast.include self, "testsuite.rb"

      Yast.import "String"

      #import "Wagon";
      DUMP("Test nil")
      TEST(lambda { String.FindMountPoint(nil, nil) }, [], nil)
      TEST(lambda { String.FindMountPoint(nil, []) }, [], nil)
      TEST(lambda { String.FindMountPoint(nil, ["/boot", "/"]) }, [], nil)

      DUMP("Test empty string")
      TEST(lambda { String.FindMountPoint("", nil) }, [], nil)
      TEST(lambda { String.FindMountPoint("", []) }, [], nil)
      TEST(lambda { String.FindMountPoint("", ["/boot", "/"]) }, [], nil)

      DUMP("Test valid values")
      TEST(lambda { String.FindMountPoint("/", ["/boot", "/", "/usr"]) }, [], nil)
      TEST(lambda { String.FindMountPoint("/usr", ["/boot", "/", "/usr"]) }, [], nil)
      TEST(lambda { String.FindMountPoint("/usr/", ["/boot", "/", "/usr"]) }, [], nil)
      TEST(lambda do
        String.FindMountPoint("/usr/share/locale", ["/boot", "/", "/usr"])
      end, [], nil)
      TEST(lambda do
        String.FindMountPoint(
          "/usr/share/locale",
          ["/boot", "/", "/usr", "/usr/share"]
        )
      end, [], nil)

      nil
    end
  end
end

Yast::FindMountPointClient.new.main
