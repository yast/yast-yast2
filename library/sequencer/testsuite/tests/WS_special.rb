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
  class WSSpecialClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "Sequencer"

      @Aliases = {
        "normal"    => lambda { Normal() },
        "special_n" => [lambda { SpecialN() }, false],
        "special_y" => [lambda { SpecialY() }, true]
      }

      TEST(lambda { Sequencer.WS_special(@Aliases, "normal") }, [], nil)
      TEST(lambda { Sequencer.WS_special(@Aliases, "special_n") }, [], nil)
      TEST(lambda { Sequencer.WS_special(@Aliases, "special_y") }, [], nil)
      TEST(lambda { Sequencer.WS_special(@Aliases, "missing") }, [], nil)

      nil
    end

    def Normal
      1
    end
    def SpecialN
      1
    end
    def SpecialY
      1
    end
  end
end

Yast::WSSpecialClient.new.main
