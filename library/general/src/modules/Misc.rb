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
# Module:
#	Misc
# File:
#	Misc.ycp
# Purpose:
#	miscellaneous definitions for installation
# Author:	Klaus Kaempf <kkaempf@suse.de>
# $Id$
require "yast"

module Yast
  class MiscClass < Module
    def main
      Yast.import "UI"

      Yast.import "Mode"

      # Message after finishing installation and before the system
      # boots for the first time.
      #
      @boot_msg = ""
    end

    # @param [String] first	string	name of first file to try
    # @param [String] second	string	name of second file to try
    # @return	[Object]	content of file
    #
    # try to read first file, if it doesn't exist, read second
    # files must reside below /usr/lib/YaST2
    # files must have ycp syntax

    def ReadAlternateFile(first, second)
      result = SCR.Read(path(".target.yast2"), [first, nil])
      result = SCR.Read(path(".target.yast2"), second) if result.nil?
      deep_copy(result)
    end

    # @param [Hash] hardware_entry	map	map of .probe entry
    # @return	[String]	vendor and device name
    #
    # common function to extract 'name' of hardware

    def hardware_name(hardware_entry)
      hardware_entry = deep_copy(hardware_entry)
      sub_vendor = Ops.get_string(hardware_entry, "sub_vendor", "")
      sub_device = Ops.get_string(hardware_entry, "sub_device", "")

      if sub_vendor != "" && sub_device != ""
        return Ops.add(Ops.add(sub_vendor, "\n"), sub_device)
      else
        vendor = Ops.get_string(hardware_entry, "vendor", "")
        return Ops.add(
          Ops.add(vendor, vendor != "" ? "\n" : ""),
          Ops.get_string(hardware_entry, "device", "")
        )
      end
    end

    # @param [Hash] lmap	map	map of language codes and translations
    #				e.g. $[ "default" : "Defaultstring", "de" : "German....", ...]
    # @param [String] lang	string	language as ISO code, either 2 chars (de)
    #				or 5 chars (de_DE)
    # @return	[String]		translation
    #
    # Define a macro that looks up a localized string in a language map
    # of the form $[ "default" : "Defaultstring", "de" : "German....", ...]

    def translate(lmap, lang)
      lmap = deep_copy(lmap)
      t = Ops.get_string(lmap, lang, "")
      if Builtins.size(t) == 0 && Ops.greater_than(Builtins.size(lang), 2)
        t = Ops.get_string(lmap, Builtins.substring(lang, 0, 2), "")
      end
      t = Ops.get_string(lmap, "default", "") if Builtins.size(t) == 0

      t
    end

    # SysconfigWrite()
    # @param [Yast::Path] level	path behind .sysconfig for all values
    # @param [Array<Array>] values	list of [ .NAME, value] lists
    #
    # @return [Boolean]		false if SCR::Write reported error
    #
    # write list of sysyconfig entries via rcconfig agent

    def SysconfigWrite(level, values)
      values = deep_copy(values)
      result = true
      level = if level == path(".")
        path(".sysconfig")
              else
        Ops.add(path(".sysconfig"), level)
      end

      Builtins.foreach(values) do |entry|
        if Builtins.size(entry) != 2
          Builtins.y2error("bad entry in rc_write()")
        else
          if !SCR.Write(
            Ops.add(level, Ops.get_path(entry, 0, path("."))),
            Ops.get_string(entry, 1, "")
          )
            result = false
          end
        end
      end
      result
    end

    # MergeOptions
    # Merges "opt1=val1 opt2=val2 ..." and $["opta":"vala", ..."]
    # to $["opt1":"val1", "opt2":"val2", "opta":"vala", ...]
    # as needed by modules.conf agent
    # @param [String] options	string	module options, e.g. "opt1=val1 opt2=val2 ..."
    # @param [Hash] optmap	map	possible old options $["opta":"vala", ...]
    # @return [Hash]	$["opt1":"val1", "opt2":"val2", ...]

    def SplitOptions(options, optmap)
      optmap = deep_copy(optmap)
      # step 1: split "opt1=val1 opt2=val2 ..."
      # to ["opt1=val1", "opt2=val2", "..."]

      options_split = Builtins.splitstring(options, " ")

      Builtins.foreach(options_split) do |options_element|
        options_values = Builtins.splitstring(options_element, "=")
        if Builtins.size(options_values) == 1 &&
            Ops.get_string(optmap, options_element, "") == ""
          # single argument
          Ops.set(optmap, options_element, "")
        elsif Builtins.size(options_values) == 2
          # argument with value
          Ops.set(
            optmap,
            Ops.get_string(options_values, 0, ""),
            Ops.get_string(options_values, 1, "")
          )
        end
      end
      deep_copy(optmap)
    end

    # SysconfigRead()
    #
    # Try an SCR::Read(...) and return the result if successful.
    # On failure return the the second parameter (default value)
    #
    # @param [Yast::Path] sysconfig_path   Sysconfig SCR path.
    # @param [String] defaultv         Default value
    #
    # @return  Success --> Result of SCR::Read<br>
    #		Failure --> Default value
    #

    def SysconfigRead(sysconfig_path, defaultv)
      local_ret = Convert.to_string(SCR.Read(sysconfig_path))

      if local_ret.nil?
        Builtins.y2warning(
          "Failed reading '%1', using default value",
          sysconfig_path
        )
        return defaultv
      else
        Builtins.y2milestone("%1: '%2'", sysconfig_path, local_ret)
        return local_ret
      end
    end # SysconfigRead()

    # Try to read value from sysconfig file and return the result if successful.
    # Function reads from arbitrary sysconfig file, for which the agent
    # doesn't exist: e.g. from different partition like /mnt/etc/sysconfig/file.
    #
    # @param [String] key		Key of the value we want to read from sysconfig file.
    # @param	defaultv        Default value
    # @param [String] location	Full path to target sysconfig file.
    #
    # @return  Success --> Result of SCR::Read<br>
    #		Failure --> Default value
    #
    # @example Misc::CustomSysconfigRead ("INSTALLED_LANGUAGES", "", Installation::destdir + "/etc/sysconfig/language");
    #
    def CustomSysconfigRead(key, defval, location)
      return defval if location == ""

      custom_path = Builtins.topath(location)
      SCR.RegisterAgent(
        custom_path,
        term(:ag_ini, term(:SysConfigFile, location))
      )
      ret = SysconfigRead(Builtins.add(custom_path, key), defval)
      SCR.UnregisterAgent(custom_path)
      ret
    end

    # Runs a bash command with timeout.
    #
    # **Structure:**
    #
    #     Returns map $[
    #          "exit" : int_return_code,
    #          "stdout"  : [ "script", "stdout", "lines" ],
    #          "stderr"  : [ "script", "stderr", "lines" ],
    #      ]
    #
    # @param [String] run_command what to run
    # @param [String] log_command what to log (passwords masked)
    # @param [Fixnum] script_time_out in sec.
    # @return [Hash] with out, err and ret_code
    def RunCommandWithTimeout(run_command, log_command, script_time_out)
      Builtins.y2milestone(
        "Running command \"%1\" in background...",
        log_command
      )

      processID = Convert.to_integer(
        SCR.Execute(path(".process.start_shell"), run_command)
      )

      if processID == 0
        Builtins.y2error("Cannot run '%1'", run_command)
        return nil
      end

      script_out = []
      script_err = []
      time_spent = 0
      return_code = nil
      timed_out = false
      sleep_step = 200 # ms
      script_time_out = Ops.multiply(script_time_out, 1000)

      # while continuing is needed and while it is possible
      until timed_out
        running = Convert.to_boolean(
          SCR.Read(path(".process.running"), processID)
        )
        # debugging #165821
        if Ops.modulo(time_spent, 100_000) == 0
          Builtins.y2milestone("running: %1", running)
          flag = "/tmp/SourceManagerTimeout"
          if SCR.Read(path(".target.size"), flag) != -1
            Builtins.y2milestone("Emergency exit")
            SCR.Execute(path(".target.remove"), flag)
            break
          end
        end

        break if !running

        # at last, enable aborting the sync
        if Mode.commandline
          Builtins.sleep(sleep_step)
        else
          ui = UI.TimeoutUserInput(sleep_step)
          if ui == :abort
            Builtins.y2milestone("aborted")
            timed_out = true
            break
          end
        end

        # time-out
        if Ops.greater_or_equal(time_spent, script_time_out)
          Builtins.y2error("Command timed out after %1 msec", time_spent)
          timed_out = true
        end

        time_spent = Ops.add(time_spent, sleep_step)
      end
      Builtins.y2milestone("Time spent: %1 msec", time_spent)

      # fetching the return code if not timed-out
      if !timed_out
        Builtins.y2milestone("getting output")
        script_out = Builtins.splitstring(
          Convert.to_string(SCR.Read(path(".process.read"), processID)),
          "\n"
        )
        Builtins.y2milestone("getting errors")
        script_err = Builtins.splitstring(
          Convert.to_string(SCR.Read(path(".process.read_stderr"), processID)),
          "\n"
        )
        Builtins.y2milestone("getting status")
        return_code = Convert.to_integer(
          SCR.Read(path(".process.status"), processID)
        )
      end
      Builtins.y2milestone("killing")
      SCR.Execute(path(".process.kill"), processID)

      # release the process from the agent
      SCR.Execute(path(".process.release"), processID)

      command_ret = {
        "exit"   => return_code,
        "stdout" => script_out,
        "stderr" => script_err
      }
      Ops.set(command_ret, "timed_out", time_spent) if timed_out
      deep_copy(command_ret)
    end

    # Run
    # - with a timeout
    # - on dumb terminal to disable colors etc
    # - using 'exit $?' because of buggy behavior '.background vs. ZMD' (FIXME still needed???)
    # @param [String] command a command
    # @param [String] log_command a command to log
    # @param [Fixnum] seconds timeout
    # @return [Hash] with out, err and ret_code
    def RunDumbTimeout(command, log_command, seconds)
      dumb_format = "export TERM=dumb; %1; exit $?"
      dumb_command = Builtins.sformat(dumb_format, command)
      dumb_log_command = Builtins.sformat(dumb_format, log_command)
      # explicit export in case TERM was not in the environment
      ret = RunCommandWithTimeout(dumb_command, dumb_log_command, seconds)
      ret = {} if ret.nil?
      deep_copy(ret)
    end

    publish variable: :boot_msg, type: "string"
    publish function: :ReadAlternateFile, type: "any (string, string)"
    publish function: :hardware_name, type: "string (map)"
    publish function: :translate, type: "string (map, string)"
    publish function: :SysconfigWrite, type: "boolean (path, list <list>)"
    publish function: :SplitOptions, type: "map (string, map)"
    publish function: :SysconfigRead, type: "string (path, string)"
    publish function: :CustomSysconfigRead, type: "string (string, string, string)"
    publish function: :RunCommandWithTimeout, type: "map (string, string, integer)"
    publish function: :RunDumbTimeout, type: "map (string, string, integer)"
  end

  Misc = MiscClass.new
  Misc.main
end
