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
  class WorkflowManagerClient < Client
    def main
      # testedfiles: WorkflowManager.ycp

      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "size" => 0, "stat" => { "dummy" => true } } }

      @WRITE = {}

      @EXEC = {}

      @MOCK = [@READ, @WRITE, @EXEC]

      TESTSUITE_INIT(@MOCK, nil)

      Yast.import "WorkflowManager"
      Yast.import "ProductControl"

      # init -->
      ProductControl.workflows = [
        {
          "defaults" => { "archs" => "i386" },
          "label"    => "Preparation",
          "mode"     => "installation",
          "modules"  => [
            {
              "arguments"   => { "first_run" => "yes" },
              "enable_back" => "no",
              "enable_next" => "yes",
              "label"       => "Language",
              "name"        => "language",
              "retranslate" => true
            },
            { "label" => "Perform Installation", "name" => "finish" }
          ],
          "stage"    => "initial"
        },
        {
          "defaults" => { "archs" => "x86_64" },
          "label"    => "Preparation",
          "mode"     => "installation",
          "modules"  => [
            {
              "arguments"   => { "first_run" => "yes" },
              "enable_back" => "no",
              "enable_next" => "yes",
              "label"       => "Language",
              "name"        => "language",
              "retranslate" => true
            },
            { "label" => "Perform Installation", "name" => "finish" }
          ],
          "stage"    => "initial"
        },
        {
          "defaults" => { "archs" => "i386" },
          "label"    => "Preparation",
          "mode"     => "update",
          "modules"  => [
            {
              "arguments"   => { "first_run" => "yes" },
              "enable_back" => "no",
              "enable_next" => "yes",
              "label"       => "Language",
              "name"        => "language",
              "retranslate" => true
            },
            { "label" => "Perform Installation", "name" => "finish" }
          ],
          "stage"    => "initial"
        },
        {
          "defaults" => { "archs" => "x86_64" },
          "label"    => "Preparation",
          "mode"     => "update",
          "modules"  => [
            {
              "arguments"   => { "first_run" => "yes" },
              "enable_back" => "no",
              "enable_next" => "yes",
              "label"       => "Language",
              "name"        => "language",
              "retranslate" => true
            },
            { "label" => "Perform Installation", "name" => "finish" }
          ],
          "stage"    => "initial"
        }
      ]
      WorkflowManager.PrepareSystemWorkflows

      ProductControl.proposals = [
        {
          "archs"            => "",
          "mode"             => "installation",
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
          "archs"            => "",
          "mode"             => "demo",
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
          "archs"            => "",
          "mode"             => "autoinstallation",
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
          "archs"            => "",
          "mode"             => "",
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
          "stage"            => "continue"
        },
        {
          "archs"            => "",
          "mode"             => "",
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
          "stage"            => "normal"
        }
      ]
      WorkflowManager.PrepareSystemProposals
      # init <--

      TEST(->() { WorkflowManager.SetBaseWorkflow(false) }, @MOCK, nil)

      DUMP("")
      DUMP("Adding new Add-On product")
      TEST(->() { WorkflowManager.AddWorkflow(:addon, 3, "") }, @MOCK, nil)
      TEST(->() { WorkflowManager.GetAllUsedControlFiles }, @MOCK, nil)

      DUMP("")
      DUMP("Adding another Add-On product")
      TEST(->() { WorkflowManager.AddWorkflow(:addon, 12, "") }, @MOCK, nil)
      TEST(->() { WorkflowManager.GetAllUsedControlFiles }, @MOCK, nil)

      DUMP("")
      DUMP("Removing the first Add-On product")
      TEST(->() { WorkflowManager.RemoveWorkflow(:addon, 3, "") }, @MOCK, nil)
      TEST(->() { WorkflowManager.GetAllUsedControlFiles }, @MOCK, nil)

      DUMP("")
      DUMP("Removing the first Add-On product")
      TEST(->() { WorkflowManager.MergeWorkflows }, @MOCK, nil)

      DUMP("")
      DUMP("Current Settings")
      TEST(->() { WorkflowManager.DumpCurrentSettings }, @MOCK, nil)

      nil
    end
  end
end

Yast::WorkflowManagerClient.new.main
