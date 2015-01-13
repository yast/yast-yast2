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
  class IntegerClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "Integer"

      DUMP("Integer::Range")
      TEST(->() { Integer.Range(0) }, [], nil)
      TEST(->() { Integer.Range(10) }, [], nil)

      DUMP("Integer::RangeFrom")
      TEST(->() { Integer.RangeFrom(5, 10) }, [], nil)

      DUMP("Integer::IsPowerOfTwo")
      TEST(->() { Integer.IsPowerOfTwo(0) }, [], nil)
      TEST(->() { Integer.IsPowerOfTwo(1) }, [], nil)
      TEST(->() { Integer.IsPowerOfTwo(2) }, [], nil)
      TEST(->() { Integer.IsPowerOfTwo(3) }, [], nil)
      TEST(->() { Integer.IsPowerOfTwo(4) }, [], nil)

      TEST(->() { Integer.IsPowerOfTwo(1024 - 1) }, [], nil)
      TEST(->() { Integer.IsPowerOfTwo(1024) }, [], nil)
      TEST(->() { Integer.IsPowerOfTwo(1024 + 1) }, [], nil)

      TEST(->() { Integer.IsPowerOfTwo(1024 * 1024 * 1024 * 1024 - 1) }, [], nil)
      TEST(->() { Integer.IsPowerOfTwo(1024 * 1024 * 1024 * 1024) }, [], nil)
      TEST(->() { Integer.IsPowerOfTwo(1024 * 1024 * 1024 * 1024 + 1) }, [], nil)

      DUMP("Integer::Sum")
      TEST(->() { Integer.Sum([]) }, [], nil)
      TEST(->() { Integer.Sum([1]) }, [], nil)
      TEST(->() { Integer.Sum([2, 3]) }, [], nil)

      DUMP("Integer::Min")
      TEST(->() { Integer.Min([1]) }, [], nil)
      TEST(->() { Integer.Min([1, 2]) }, [], nil)
      TEST(->() { Integer.Min([2, 1]) }, [], nil)

      DUMP("Integer::Max")
      TEST(->() { Integer.Max([1]) }, [], nil)
      TEST(->() { Integer.Max([1, 2]) }, [], nil)
      TEST(->() { Integer.Max([2, 1]) }, [], nil)

      DUMP("Integer::Clamp")
      TEST(->() { Integer.Clamp(1, 2, 4) }, [], nil)
      TEST(->() { Integer.Clamp(2, 2, 4) }, [], nil)
      TEST(->() { Integer.Clamp(3, 2, 4) }, [], nil)
      TEST(->() { Integer.Clamp(4, 2, 4) }, [], nil)
      TEST(->() { Integer.Clamp(5, 2, 4) }, [], nil)

      nil
    end
  end
end

Yast::IntegerClient.new.main
