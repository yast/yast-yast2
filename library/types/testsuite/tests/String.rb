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
  class StringClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "String"

      DUMP("String::Repeat")
      TEST(lambda do
        Builtins.mergestring(["\"", String.Repeat(nil, 2), "\""], "")
      end, [], nil)
      TEST(lambda do
        Builtins.mergestring(["\"", String.Repeat(".", 8), "\""], "")
      end, [], nil)
      TEST(lambda do
        Builtins.mergestring(["\"", String.Repeat(".", -1), "\""], "")
      end, [], nil)

      DUMP("String::SuperPad")
      TEST(lambda do
        Builtins.mergestring(
          ["\"", String.SuperPad(nil, 2, nil, :left), "\""],
          ""
        )
      end, [], nil)
      TEST(lambda do
        Builtins.mergestring(
          ["\"", String.SuperPad("a", 8, ".", :left), "\""],
          ""
        )
      end, [], nil)
      TEST(lambda do
        Builtins.mergestring(
          ["\"", String.SuperPad("abc", 8, ".", :left), "\""],
          ""
        )
      end, [], nil)
      TEST(lambda do
        Builtins.mergestring(
          ["\"", String.SuperPad("a", 8, ".", :right), "\""],
          ""
        )
      end, [], nil)
      TEST(lambda do
        Builtins.mergestring(
          ["\"", String.SuperPad("abc", 8, ".", :right), "\""],
          ""
        )
      end, [], nil)

      DUMP("String::Pad")
      TEST(->() { Builtins.mergestring(["\"", String.Pad(nil, 2), "\""], "") }, [], nil)
      TEST(->() { Builtins.mergestring(["\"", String.Pad("", 2), "\""], "") }, [], nil)
      TEST(->() { Builtins.mergestring(["\"", String.Pad("a", 2), "\""], "") }, [], nil)
      TEST(->() { Builtins.mergestring(["\"", String.Pad("ab", 2), "\""], "") }, [], nil)
      TEST(->() { Builtins.mergestring(["\"", String.Pad("abc", 2), "\""], "") }, [], nil)
      TEST(->() { Builtins.mergestring(["\"", String.Pad("a", -1), "\""], "") }, [], nil)
      TEST(->() { Builtins.mergestring(["\"", String.Pad("", 0), "\""], "") }, [], nil)
      TEST(->() { Builtins.mergestring(["\"", String.Pad("a", 0), "\""], "") }, [], nil)

      DUMP("String::PadZeros")
      TEST(->() { String.PadZeros(nil, 4) }, [], nil)
      TEST(->() { String.PadZeros("", 4) }, [], nil)
      TEST(->() { String.PadZeros("1", 4) }, [], nil)
      TEST(->() { String.PadZeros("12", 4) }, [], nil)
      TEST(->() { String.PadZeros("123", 4) }, [], nil)
      TEST(->() { String.PadZeros("1234", 4) }, [], nil)
      TEST(->() { String.PadZeros("12345", 4) }, [], nil)

      DUMP("String::ParseOptions")
      TEST(->() { String.ParseOptions("a=3\tb=2", {}) }, [], nil)
      TEST(->() { String.ParseOptions("a=3 b=2", {}) }, [], nil)
      TEST(->() { String.ParseOptions("a=", {}) }, [], nil)

      @param = {
        "separator"         => ",",
        "unique"            => true,
        "remove_whitespace" => true
      }

      # Basic functionality
      TEST(->() { String.ParseOptions(nil, @param) }, [{}, {}, {}], nil)
      TEST(->() { String.ParseOptions("", @param) }, [{}, {}, {}], nil)
      TEST(->() { String.ParseOptions("    ", @param) }, [{}, {}, {}], nil)
      TEST(->() { String.ParseOptions(" abc , 123, var", @param) }, [
        {},
        {},
        {}
      ], nil)
      TEST(->() { String.ParseOptions(" abc,123  ", @param) }, [{}, {}, {}], nil)
      TEST(->() { String.ParseOptions("x,  y  ,  z", @param) }, [{}, {}, {}], nil)
      TEST(->() { String.ParseOptions("0,\"1, 2, 3\", 4, 5 ", @param) }, [
        {},
        {},
        {}
      ], nil)
      TEST(->() { String.ParseOptions(" ,,  ,", @param) }, [{}, {}, {}], nil)
      TEST(->() { String.ParseOptions("\"abc\"", @param) }, [{}, {}, {}], nil)
      TEST(->() { String.ParseOptions("\" abc \"", @param) }, [{}, {}, {}], nil)

      # multi separator
      Ops.set(@param, "separator", ",;.")
      TEST(->() { String.ParseOptions("ab.sdf;  fwre  sdf", @param) }, [
        {},
        {},
        {}
      ], nil)

      # uniqe / multile test
      TEST(->() { String.ParseOptions(" 1,2,1,1,5 ,", @param) }, [{}, {}, {}], nil)
      Ops.set(@param, "unique", false)
      TEST(->() { String.ParseOptions(" 1,2,1,1,5 ,", @param) }, [{}, {}, {}], nil)

      # use space as separator
      Ops.set(@param, "separator", " ")
      TEST(->() { String.ParseOptions(" \"\\\"\", 2", @param) }, [{}, {}, {}], nil)
      TEST(->() { String.ParseOptions("   a   b zx ,, ,", @param) }, [
        {},
        {},
        {}
      ], nil)
      TEST(->() { String.ParseOptions("   123\"56\"78  bzx ", @param) }, [
        {},
        {},
        {}
      ], nil)
      TEST(->() { String.ParseOptions("   a \\\\ b ", @param) }, [{}, {}, {}], nil)
      TEST(->() { String.ParseOptions(" \n \\\"  ", @param) }, [{}, {}, {}], nil)

      # don't remove white space
      Ops.set(@param, "remove_whitespace", false)
      Ops.set(@param, "separator", ",")
      TEST(->() { String.ParseOptions("   a   b zx ,, ,", @param) }, [
        {},
        {},
        {}
      ], nil)

      DUMP("String::CutRegexMatch")
      TEST(->() { String.CutRegexMatch("abc", "[0-9]+", true) }, [], nil)
      TEST(->() { String.CutRegexMatch("abc12def345ghi678900", "[0-9]+", true) }, [], nil)
      TEST(lambda do
        String.CutRegexMatch("abc12def345ghi678900", "[0-9]+", false)
      end, [], nil)
      TEST(->() { String.CutRegexMatch("abc12def345ghi678900", ".*", false) }, [], nil)

      DUMP("Strings::EscapeTags")
      TEST(lambda do
        String.EscapeTags("<font size='2'><b>text & another</b></font>")
      end, [], nil)
      TEST(->() { String.EscapeTags("2 > 1") }, [], nil)

      DUMP("String::StartsWith")
      TEST(->() { String.StartsWith("hello", "hello") }, [], nil)
      TEST(->() { String.StartsWith("hello world", "hello") }, [], nil)
      TEST(->() { String.StartsWith("hello hello", "hello") }, [], nil)
      TEST(->() { String.StartsWith("hello", "hello world") }, [], nil)

      DUMP("Strings::RemoveShortcut")
      TEST(->() { String.RemoveShortcut("Hello") }, [], nil)
      TEST(->() { String.RemoveShortcut("He&llo") }, [], nil)
      TEST(->() { String.RemoveShortcut("He&&llo") }, [], nil)
      TEST(->() { String.RemoveShortcut("He&&&llo") }, [], nil)
      TEST(->() { String.RemoveShortcut("He&&&&llo") }, [], nil)
      TEST(->() { String.RemoveShortcut("He&&&&&llo") }, [], nil)
      TEST(->() { String.RemoveShortcut("&Hello") }, [], nil)
      TEST(->() { String.RemoveShortcut("&&Hello") }, [], nil)
      TEST(->() { String.RemoveShortcut("&&&Hello") }, [], nil)
      TEST(->() { String.RemoveShortcut("&&&&Hello") }, [], nil)
      TEST(->() { String.RemoveShortcut("&&&&&Hello") }, [], nil)
      TEST(->() { String.RemoveShortcut("&&He&llo") }, [], nil)

      DUMP("String::ReplaceWith")
      TEST(->() { String.ReplaceWith("a\nb\tc d", "\n\t ", "-") }, [], nil)
      TEST(lambda do
        String.ReplaceWith(
          "this$# is an in&put text co@ntain$ing some special## ch@a$racters to remove",
          "&$\#@",
          ""
        )
      end, [], nil)

      nil
    end
  end
end

Yast::StringClient.new.main
