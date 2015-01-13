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
  class WSNextClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "Sequencer"

      @aliases = { "1" => ->() { f1 }, "2" => ->() { f2 }, "3" => lambda do
        f3
      end }

      @sequence = {
        "ws_start" => "begin",
        "begin"    => { :next => "decide" },
        "config"   => { :next => "end" },
        "decide"   => { :no => "end", :yes => "config" },
        "end"      => { :finish => :ws_finish }
      }

      TEST(->() { Sequencer.WS_next({}, "blah", :id3) }, [], nil)
      TEST(->() { Sequencer.WS_next(@sequence, "blah", :id3) }, [], nil)
      TEST(->() { Sequencer.WS_next(@sequence, "begin", :id3) }, [], nil)
      TEST(->() { Sequencer.WS_next(@sequence, "begin", :id3) }, [], nil)
      TEST(->() { Sequencer.WS_next(@sequence, "begin", :id3) }, [], nil)
      #TEST(``(Sequencer::WS_next(sequence, "ws_start", `next)), [], nil);
      TEST(->() { Sequencer.WS_next(@sequence, "decide", :yes) }, [], nil)
      TEST(->() { Sequencer.WS_next(@sequence, "decide", :no) }, [], nil)
      TEST(->() { Sequencer.WS_next(@sequence, "end", :finish) }, [], nil)

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
  end
end

Yast::WSNextClient.new.main
