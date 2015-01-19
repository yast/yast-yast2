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
  class WSPushClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "Sequencer"

      TEST(->() { Sequencer.WS_push(nil, 4) }, [], nil)
      TEST(->() { Sequencer.WS_push([], 4) }, [], nil)
      TEST(->() { Sequencer.WS_push([1, 3, 5, 7, 9, 11], 4) }, [], nil)
      TEST(->() { Sequencer.WS_push([1, 3, 5, 7, 9, 11], 7) }, [], nil)

      nil
    end
  end
end

Yast::WSPushClient.new.main
