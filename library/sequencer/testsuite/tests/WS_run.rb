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
  class WSRunClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "Sequencer"

      @aliases = { "1" => lambda { f1 }, "2" => lambda { f2 }, "3" => lambda do
        f3
      end }

      TEST(lambda { Sequencer.WS_run({}, "blah") }, [], nil)
      TEST(lambda { Sequencer.WS_run(@aliases, "blah") }, [], nil)
      TEST(lambda { Sequencer.WS_run(@aliases, "1") }, [], nil)
      TEST(lambda { Sequencer.WS_run(@aliases, "2") }, [], nil)
      TEST(lambda { Sequencer.WS_run(@aliases, "3") }, [], nil)

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

Yast::WSRunClient.new.main
