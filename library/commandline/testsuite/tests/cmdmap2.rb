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
# File:	cmpmap2.ycp
# Package:	yast2
# Summary:	sanity validation of the command line map
# Author:	Stanislav Visnovsky <visnov@suse.cz>
#
# $Id$
#
# testedfiles: CommandLine.ycp Testsuite.ycp
module Yast
  class Cmdmap2Client < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "TypeRepository"
      Yast.import "CommandLine"

      textdomain "empty"

      # map must define reasonable id
      TEST(lambda do
        CommandLine.Init({ "id" => "", "help" => _("This is testsuite") }, [])
      end, [], nil)
      TEST(->() { CommandLine.Done }, [], nil)
      TEST(->() { CommandLine.Aborted }, [], nil) 

      # EOF

      nil
    end
  end
end

Yast::Cmdmap2Client.new.main
