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
  class PrepareProposalsClient < Client
    def main
      # testedfiles: WorkflowManager.ycp

      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "size" => 0 } }

      @WRITE = {}

      @EXEC = {
        "target" => {
          "bash_output" => { "exit" => 0, "stdout" => "", "stderr" => "" }
        }
      }

      TESTSUITE_INIT([@READ, @WRITE, @EXEC], nil)

      Yast.import "WorkflowManager"

      @proposals = [
        {
          "mode"             => "installation,demo,autoinstallation",
          "name"             => "initial",
          "proposal_modules" => [
            "hwinfo",
            "keyboard",
            "mouse",
            "partitions",
            "software",
            "bootloader",
            "timezone",
            "language",
            "default_target"
          ],
          "proposal_tabs"    => [
            {
              "label"            => "Overview",
              "proposal_modules" => [
                "partitions",
                "software_simple",
                "language_simple"
              ]
            },
            {
              "label"            => "Expert",
              "proposal_modules" => [
                "hwinfo",
                "keyboard",
                "mouse",
                "partitions",
                "software",
                "bootloader",
                "timezone",
                "language",
                "default_target"
              ]
            }
          ],
          "stage"            => "initial"
        },
        {
          "name"             => "network",
          "proposal_modules" => [
            { "name" => "lan", "presentation_order" => "20" },
            { "name" => "dsl", "presentation_order" => "30" },
            { "name" => "isdn", "presentation_order" => "40" },
            { "name" => "modem", "presentation_order" => "50" },
            { "name" => "remote", "presentation_order" => "60" },
            { "name" => "firewall", "presentation_order" => "10" },
            { "name" => "proxy", "presentation_order" => "70" }
          ],
          "stage"            => "continue,normal"
        }
      ]

      TEST(->() { WorkflowManager.PrepareProposals(@proposals) }, [], nil)

      nil
    end
  end
end

Yast::PrepareProposalsClient.new.main
