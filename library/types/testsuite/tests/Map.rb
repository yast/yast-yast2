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
  class MapClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "Map"

      DUMP("Map::Keys")
      TEST(->() { Map.Keys(nil) }, [], nil)
      TEST(->() { Map.Keys({}) }, [], nil)
      TEST(->() { Map.Keys(1 => 2) }, [], nil)
      TEST(->() { Map.Keys("2" => 3) }, [], nil)
      TEST(->() { Map.Keys(x: 4) }, [], nil)
      TEST(->() { Map.Keys(1 => 2, 3 => 4) }, [], nil)

      DUMP("Map::Values")
      TEST(->() { Map.Values(nil) }, [], nil)
      TEST(->() { Map.Values({}) }, [], nil)
      TEST(->() { Map.Values(1 => 2) }, [], nil)
      TEST(->() { Map.Values("2" => 3) }, [], nil)
      TEST(->() { Map.Values(x: 4) }, [], nil)
      TEST(->() { Map.Values(1 => 2, 3 => 4) }, [], nil)

      DUMP("Map::KeysToLower")
      TEST(->() { Map.KeysToLower(nil) }, [], nil)
      TEST(->() { Map.KeysToLower({}) }, [], nil)
      TEST(->() { Map.KeysToLower("a" => 1) }, [], nil)
      TEST(->() { Map.KeysToLower("A" => 1) }, [], nil)
      TEST(->() { Map.KeysToLower("A" => 1, "b" => 1) }, [], nil)

      DUMP("Map::KeysToUpper")
      TEST(->() { Map.KeysToUpper(nil) }, [], nil)
      TEST(->() { Map.KeysToUpper({}) }, [], nil)
      TEST(->() { Map.KeysToUpper("a" => 1) }, [], nil)
      TEST(->() { Map.KeysToUpper("A" => 1) }, [], nil)
      TEST(->() { Map.KeysToUpper("A" => 1, "b" => 1) }, [], nil)

      DUMP("Map::CheckKeys")
      TEST(->() { Map.CheckKeys(nil, [1]) }, [], nil)
      TEST(->() { Map.CheckKeys({}, [1]) }, [], nil)
      TEST(->() { Map.CheckKeys({ 1 => 2 }, [nil]) }, [], nil)
      TEST(->() { Map.CheckKeys({ 1 => 2 }, [1]) }, [], nil)
      TEST(->() { Map.CheckKeys({ 1 => 2 }, [2]) }, [], nil)
      TEST(->() { Map.CheckKeys({ "2" => 3 }, [1]) }, [], nil)
      TEST(->() { Map.CheckKeys({ "2" => 3 }, ["2"]) }, [], nil)
      TEST(->() { Map.CheckKeys({ x: 4 }, [:x]) }, [], nil)
      TEST(->() { Map.CheckKeys({ x: 4 }, [:y]) }, [], nil)
      TEST(->() { Map.CheckKeys({ x: 4 }, [1]) }, [], nil)
      TEST(->() { Map.CheckKeys({ 1 => 2, 3 => 4 }, [1]) }, [], nil)
      TEST(->() { Map.CheckKeys({ 1 => 2, 3 => 4 }, [1, 3]) }, [], nil)
      TEST(->() { Map.CheckKeys({ 1 => 2, 3 => 4 }, [3, 1]) }, [], nil)
      TEST(->() { Map.CheckKeys({ 1 => 2, 3 => 4 }, [2, 3]) }, [], nil)
      TEST(->() { Map.CheckKeys({ 1 => 2, 3 => 4 }, [4, 5]) }, [], nil)
      TEST(->() { Map.CheckKeys({ 1 => 2, 3 => 4 }, [2, 1]) }, [], nil)
      TEST(->() { Map.CheckKeys({ 1 => 2, 3 => 4 }, [:x]) }, [], nil)

      DUMP("Map::ToString")
      TEST(->() { Map.ToString(nil) }, [], nil)
      TEST(->() { Map.ToString({}) }, [], nil)
      TEST(->() { Map.ToString("io" => "0x340") }, [], nil)
      TEST(->() { Map.ToString("io" => "0x340", "irq" => "9") }, [], nil)

      DUMP("Map::FromString")
      TEST(->() { Map.FromString(nil) }, [], nil)
      TEST(->() { Map.FromString("") }, [], nil)
      TEST(->() { Map.FromString(" ") }, [], nil)
      TEST(->() { Map.FromString("io=0x340") }, [], nil)
      TEST(->() { Map.FromString("io=0x340 irq=9") }, [], nil)

      nil
    end
  end
end

Yast::MapClient.new.main
