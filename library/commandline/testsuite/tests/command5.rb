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
# File:	command5.ycp
# Package:	yast2
# Summary:	test command-line parsing
# Author:	Stanislav Visnovsky <visnov@suse.cz>
#
# $Id$
#
# testedfiles: CommandLine.ycp Testsuite.ycp
module Yast
  class Command5Client < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.include self, "testsuitedata.rb"

      Yast.import "CommandLine"

      # unknown option
      TEST(->() { CommandLine.Init(@cmdline, ["add", "ip=10.20.a.b"]) }, [], nil)
      TEST(->() { CommandLine.Command }, [], nil)

      # EOF

      nil
    end
  end
end

Yast::Command5Client.new.main
