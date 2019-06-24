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
# File:  modules/Crash.ycp
# Package:  YaST2 base package
# Summary:  Handling crashes and recovery of other modules
# Authors:  Jiri Srain <jsrain@suse.cz>
# Flags:  Stable
#
# $Id$
require "yast"

module Yast
  class CrashClass < Module
    def main
      Yast.import "Popup"

      # All operations that failed when were running last time
      @all_failed = []

      # All operations that were the last started when crashed
      # when running last time
      @last_failed = []

      # Last successfully finished operation
      @last_done = nil

      # List of operations which are active during this YaST2 session
      @this_run_active = []

      # Filename of file storing crash settings
      @filename = "/var/lib/YaST2/crash"
    end

    # Read settings from data file to variables
    def Read
      if SCR.Read(path(".target.size"), @filename) != -1
        settings = Convert.convert(
          SCR.Read(path(".target.ycp"), @filename),
          from: "any",
          to:   "map <string, any>"
        )
        Builtins.y2milestone("Read settings: %1", settings)
        @all_failed = Ops.get_list(settings, "all_failed", [])
        @last_failed = Ops.get_list(settings, "last_failed", [])
        @last_done = Ops.get_string(settings, "last_done")
      end

      nil
    end

    # Write data stored in variables to data files
    def Write
      settings = {
        "all_failed"  => @all_failed,
        "last_failed" => @last_failed,
        "last_done"   => @last_done
      }
      SCR.Write(path(".target.ycp"), @filename, settings)
      Builtins.y2milestone("Written settings: %1", settings)
      SCR.Execute(path(".target.bash"), "/bin/sync")

      nil
    end

    # Start operation
    # @param [String] operation to start
    def Run(operation)
      Read()
      if !Builtins.contains(@all_failed, operation)
        @all_failed = Builtins.add(@all_failed, operation)
      end
      if Ops.greater_than(Builtins.size(@this_run_active), 0)
        @last_failed = Builtins.filter(@last_failed) do |f|
          f != Ops.get(@this_run_active, 0)
        end
      end
      @this_run_active = Builtins.prepend(@this_run_active, operation)
      if !Builtins.contains(@last_failed, operation)
        @last_failed = Builtins.add(@last_failed, operation)
      end
      Write()

      nil
    end

    # Finish operation
    # @param [String] operation to finish
    def Finish(operation)
      Read()
      @all_failed = Builtins.filter(@all_failed) { |f| f != operation }
      @this_run_active = Builtins.filter(@this_run_active) { |f| f != operation }
      @last_failed = Builtins.filter(@last_failed) { |f| f != operation }
      if Ops.greater_than(Builtins.size(@this_run_active), 0)
        @last_failed = Builtins.add(@last_failed, Ops.get(@this_run_active, 0))
      end
      @last_done = operation
      Write()

      nil
    end

    # Check whether operation failed
    # @param [String] operation to check
    # @return [Boolean] true if yes
    def Failed(operation)
      Read()
      Builtins.contains(@all_failed, operation)
    end

    # Check whether operation was last started when failed
    # @param [String] operation to check
    # @return [Boolean] true if yes
    def FailedLast(operation)
      Read()
      Builtins.contains(@last_failed, operation)
    end

    # Get last finished operation
    # @return [String] operation name
    def LastFinished
      Read()
      @last_done
    end

    # Check whether operation was last run in moment of last fail.
    # Return whether operation shall be run
    # If not, return true (no reason to think that operation is unsafe),
    # Otherwise ask user
    # @param [String] operation name
    # @param [String] question string question to ask when was unsuccessfull last time
    # @return [Boolean] true if operation shall be started
    def AskRun(operation, question)
      ret = true
      Read()
      ret = Popup.YesNo(question) if FailedLast(operation)
      ret
    end

    publish variable: :filename, type: "string"
    publish function: :Read, type: "void ()"
    publish function: :Write, type: "void ()"
    publish function: :Run, type: "void (string)"
    publish function: :Finish, type: "void (string)"
    publish function: :Failed, type: "boolean (string)"
    publish function: :FailedLast, type: "boolean (string)"
    publish function: :LastFinished, type: "string ()"
    publish function: :AskRun, type: "boolean (string, string)"
  end

  Crash = CrashClass.new
  Crash.main
end
