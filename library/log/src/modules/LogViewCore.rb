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
# File:	modules/LogViewCore.ycp
# Package:	YaST2
# Summary:	Displaying a log
# Authors:	Jiri Srain <jsrain@suse.cz>
#		Arvin Schnell <aschnell@suse.de>
#
# $Id: LogViewCore.ycp 45503 2008-03-17 09:46:23Z aschnell $
require "yast"

module Yast
  class LogViewCoreClass < Module
    def main
      Yast.import "UI"

      textdomain "base"

      Yast.import "Report"

      # default value of maximum displayed lines
      @max_lines_default = 100

      # lines of the log
      @lines = []

      # data describing log:
      #   file:       filename to read from
      #   grep:       grep file with expression
      #   command:    command to run (use instead of file and grep)
      #   max_lines:  max lines to keep (0 -> infinite)
      @data = {}

      # id of background process
      @id = nil

      # flag indicating if background process is (or should be) running
      @is_running = false
    end

    def GetNewLines
      return [] if !@is_running

      if !Convert.to_boolean(SCR.Read(path(".process.running"), @id))
        @is_running = false
        Report.Error(_("Error occurred while reading the log."))
        return []
      end

      new_lines = []

      loop do
        line = Convert.to_string(SCR.Read(path(".process.read_line"), @id))
        break if line.nil?

        new_lines = Builtins.add(new_lines, line)
      end

      deep_copy(new_lines)
    end

    # Remove unneeded items from a list of lines
    # If max_lines is 0, then don't remove anything
    def DeleteOldLines
      max_lines = Ops.get_integer(@data, "max_lines", @max_lines_default)
      return if max_lines == 0

      if Ops.greater_than(
        Ops.subtract(Ops.subtract(Builtins.size(@lines), max_lines), 1),
        0
      )
        @lines = Builtins.sublist(
          @lines,
          Ops.subtract(Ops.subtract(Builtins.size(@lines), max_lines), 1)
        )
      end

      nil
    end

    # Starts the log reading command via process agent.
    #
    # The LogView widget must exist when calling this function. The `MaxLines
    # parameter of the widget will be set.
    def Start(widget, d)
      widget = deep_copy(widget)
      d = deep_copy(d)
      if !@id.nil?
        SCR.Execute(path(".process.release"), @id)
        @id = nil
      end

      @data = deep_copy(d)

      file = Ops.get_string(@data, "file", "")
      grep = Ops.get_string(@data, "grep", "")
      command = Ops.get_string(@data, "command", "")
      max_lines = Ops.get_integer(@data, "max_lines", @max_lines_default)

      if command == ""
        if grep == ""
          command = Builtins.sformat("tail -n %1 -f '%2'", max_lines, file)
        else
          command = Builtins.sformat(
            "tail -n +0 -f '%1' | grep --line-buffered '%2'",
            file,
            grep
          )

          if max_lines != 0
            lc_command = Builtins.sformat(
              "cat '%1' | grep '%2' | wc -l",
              file,
              grep
            )
            bash_output = Convert.to_map(
              SCR.Execute(path(".target.bash_output"), lc_command)
            )
            if Ops.get_integer(bash_output, "exit", 1) == 0
              lc = Builtins.filterchars(
                Ops.get_string(bash_output, "stdout", ""),
                "1234567890"
              )
              lines_count = Builtins.tointeger(lc)

              # don't know why without doubling it discards more lines,
              # out of YaST2 it works
              lines_count = Ops.subtract(
                lines_count,
                Ops.multiply(2, max_lines)
              )
              lines_count = 0 if Ops.less_than(lines_count, 0)

              if Ops.greater_than(lines_count, 0)
                command = Ops.add(
                  command,
                  Builtins.sformat(" | tail -n +%1", lines_count)
                )
              end
            end
          end
        end
      end

      Builtins.y2milestone("Calling process agent with command %1", command)

      @id = Convert.to_integer(
        SCR.Execute(path(".process.start_shell"), command, "tty" => true)
      )
      @is_running = true

      Builtins.sleep(100)

      @lines = GetNewLines()
      DeleteOldLines()

      UI.ChangeWidget(widget, :MaxLines, max_lines)
      UI.ChangeWidget(
        widget,
        :Value,
        Builtins.mergestring(Builtins.maplist(@lines) do |line|
          Ops.add(line, "\n")
        end, "")
      )

      nil
    end

    def Update(widget)
      widget = deep_copy(widget)
      if !@id.nil?
        new_lines = GetNewLines()
        if Ops.greater_than(Builtins.size(new_lines), 0)
          @lines = Convert.convert(
            Builtins.merge(@lines, new_lines),
            from: "list",
            to:   "list <string>"
          )
          DeleteOldLines()

          UI.ChangeWidget(
            widget,
            :LastLine,
            Builtins.mergestring(Builtins.maplist(new_lines) do |line|
              Ops.add(line, "\n")
            end, "")
          )
        end
      end

      nil
    end

    def Stop
      if !@id.nil?
        SCR.Execute(path(".process.release"), @id)
        @id = nil
      end

      nil
    end

    def GetLines
      deep_copy(@lines)
    end

    publish function: :Start, type: "void (term, map <string, any>)"
    publish function: :Update, type: "void (term)"
    publish function: :Stop, type: "void ()"
    publish function: :GetLines, type: "list <string> ()"
  end

  LogViewCore = LogViewCoreClass.new
  LogViewCore.main
end
