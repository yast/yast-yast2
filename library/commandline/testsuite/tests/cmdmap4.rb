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
# File:	cmpmap4.ycp
# Package:	yast2
# Summary:	sanity validation of the command line map
# Author:	Stanislav Visnovsky <visnov@suse.cz>
#
# $Id$
#
# testedfiles: CommandLine.ycp Testsuite.ycp
module Yast
  class Cmdmap4Client < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "TypeRepository"
      Yast.import "CommandLine"

      # map must define help for each option
      # map must contain typespec for types "regex" and "enum"
      TEST(lambda do
        CommandLine.Init(
          {
            "id"      => "testsuite",
            "help"    => "help is there",
            "options" => {
              "nohelpoption"  => { "type" => "string" },
              "noregexoption" => { "help" => "some help", "type" => "regex" },
              "noenumpoption" => { "help" => "some help", "type" => "enum" },
              "okregexoption" => {
                "help"     => "some help",
                "type"     => "regex",
                "typespec" => "^[a]+$"
              },
              "okenumoption"  => {
                "help"     => "some help",
                "type"     => "enum",
                "typespec" => ["a", "b"]
              }
            }
          },
          []
        )
      end, [], nil)
      TEST(->() { CommandLine.Done }, [], nil)
      TEST(->() { CommandLine.Aborted }, [], nil)

      # EOF

      nil
    end
  end
end

Yast::Cmdmap4Client.new.main
