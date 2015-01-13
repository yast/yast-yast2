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
# File:	help.ycp
# Package:	yast2
# Summary:	print help test
# Author:	Stanislav Visnovsky <visnov@suse.cz>
#
# $Id$
#
# testedfiles: CommandLine.ycp Testsuite.ycp
module Yast
  class HelpClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.include self, "testsuitedata.rb"

      Yast.import "TypeRepository"
      Yast.import "CommandLine"

      # test of the resulting maps
      TEST(->() { CommandLine.Init(@cmdline, ["help"]) }, [], nil)

      # EOF

      nil
    end
  end
end

Yast::HelpClient.new.main
