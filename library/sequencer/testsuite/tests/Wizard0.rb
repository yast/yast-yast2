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
  class Wizard0Client < Client
    def main
      @clicks = nil
      @cur = -1
      Yast.include self, "Wizard.rb"

      @Aliases = { "0" => ->() { next }, "1" => ->() { next }, "F" => lambda do
        finish
      end }

      @Sequence = {
        "ws_start" => "0",
        "0"        => { next: "1" },
        "1"        => { next: "F" },
        "F"        => { finish: :ws_finish }
      }

      TEST(->() { Sequencer.Run(nil, nil) }, [], nil)
      TEST(->() { Sequencer.Run({}, {}) }, [], nil)
      TEST(->() { Sequencer.Run({}, nil) }, [], nil)
      TEST(->() { Sequencer.Run(nil, {}) }, [], nil)
      TEST(->() { Sequencer.Run({}, @Sequence) }, [], nil)
      TEST(->() { Sequencer.Run(@Aliases, {}) }, [], nil)
      TEST(->() { Sequencer.Run({}, "ws_start" => :ok) }, [], nil)

      nil
    end
  end
end

Yast::Wizard0Client.new.main
