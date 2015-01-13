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
# Testsuite for URLRecode.pm module
#
# $Id$
module Yast
  class URLRecodeClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "URLRecode"

      TEST(->() { URLRecode.EscapePath(nil) }, [], nil)
      TEST(->() { URLRecode.EscapePath("") }, [], nil)

      @test_path = "/@\#$%^&/dir/\u010D\u00FD\u011B\u0161\u010D\u00FD\u00E1/file"

      TEST(->() { URLRecode.EscapePath(@test_path) }, [], nil)
      TEST(lambda do
        URLRecode.UnEscape(URLRecode.EscapePath(@test_path)) == @test_path
      end, [], nil)

      TEST(->() { URLRecode.EscapePath(" !@\#$%^&*()/?+=") }, [], nil)
      TEST(->() { URLRecode.EscapePassword(" !@\#$%^&*()/?+=<>[]|\"") }, [], nil)
      TEST(->() { URLRecode.EscapeQuery(" !@\#$%^&*()/?+=") }, [], nil)

      # EOF

      nil
    end
  end
end

Yast::URLRecodeClient.new.main
