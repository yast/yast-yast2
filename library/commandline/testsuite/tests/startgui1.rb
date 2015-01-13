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
# File:	startgui1.ycp
# Package:	yast2
# Summary:	test StartGUI() and Done()
# Author:	Stanislav Visnovsky <visnov@suse.cz>
#
# $Id$
#
# testedfiles: CommandLine.ycp Testsuite.ycp
module Yast
  class Startgui1Client < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.include self, "testsuitedata.rb"

      Yast.import "TypeRepository"
      Yast.import "CommandLine"

      # should be successfull
      TEST(->() { CommandLine.Init(@cmdline, []) }, [], nil)
      TEST(->() { CommandLine.StartGUI }, [], nil)
      TEST(->() { CommandLine.Done }, [], nil) 

      # EOF

      nil
    end
  end
end

Yast::Startgui1Client.new.main
