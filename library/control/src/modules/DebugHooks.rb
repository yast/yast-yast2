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
# File:	modules/DebugHooks.rb
# Package:	yast2
# Summary:	Provide debug hooks during installation
# Authors:	Klaus Kaempf <kkaempf@suse.de>
#
# $Id$
require "yast"

module Yast
  class DebugHooksClass < Module
    def main
      Yast.import "Popup"
      Yast.import "Directory"

      @tmp_dir = Convert.to_string(WFM.Read(path(".local.tmpdir"), []))
      @log_dir = Directory.logdir

      # script types, ycp does not make  sense, it can be added directly
      # to the workflow.
      @supported_types = ["sh", "pl"]
    end

    # called whenever an inst_*.ycp file is called during
    # installation.
    # checks if /tmp/<filename> exists and pops up a "Entry: <filename>"
    # or "Exit: <filename>" box
    #
    # @param [String] filename == name of .ycp file
    # @param [Boolean] at_entry == true before call of file == false after call of file
    # @return [void]

    def Checkpoint(filename, at_entry)
      if Ops.greater_or_equal(
        WFM.Read(path(".local.size"), Ops.add("/tmp/", filename)),
        0
      )
        if at_entry
          Popup.Message(Builtins.sformat("Entry: %1", filename))
        else
          Popup.Message(Builtins.sformat("Exit: %1", filename))
        end
      end
      nil
    end

    # Execute Script
    # @param [String] script name
    # @param [String] type
    def ExecuteScript(script, type)
      Builtins.y2milestone("Executing script: %1", script)
      # string message =  sformat(_("Executing user supplied script: %1"), scriptName);
      executionString = ""
      scriptPath = Builtins.sformat("%1/%2", @tmp_dir, script)
      if type == "shell"
        executionString = Builtins.sformat(
          "/bin/sh -x %1 2&> %2/%3.log",
          scriptPath,
          @log_dir,
          script
        )
        WFM.Execute(path(".local.bash"), executionString)
      elsif type == "perl"
        executionString = Builtins.sformat(
          "/usr/bin/perl %1 2&> %2/%3.log",
          scriptPath,
          @log_dir,
          script
        )
        WFM.Execute(path(".local.bash"), executionString)
      else
        Builtins.y2error("Unknown interpreter: %1", type)
      end
      Builtins.y2milestone("Script Execution command: %1", executionString)

      nil
    end

    # Run Script
    # @param [String] filename == name of .ycp file
    # @param [Boolean] at_entry == true before call of file == false after call of file
    def Run(filename, at_entry)
      Builtins.y2debug("Running debug hook: %1", filename)
      # do not run scripts twice
      if at_entry
        if Ops.greater_than(
          WFM.Read(
            path(".local.size"),
            Builtins.sformat("%1/%2_pre.sh", @tmp_dir, filename)
          ),
          0
        )
          ExecuteScript(Builtins.sformat("%1_pre.sh", filename), "shell")
        elsif Ops.greater_than(
          WFM.Read(
            path(".local.size"),
            Builtins.sformat("%1/%2_pre.pl", @tmp_dir, filename)
          ),
          0
        )
          ExecuteScript(Builtins.sformat("%1_pre.pl", filename), "perl")
        else
          Builtins.y2debug(
            "Debug hook not found: %1/%2_pre.{sh,pl}",
            @tmp_dir,
            filename
          )
        end
      else
        if Ops.greater_than(
          WFM.Read(
            path(".local.size"),
            Builtins.sformat("%1/%2_post.sh", @tmp_dir, filename)
          ),
          0
        )
          ExecuteScript(Builtins.sformat("%1_post.sh", filename), "shell")
        elsif Ops.greater_than(
          WFM.Read(
            path(".local.size"),
            Builtins.sformat("%1/%2_post.pl", @tmp_dir, filename)
          ),
          0
        )
          ExecuteScript(Builtins.sformat("%1_post.pl", filename), "perl")
        else
          Builtins.y2debug(
            "Debug hook not found: %1/%2_post.{sh,pl}",
            @tmp_dir,
            filename
          )
        end
      end
      nil
    end

    publish function: :Checkpoint, type: "void (string, boolean)"
    publish function: :Run, type: "void (string, boolean)"
  end

  DebugHooks = DebugHooksClass.new
  DebugHooks.main
end
