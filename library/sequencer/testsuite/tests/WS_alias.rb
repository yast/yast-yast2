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
  class WSAliasClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "Sequencer"

      @aliases = {
        "1" => nil,
        "2" => ->() { func1 },
        "3" => [],
        "4" => [nil],
        "5" => [->() { func2 }],
        "6" => [->() { func3 }, :blah]
      }

      TEST(->() { Sequencer.WS_alias({}, "blah") }, [], nil)
      TEST(->() { Sequencer.WS_alias(@aliases, "blah") }, [], nil)
      TEST(->() { Sequencer.WS_alias(@aliases, "1") }, [], nil)
      TEST(->() { Builtins.eval(Sequencer.WS_alias(@aliases, "2")) }, [], nil)
      TEST(->() { Sequencer.WS_alias(@aliases, "3") }, [], nil)
      TEST(->() { Sequencer.WS_alias(@aliases, "4") }, [], nil)
      TEST(->() { Builtins.eval(Sequencer.WS_alias(@aliases, "5")) }, [], nil)
      TEST(->() { Builtins.eval(Sequencer.WS_alias(@aliases, "6")) }, [], nil)

      nil
    end

    def func1
      :func1
    end

    def func2
      :func2
    end

    def func3
      :func3
    end
  end
end

Yast::WSAliasClient.new.main
