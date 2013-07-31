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
  class PrepareWorkflowsClient < Client
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

      @workflows = [
        {
          "defaults" => { "archs" => "i386,x86_64" },
          "label"    => "Preparation",
          "mode"     => "installation,update",
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

      TEST(lambda { WorkflowManager.PrepareWorkflows(@workflows) }, [], nil)

      nil
    end
  end
end

Yast::PrepareWorkflowsClient.new.main
