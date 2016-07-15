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
# File:	interactive4.ycp
# Package:	yast2
# Summary:	test action in interactive mode
# Author:	Stanislav Visnovsky <visnov@suse.cz>
#
# $Id$
#
# testedfiles: CommandLine.ycp Testsuite.ycp
module Yast
  class Interactive4Client < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.include self, "testsuitedata.rb"

      Yast.import "CommandLine"

      # startup
      TEST(->() { CommandLine.Init(@cmdline, ["interactive"]) }, [], nil)
      TEST(->() { CommandLine.StartGUI }, [], nil)
      TEST(->() { CommandLine.Done }, [], nil)

      # do help
      TEST(->() { CommandLine.Command },
        [
          { "dev" => { "tty" => "add device=eth0" } }
        ], nil)
      TEST(->() { CommandLine.Done }, [], nil)
      TEST(->() { CommandLine.Aborted }, [], nil)

      # quit
      TEST(->() { CommandLine.Command }, [{ "dev" => { "tty" => "abort" } }], nil)
      TEST(->() { CommandLine.Done }, [], nil)
      TEST(->() { CommandLine.Aborted }, [], nil)

      # EOF

      nil
    end
  end
end

Yast::Interactive4Client.new.main
