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
# File:	enumtype.ycp
# Package:	yast2
# Summary:	enumerated type generic validator test
# Author:	Stanislav Visnovsky <visnov@suse.cz>
#
# $Id$
module Yast
  class EnumtypeClient < Client
    def main
      Yast.include self, "testsuite.rb"
      @READ = { "target" => { "tmpdir" => "/tmp" } }
      TESTSUITE_INIT([@READ], nil)

      Yast.import "TypeRepository"

      TEST(->() { TypeRepository.enum_validator(["a", "b", "c"], "a") }, [], nil)
      TEST(->() { TypeRepository.enum_validator(["a", "b", "c"], "x") }, [], nil)
      TEST(->() { TypeRepository.enum_validator([], "ahoj") }, [], nil) 

      # EOF

      nil
    end
  end
end

Yast::EnumtypeClient.new.main
