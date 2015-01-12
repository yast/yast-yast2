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
# File:	cmpmap3.ycp
# Package:	yast2
# Summary:	sanity validation of the command line map
# Author:	Stanislav Visnovsky <visnov@suse.cz>
#
# $Id$
#
# testedfiles: CommandLine.ycp Testsuite.ycp
module Yast
  class Cmdmap3Client < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "TypeRepository"
      Yast.import "CommandLine"

      # map must define help for each action
      TEST(lambda do
        CommandLine.Init(
          {
            "id"      => "testsuite",
            "actions" => {
              "okaction"    => { "help" => "This action should be ok" },
              "wrongaction" => { "key" => nil }
            }
          },
          []
        )
      end, [], nil)
      TEST(lambda { CommandLine.Done }, [], nil)
      TEST(lambda { CommandLine.Aborted }, [], nil)

      # EOF

      nil
    end
  end
end

Yast::Cmdmap3Client.new.main
