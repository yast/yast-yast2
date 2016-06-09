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
  class WSCheckClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "Sequencer"

      @aliases1 = {
        :x  => "x",
        "1" => "1",
        "2" => [],
        "3" => [->() { f1 }],
        "4" => ["4", :x],
        "5" => [->() { f2 }, "5"],
        "6" => [->() { f3 }, true],
        "7" => [->() { f4 }, false],
        "8" => ->() { f5 },
        "9" => ->() { f6 },
        "A" => ->() { f7 }
      }

      @sequence1 = {
        "ws_start" => "missing",
        "0"        => {},
        "8"        => [],
        "9"        => {},
        "A"        => { "blah" => :back, :next => "huu", :finish => :ok },
        :x         => {},
        "1"        => {},
        "2"        => {},
        "3"        => {},
        "4"        => {},
        "5"        => {},
        "6"        => {}
      }

      TEST(->() { Sequencer.WS_check({}, {}) }, [], nil)
      TEST(->() { Sequencer.WS_check(@aliases1, @sequence1) }, [], nil)

      TEST(->() { Sequencer.WS_check({}, "ws_start" => :ws_finish) }, [], nil)

      @clicks = nil
      @cur = -1
      Yast.include self, "Wizard.rb"
      TEST(->() { Sequencer.WS_check(aliases, sequence) }, [], nil)

      nil
    end

    def f1
      "1"
    end

    def f2
      2
    end

    def f3
      :id3
    end

    def f4
      1
    end

    def f5
      1
    end

    def f6
      1
    end

    def f7
      1
    end
  end
end

Yast::WSCheckClient.new.main
