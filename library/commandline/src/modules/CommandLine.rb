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
# File:	modules/CommandLine.ycp
# Package:	yast2
# Summary:	Command line interface for YaST2 modules
# Author:	Stanislav Visnovsky <visnov@suse.cz>
#
# $Id$
require "yast"

module Yast
  class CommandLineClass < Module
    def main
      Yast.import "Directory"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Stage"
      Yast.import "String"
      Yast.import "Integer"
      Yast.import "TypeRepository"
      Yast.import "XML"

      textdomain "base"

      @cmdlineprompt = "YaST2 > "

      # Map of commands for every module. ATM the list of commands this module handles internally.
      @systemcommands = {
        "actions"  => {
          "help"        => {
            # translators: help for 'help' option on command line
            "help" => _(
              "Print the help for this module"
            )
          },
          "longhelp"    => {
            # translators: help for 'longhelp' option on command line
            "help" => _(
              "Print a long version of help for this module"
            )
          },
          "xmlhelp"     => {
            # translators: help for 'xmlhelp' option on command line
            "help" => _(
              "Print a long version of help for this module in XML format"
            )
          },
          "interactive" => {
            # translators: help for 'interactive' option on command line
            "help" => _(
              "Start interactive shell to control the module"
            )
          },
          "exit"        => {
            # translators: help for 'exit' command line interactive mode
            "help" => _(
              "Exit interactive mode and save the changes"
            )
          },
          "abort"       => {
            # translators: help for 'abort' command line interactive mode
            "help" => _(
              "Abort interactive mode without saving the changes"
            )
          }
        },
        "options"  => {
          "help"    => {
            # translators:  command line "help" option
            "help" => _(
              "Print the help for this command"
            )
          },
          "verbose" => {
            # translators: command line "verbose" option
            "help" => _(
              "Show progress information"
            )
          },
          "xmlfile" => {
            # translators: command line "xmlfile" option
            "help" => _(
              "Where to store the XML output"
            ),
            "type" => "string"
          }
        },
        "mappings" => {
          "help"        => ["help", "verbose"],
          "xmlhelp"     => ["help", "verbose", "xmlfile"],
          "interactive" => ["help", "verbose"],
          "exit"        => ["help"],
          "abort"       => ["help"]
        }
      }

      # Map of commands defined by the YaST2 module.
      @modulecommands = {}

      # Merged map of commands - both defined by the YaST2 module and system commands. Used for lookup
      @allcommands = deep_copy(@systemcommands)

      # User asked for interactive session
      @interactive = false

      # All commands have been processed
      @done = false

      # User asked for quitting of interactive session, or there was an error
      @aborted = false

      # a cache for already parsed but not processed command
      @commandcache = {}

      # Verbose mode flag
      @verbose = false

      # Remember the command line specification for later use
      @cmdlinespec = {}

      # string: command line interface is not supported
      @nosupport = _(
        "This YaST2 module does not support the command line interface."
      )
    end

    #  Print a String
    #
    #  Print a string to /dev/tty in interactive mode, to stderr in non-interactive
    #  Suppress printing if there are no commands to be handled (starting GUI)
    #
    #  @param [String] s	the string to be printed
    def PrintInternal(s, newline)
      return if !Mode.commandline

      # avoid using of uninitialized value in .dev.tty perl agent
      if s.nil?
        Builtins.y2warning("CommandLine::Print: invalid argument (nil)")
        return
      end

      if @interactive
        if newline
          SCR.Write(path(".dev.tty"), s)
        else
          SCR.Write(path(".dev.tty.nocr"), s)
        end
      else
        if newline
          SCR.Write(path(".dev.tty.stderr"), s)
        else
          SCR.Write(path(".dev.tty.stderr_nocr"), s)
        end
      end

      nil
    end

    #  Print a String
    #
    #  Print a string to /dev/tty in interactive mode, to stderr in non-interactive
    #  Suppress printing if there are no commands to be handled (starting GUI)
    #
    #  @param [String] s	the string to be printed
    def Print(s)
      PrintInternal(s, true)
    end

    #  Print a String, don't add a trailing newline character
    #
    #  Print a string to /dev/tty in interactive mode, to stderr in non-interactive
    #  Suppress printing if there are no commands to be handled (starting GUI)
    #
    #  @param [String] s	the string to be printed
    def PrintNoCR(s)
      PrintInternal(s, false)
    end

    # Same as Print(), but the string is printed only when verbose command
    # line mode was activated
    # @param [String] s string to print
    def PrintVerbose(s)
      Print(s) if @verbose

      nil
    end

    # Same as PrintNoCR(), but the string is printed only when verbose command
    # line mode was activated
    # @param [String] s string to print
    def PrintVerboseNoCR(s)
      PrintNoCR(s) if @verbose

      nil
    end

    #  Print a Table
    #
    #  Print a table using Print(). Format of table is as libyui but not all features
    #  are supported, e.g. no icons.
    #
    #  @param [Yast::Term] header	header of table in libyui format
    #  @param [Array<Yast::Term>] content	content of table in libyui format
    def PrintTable(header, content)
      header = deep_copy(header)
      content = deep_copy(content)
      aligns = []
      widths = []

      process = lambda do |line|
        line = deep_copy(line)
        ret = []
        anys = Builtins.argsof(line)
        Builtins.foreach(anys) do |a|
          if Ops.is_string?(a)
            s = Convert.to_string(a)
            ret = Builtins.add(ret, s)
          elsif Ops.is_term?(a)
            t = Convert.to_term(a)
            if Builtins.contains([:Left, :Center, :Right], Builtins.symbolof(t))
              ret = Builtins.add(ret, Ops.get_string(Builtins.argsof(t), 0, ""))
            end
          end
        end
        deep_copy(ret)
      end

      get_aligns = lambda do |header2|
        header2 = deep_copy(header2)
        anys = Builtins.argsof(header2)
        Builtins.foreach(Integer.Range(Builtins.size(anys))) do |i|
          a = Ops.get(anys, i)
          if Ops.is_term?(a)
            t = Convert.to_term(a)
            Ops.set(aligns, i, :right) if Builtins.symbolof(t) == :Right
          end
        end

        nil
      end

      update_widths = lambda do |columns|
        columns = deep_copy(columns)
        Builtins.foreach(Integer.Range(Builtins.size(columns))) do |i|
          Ops.set(
            widths,
            i,
            Integer.Max(
              [Ops.get(widths, i, 0), Builtins.size(Ops.get(columns, i, ""))]
            )
          )
        end

        nil
      end

      print_line = lambda do |line|
        line = deep_copy(line)
        columns = process.call(line)
        Builtins.foreach(Integer.Range(Builtins.size(columns))) do |i|
          Ops.set(
            columns,
            i,
            String.SuperPad(
              Ops.get(columns, i, ""),
              Ops.get(widths, i, 0),
              " ",
              Ops.get(aligns, i, :left)
            )
          )
        end
        Print(Builtins.mergestring(columns, " | "))

        nil
      end

      update_widths.call(process.call(header))
      Builtins.foreach(content) { |row| update_widths.call(process.call(row)) }

      print_line.call(header)

      get_aligns.call(header)

      Print(Builtins.mergestring(Builtins.maplist(widths) do |width|
        String.Repeat("-", width)
      end, "-+-"))

      Builtins.foreach(content) { |row| print_line.call(row) }

      nil
    end

    # Print an Error Message
    #
    # Print an error message and add the description how to get the help.
    # @param [String] message	error message to be printed. Use nil for no message
    def Error(message)
      Print(message) if !message.nil?

      if @interactive
        # translators: default error message for command line
        Print(_("Use 'help' for a complete list of available commands."))
      else
        # translators: default error message for command line
        Print(
          Builtins.sformat(
            _("Use 'yast2 %1 help' for a complete list of available commands."),
            Ops.get_string(@modulecommands, "id", "")
          )
        )
      end

      nil
    end

    #  Parse a list of arguments.
    #
    #  It checks the validity of the arguments, the type correctness
    #  and returns the command and its options in a map.
    #  @param [Array] arguments	the list of arguments to be parsed
    #  @return [Hash{String => Object}]	containing the command and it's option. In case of
    #				error it is an empty map.
    def Parse(arguments)
      arguments = deep_copy(arguments)
      args = deep_copy(arguments)
      return {} if Ops.less_than(Builtins.size(args), 1)

      # Parse command
      command = Ops.get_string(args, 0, "")
      Builtins.y2debug("command=%1", command)
      args = Builtins.remove(args, 0)
      Builtins.y2debug("args=%1", args)

      if command == ""
        Builtins.y2error(
          "CommandLine::Parse called with first parameter being empty. Arguments passed: %1",
          arguments
        )
        return {}
      end

      # Check command
      if !Builtins.haskey(Ops.get_map(@allcommands, "actions", {}), command)
        # translators: error message in command line interface
        Error(Builtins.sformat(_("Unknown Command: %1"), command))

        return { "command" => command }
      end

      # build the list of options for the command
      opts = Ops.get_list(@allcommands, ["mappings", command], [])
      allopts = Ops.get_map(@allcommands, "options", {})
      cmdoptions = {}
      Builtins.maplist(opts) do |k|
        if Ops.is_string?(k)
          cmdoptions = Builtins.add(cmdoptions, k, Ops.get_map(allopts, k, {}))
        end
      end

      ret = true

      # Parse options
      givenoptions = {}
      Builtins.maplist(args) do |aos|
        Builtins.y2debug("os=%1", aos)
        next if !Ops.is_string?(aos)
        os = Convert.to_string(aos)
        o = Builtins.regexptokenize(os, "([^=]+)=(.+)")
        Builtins.y2debug("o=%1", o)
        if Builtins.size(o) == 2
          givenoptions = Builtins.add(
            givenoptions,
            Ops.get(o, 0, ""),
            Ops.get(o, 1, "")
          )
        elsif Builtins.size(o) == 0
          # check, if the last character is "="
          # FIXME: consider whitespace
          if Builtins.substring(os, Ops.subtract(Builtins.size(os), 1)) == "="
            # translators: error message - user did not provide a value for option %1 on the command line
            Print(
              Builtins.sformat(
                _("Option '%1' is missing value."),
                Builtins.substring(os, 0, Ops.subtract(Builtins.size(os), 1))
              )
            )
            @aborted = true if !@interactive
            ret = false
            next {}
          else
            givenoptions = Builtins.add(givenoptions, os, "")
          end
        end
      end

      return {} if ret != true

      Builtins.y2debug("options=%1", givenoptions)

      # Check options

      # find out, if the action has a "non-strict" option set
      non_strict = Builtins.contains(
        Ops.get_list(@allcommands, ["actions", command, "options"], []),
        "non_strict"
      )
      Builtins.y2debug("Using non-strict check for %1", command) if non_strict

      # check (and convert data types)
      Builtins.maplist(givenoptions) do |o, val|
        v = Convert.to_string(val)
        next if ret != true
        if Ops.get(cmdoptions, o).nil?
          if !non_strict
            # translators: error message, %1 is a command, %2 is the wrong option given by the user
            Print(
              Builtins.sformat(
                _("Unknown option for command '%1': %2"),
                command,
                o
              )
            )
            @aborted = true if !@interactive
            ret = false
          end
        else
          # this option is valid, let's check the type

          opttype = Ops.get_string(cmdoptions, [o, "type"], "")

          if opttype != ""
            # need to check the type
            if opttype == "regex"
              opttypespec = Ops.get_string(cmdoptions, [o, "typespec"], "")
              ret = TypeRepository.regex_validator(opttypespec, v)
              if ret != true
                # translators: error message, %2 is the value given
                Print(
                  Builtins.sformat(_("Invalid value for option '%1': %2"), o, v)
                )
                @aborted = true if !@interactive
              end
            elsif opttype == "enum"
              ret = TypeRepository.enum_validator(
                Ops.get_list(cmdoptions, [o, "typespec"], []),
                v
              )
              if ret != true
                # translators: error message, %2 is the value given
                Print(
                  Builtins.sformat(_("Invalid value for option '%1': %2"), o, v)
                )
                @aborted = true if !@interactive
              end
            elsif opttype == "integer"
              i = Builtins.tointeger(v)
              ret = !i.nil?
              if ret != true
                # translators: error message, %2 is the value given
                Print(
                  Builtins.sformat(_("Invalid value for option '%1': %2"), o, v)
                )
                @aborted = true if !@interactive
              else
                # update value of the option to integer
                Ops.set(givenoptions, o, i)
              end
            else
              if v == ""
                ret = false
              else
                ret = TypeRepository.is_a(v, opttype)
              end

              if ret != true
                # translators: error message, %2 is expected type, %3 is the value given
                Print(
                  Builtins.sformat(
                    _(
                      "Invalid value for option '%1' -- expected '%2', received %3"
                    ),
                    o,
                    opttype,
                    v
                  )
                )
                @aborted = true if !@interactive
              end
            end
          else
            # type is missing
            if v != ""
              Builtins.y2error(
                "Type specification for option '%1' is missing, cannot assign a value to the option",
                o
              )
              # translators: error message if option has a value, but cannot have one
              Print(
                Builtins.sformat(
                  _("Option '%1' cannot have a value. Given value: %2"),
                  o,
                  v
                )
              )
              @aborted = true if !@interactive
              ret = false
            end
          end
        end
      end

      # wrong, let's print the help message
      if ret != true
        if @interactive
          # translators: error message, how to get command line help for interactive mode
          # %1 is the module name, %2 is the action name
          Print(
            Builtins.sformat(
              _("Use '%1 %2 help' for a complete list of available options."),
              Ops.get_string(@modulecommands, "id", ""),
              command
            )
          )
        else
          # translators: error message, how to get command line help for non-interactive mode
          # %1 is the module name, %2 is the action name
          Print(
            Builtins.sformat(
              _(
                "Use 'yast2 %1 %2 help' for a complete list of available options."
              ),
              Ops.get_string(@modulecommands, "id", ""),
              command
            )
          )
        end
        return {}
      end

      { "command" => command, "options" => givenoptions }
    end

    # Print a nice heading for this module
    def PrintHead
      # translators: command line interface header, %1 is identification of the module
      head = Builtins.sformat(
        _("YaST Configuration Module %1\n"),
        Ops.get_string(@modulecommands, "id", "YaST")
      )
      headlen = Builtins.size(head)
      i = 0
      while Ops.less_than(i, headlen)
        head = Ops.add(head, "-")
        i = Ops.add(i, 1)
      end
      head = Ops.add(Ops.add("\n", head), "\n")

      Print(head)

      nil
    end

    # Print a help text for a given action.
    #
    # @param [String] action the action for which the help should be printed
    def PrintActionHelp(action)
      # lookup action in actions
      command = Ops.get_map(@allcommands, ["actions", action], {})
      # translators: the command does not provide any help
      commandhelp = Ops.get(command, "help")
      commandhelp = _("No help available") if commandhelp.nil?
      has_string_option = false
      # Process <command> "help"
      # translators: %1 is the command name
      Print(Builtins.sformat(_("Command '%1'"), action))

      # print help
      if Ops.is_string?(commandhelp)
        Print(Builtins.sformat("    %1", commandhelp))
      elsif Ops.is(commandhelp, "list <string>")
        Builtins.foreach(
          Convert.convert(commandhelp, from: "any", to: "list <string>")
        ) { |e| Print(Builtins.sformat("    %1", e)) }
      end

      opts = Ops.get_list(@allcommands, ["mappings", action], [])

      # no options, skip the rest
      if Builtins.size(opts) == 0
        Print("")
        return
      end

      # translators: command line options
      Print(_("\n    Options:"))

      allopts = Ops.get_map(@allcommands, "options", {})

      longestopt = 0
      longestarg = 0

      Builtins.foreach(opts) do |opt|
        op = Ops.get_map(allopts, opt, {})
        t = Ops.get_string(op, "type", "")
        has_string_option = true if t == "string"
        if t != "regex" && t != "enum" && t != ""
          t = Ops.add(Ops.add("[", t), "]")
        elsif t == "enum"
          t = "[ "
          Builtins.foreach(Ops.get_list(op, "typespec", [])) do |s|
            t = Ops.add(Ops.add(t, s), " ")
          end
          t = Ops.add(t, "]")
        end
        if Ops.greater_than(Builtins.size(t), longestarg)
          longestarg = Builtins.size(t)
        end
        if Ops.is_string?(opt) &&
            Ops.greater_than(Builtins.size(Convert.to_string(opt)), longestopt)
          longestopt = Builtins.size(Convert.to_string(opt))
        end
      end

      Builtins.foreach(opts) do |opt|
        op = Ops.get_map(allopts, opt, {})
        t = Ops.get_string(op, "type", "")
        if t != "regex" && t != "enum" && t != ""
          t = Ops.add(Ops.add("[", t), "]")
        elsif t == "enum"
          t = "[ "
          Builtins.foreach(Ops.get_list(op, "typespec", [])) do |s|
            t = Ops.add(Ops.add(t, s), " ")
          end
          t = Ops.add(t, "]")
        else
          t = "    "
        end
        if Ops.is_string?(opt)
          helptext = ""
          opthelp = Ops.get(op, "help")

          if Ops.is_string?(opthelp)
            helptext = Convert.to_string(opthelp)
          elsif Ops.is(opthelp, "map <string, string>")
            helptext = Ops.get(
              Convert.convert(
                opthelp,
                from: "any",
                to:   "map <string, string>"
              ),
              action,
              ""
            )
          elsif Ops.is(opthelp, "list <string>")
            delim = Builtins.sformat(
              "\n        %1  %2  ",
              String.Pad("", longestopt),
              String.Pad("", longestarg)
            )
            helptext = Builtins.mergestring(
              Convert.convert(opthelp, from: "any", to: "list <string>"),
              delim
            )
          else
            Builtins.y2error(
              "Invalid data type of help text, only 'string' or 'map<string,string>' types are allowed."
            )
          end

          Print(
            Builtins.sformat(
              "        %1  %2  %3",
              String.Pad(Convert.to_string(opt), longestopt),
              String.Pad(t, longestarg),
              helptext
            )
          )
        end
      end

      if has_string_option
        # additional help for using command line
        Print(
          _(
            "\n    Options of the [string] type must be written in the form 'option=value'."
          )
        )
      end
      if Builtins.haskey(command, "example")
        # translators: example title for command line
        Print(_("\n    Example:"))

        example = Ops.get(command, "example")

        if Ops.is_string?(example)
          Print(Builtins.sformat("        %1", example))
        elsif Ops.is(example, "list <string>")
          Builtins.foreach(
            Convert.convert(example, from: "any", to: "list <string>")
          ) { |e| Print(Builtins.sformat("        %1", e)) }
        else
          Builtins.y2error("Unsupported data type - value: %1", example)
        end
      end
      Print("")

      nil
    end

    # Print a general help - list of available command.
    def PrintGeneralHelp
      # display custom defined help instead of generic one
      if Builtins.haskey(@modulecommands, "customhelp")
        Print(Ops.get_string(@modulecommands, "customhelp", ""))
        return
      end

      # translators: default module description if none is provided by the module itself
      Print(
        Ops.add(
          Ops.get_locale(@modulecommands, "help", _("This is a YaST module.")),
          "\n"
        )
      )
      # translators: short help title for command line
      Print(_("Basic Syntax:"))

      if !@interactive
        # translators: module command line help, %1 is the module name
        Print(
          Builtins.sformat(
            "    yast2 %1 interactive",
            Ops.get_string(@modulecommands, "id", "")
          )
        )

        # translators: module command line help, %1 is the module name
        # translate <command> and [options] only!
        Print(
          Builtins.sformat(
            _("    yast2 %1 <command> [verbose] [options]"),
            Ops.get_string(@modulecommands, "id", "")
          )
        )
        # translators: module command line help, %1 is the module name
        Print(
          Builtins.sformat(
            "    yast2 %1 help",
            Ops.get_string(@modulecommands, "id", "")
          )
        )
        Print(
          Builtins.sformat(
            "    yast2 %1 longhelp",
            Ops.get_string(@modulecommands, "id", "")
          )
        )
        Print(
          Builtins.sformat(
            "    yast2 %1 xmlhelp",
            Ops.get_string(@modulecommands, "id", "")
          )
        )
        # translators: module command line help, %1 is the module name
        # translate <command> only!
        Print(
          Builtins.sformat(
            _("    yast2 %1 <command> help"),
            Ops.get_string(@modulecommands, "id", "")
          )
        )
      else
        # translators: module command line help
        # translate <command> and [options] only!
        Print(_("    <command> [options]"))
        # translators: module command line help
        # translate <command> only!
        Print(_("    <command> help"))
        # translators: module command line help
        Print("    help")
        Print("    longhelp")
        Print("    xmlhelp")
        Print("")
        Print("    exit")
        Print("    abort")
      end

      Print("")
      # translators: command line title: list of available commands
      Print(_("Commands:"))

      longest = 0
      Builtins.foreach(Ops.get_map(@modulecommands, "actions", {})) do |action, _desc|
        if Ops.greater_than(Builtins.size(action), longest)
          longest = Builtins.size(action)
        end
      end

      Builtins.maplist(Ops.get_map(@modulecommands, "actions", {})) do |cmd, desc|
        if !Builtins.haskey(desc, "help")
          # translators: error message: module does not provide any help messages
          Print(
            Builtins.sformat(
              "    %1  %2",
              String.Pad(cmd, longest),
              _("No help available.")
            )
          )
        end
        if Ops.is_string?(Ops.get(desc, "help"))
          Print(
            Builtins.sformat(
              "    %1  %2",
              String.Pad(cmd, longest),
              Ops.get_string(desc, "help", "")
            )
          )
        # multiline help text
        elsif Ops.is(Ops.get(desc, "help"), "list <string>")
          help = Ops.get_list(desc, "help", [])

          if Ops.greater_than(Builtins.size(help), 0)
            Print(
              Builtins.sformat(
                "    %1  %2",
                String.Pad(cmd, longest),
                Ops.get(help, 0, "")
              )
            )
            help = Builtins.remove(help, 0)
          end

          Builtins.foreach(help) do |h|
            Print(Builtins.sformat("    %1  %2", String.Pad("", longest), h))
          end
        else
          # fallback message - invalid help has been provided by the yast module
          Print(
            Builtins.sformat(
              "    %1  %2",
              String.Pad(cmd, longest),
              _("<Error: invalid help>")
            )
          )
        end
      end
      Print("")
      if !@interactive
        # translators: module command line help, %1 is the module name
        Print(
          Builtins.sformat(
            _("Run 'yast2 %1 <command> help' for a list of available options."),
            Ops.get_string(@modulecommands, "id", "")
          )
        )
        Print("")
      end

      nil
    end

    # Handle the system-wide commands, like help etc.
    #
    # @param [Hash] command	a map of the current command
    # @return		true, if the command was handled
    def ProcessSystemCommands(command)
      command = deep_copy(command)
      # handle help for specific command
      # this needs to be before general help, so "help help" works
      if Ops.get(command, ["options", "help"])
        PrintHead()
        PrintActionHelp(Ops.get_string(command, "command", ""))
        return true
      end

      # Process command "interactive"
      if Ops.get_string(command, "command", "") == "interactive"
        @interactive = true
        return true
      end

      # Process command "exit"
      if Ops.get_string(command, "command", "") == "exit"
        @done = true
        @aborted = false
        return true
      end

      # Process command "abort"
      if Ops.get_string(command, "command", "") == "abort"
        @done = true
        @aborted = true
        return true
      end

      if Ops.get_string(command, "command", "") == "help"
        # don't print header when custom help is defined
        PrintHead() if !Builtins.haskey(@modulecommands, "customhelp")
        PrintGeneralHelp()
        return true
      end

      if Ops.get_string(command, "command", "") == "longhelp"
        PrintHead()
        PrintGeneralHelp()
        Builtins.foreach(Ops.get_map(@allcommands, "actions", {})) do |action, _def|
          PrintActionHelp(action)
        end
        return true
      end

      if Ops.get_string(command, "command", "") == "xmlhelp"
        if Builtins.haskey(Ops.get_map(command, "options", {}), "xmlfile") == false
          # error message - command line option xmlfile is missing
          Print(
            _(
              "Target file name ('xmlfile' option) is missing. Use xmlfile=<target_XML_file> command line option."
            )
          )
          return false
        end

        xmlfilename = Ops.get_string(command, ["options", "xmlfile"], "")

        if xmlfilename.nil? || xmlfilename == ""
          # error message - command line option xmlfile is missing
          Print(
            _(
              "Target file name ('xmlfile' option) is empty. Use xmlfile=<target_XML_file> command line option."
            )
          )
          return false
        end

        doc = {}

        #	    TODO: DTD specification
        Ops.set(
          doc,
          "listEntries",

          "commands" => "command",
          "options"  => "option",
          "examples" => "example"

        )
        #	    doc["cdataSections"] = [];
        Ops.set(
          doc,
          "systemID",
          Ops.add(Directory.schemadir, "/commandline.dtd")
        )
        #	    doc["nameSpace"] = "http://www.suse.com/1.0/yast2ns";
        Ops.set(doc, "typeNamespace", "http://www.suse.com/1.0/configns")

        Ops.set(doc, "rootElement", "commandline")
        XML.xmlCreateDoc(:xmlhelp, doc)

        exportmap = {}
        commands = []

        actions = Ops.get_map(@cmdlinespec, "actions", {})
        mappings = Ops.get_map(@cmdlinespec, "mappings", {})
        options = Ops.get_map(@cmdlinespec, "options", {})

        Builtins.y2debug("cmdlinespec: %1", @cmdlinespec)

        Builtins.foreach(actions) do |action, description|
          help = ""
          # help text might be a simple string or a multiline text (list<string>)
          help_value = Ops.get(description, "help")
          if Ops.is_string?(help_value)
            help = Convert.to_string(help_value)
          elsif Ops.is(help_value, "list <string>")
            help = Builtins.mergestring(
              Convert.convert(
                help_value,
                from: "any",
                to:   "list <string>"
              ),
              "\n"
            )
          else
            Builtins.y2error(
              "Unsupported data type for 'help' key: %1, use 'string' or 'list<string>' type!",
              help_value
            )
          end
          opts = []
          Builtins.foreach(Ops.get(mappings, action, [])) do |option|
            #
            optn = {
              "name" => option,
              "help" => Ops.get_string(options, [option, "help"], "")
            }
            # add type specification if it's present
            if Ops.get_string(options, [option, "type"], "") != ""
              optn = Builtins.add(
                optn,
                "type",
                Ops.get_string(options, [option, "type"], "")
              )
            end
            opts = Builtins.add(opts, optn)
          end
          actiondescr = { "help" => help, "name" => action, "options" => opts }
          # add example if it's present
          if Builtins.haskey(Ops.get(actions, action, {}), "example")
            example = Ops.get(actions, [action, "example"])
            examples = Array(example)
            actiondescr = Builtins.add(actiondescr, "examples", examples)
          end
          commands = Builtins.add(commands, actiondescr)
        end

        Ops.set(exportmap, "commands", commands)
        Ops.set(exportmap, "module", Ops.get_string(@cmdlinespec, "id", ""))

        XML.YCPToXMLFile(:xmlhelp, exportmap, xmlfilename)
        Builtins.y2milestone("exported XML map: %1", exportmap)
        return true
      end

      false
    end

    #  Initialize Module
    #
    #  Initialize the module, setup the command line syntax and arguments passed on the command line.
    #
    #  @param [Hash] cmdlineinfo		the map describing the module command line
    #  @param [Array] args			arguments given by the user on the command line
    #  @return [Boolean]		true, if there are some commands to be processed (and cmdlineinfo passes sanity checks)
    #  @see #Command
    def Init(cmdlineinfo, args)
      cmdlineinfo = deep_copy(cmdlineinfo)
      args = deep_copy(args)
      # remember the command line specification
      # required later by xmlhelp command
      @cmdlinespec = deep_copy(cmdlineinfo)

      cmdline_supported = true

      # check whether the command line mode is really supported by the module
      if !Builtins.haskey(cmdlineinfo, "actions") ||
          Builtins.size(Ops.get_map(cmdlineinfo, "actions", {})) == 0
        cmdline_supported = false
      end

      # initialize verbose flag
      @verbose = Builtins.contains(WFM.Args, "verbose")

      id_string = Ops.get_string(cmdlineinfo, "id", "")
      # sanity checks on cmdlineinfo
      # check for id string , it must exist, and non-empty
      if cmdline_supported && (id_string == "" || !Ops.is_string?(id_string))
        Builtins.y2error("Command line specification does not define module id")

        # use 'unknown' as id
        if Builtins.haskey(cmdlineinfo, "id")
          cmdlineinfo = Builtins.remove(cmdlineinfo, "id")
        end

        # translators: fallback name for a module at command line
        cmdlineinfo = Builtins.add(cmdlineinfo, "id", _("unknown"))

        # it's better to abort now
        @done = true
        @aborted = true
      end

      # check for helps, they are required everywhere
      # global help text
      if cmdline_supported && !Builtins.haskey(cmdlineinfo, "help")
        Builtins.y2error(
          "Command line specification does not define global help for the module"
        )

        # it's better to abort now
        @done = true
        @aborted = true
      end

      # help texts for actions
      if Builtins.haskey(cmdlineinfo, "actions")
        Builtins.foreach(Ops.get_map(cmdlineinfo, "actions", {})) do |action, def_|
          if !Builtins.haskey(def_, "help")
            Builtins.y2error(
              "Command line specification does not define help for action '%1'",
              action
            )

            # it's better to abort now
            @done = true
            @aborted = true
          end
        end
      end

      # help for options
      if Builtins.haskey(cmdlineinfo, "options")
        Builtins.foreach(Ops.get_map(cmdlineinfo, "options", {})) do |option, def_|
          if !Builtins.haskey(def_, "help")
            Builtins.y2error(
              "Command line specification does not define help for option '%1'",
              option
            )

            # it's better to abort now
            @done = true
            @aborted = true
          end
          # check that regex and enum have defined typespec
          if (Ops.get_string(def_, "type", "") == "regex" ||
              Ops.get_string(def_, "type", "") == "enum") &&
              !Builtins.haskey(def_, "typespec")
            Builtins.y2error(
              "Command line specification does not define typespec for option '%1'",
              option
            )

            # it's better to abort now
            @done = true
            @aborted = true
          end
        end
      end

      # mappings - check for existing actions and options
      if Builtins.haskey(cmdlineinfo, "mappings")
        Builtins.foreach(Ops.get_map(cmdlineinfo, "mappings", {})) do |mapaction, def_|
          # is this action defined?
          if !Builtins.haskey(
            Ops.get_map(cmdlineinfo, "actions", {}),
            mapaction
            )
            Builtins.y2error(
              "Command line specification maps undefined action '%1'",
              mapaction
            )

            # it's better to abort now
            @done = true
            @aborted = true
          end
          Builtins.foreach(def_) do |mapopt|
            next if !Ops.is_string?(mapopt)
            # is this option defined?
            if !Builtins.haskey(
              Ops.get_map(cmdlineinfo, "options", {}),
              Convert.to_string(mapopt)
              )
              Builtins.y2error(
                "Command line specification maps undefined option '%1' for action '%2'",
                mapopt,
                mapaction
              )

              # it's better to abort now
              @done = true
              @aborted = true
            end
          end
        end
      end

      return false if @done

      @modulecommands = deep_copy(cmdlineinfo)

      # build allcommands - help and verbose options are added specially
      @allcommands = {
        "actions"  => Builtins.union(
          Ops.get_map(@modulecommands, "actions", {}),
          Ops.get(@systemcommands, "actions", {})
        ),
        "options"  => Builtins.union(
          Ops.get_map(@modulecommands, "options", {}),
          Ops.get(@systemcommands, "options", {})
        ),
        "mappings" => Builtins.union(
          Builtins.mapmap(Ops.get_map(@modulecommands, "mappings", {})) do |act, opts|
            { act => Builtins.union(opts, ["help", "verbose"]) }
          end,
          Ops.get(@systemcommands, "mappings", {})
        )
      }

      if Ops.less_than(Builtins.size(args), 1) || Stage.stage != "normal" ||
          Stage.firstboot
        Mode.SetUI("dialog")
        # start GUI, module has some work to do :-)
        return true
      else
        Mode.SetUI("commandline")
      end

      if !cmdline_supported
        # command line is not supported
        Print(
          String.UnderlinedHeader(
            Ops.add("YaST2 ", Ops.get_string(cmdlineinfo, "id", "")),
            0
          )
        )
        Print("")

        help = Ops.get_string(cmdlineinfo, "help", "")
        if !help.nil? && help != ""
          Print(Ops.get_string(cmdlineinfo, "help", ""))
          Print("")
        end

        Print(@nosupport)
        Print("")
        return false
      end

      # setup prompt
      @cmdlineprompt = Ops.add(
        Ops.add("YaST2 ", Ops.get_string(cmdlineinfo, "id", "")),
        "> "
      )
      SCR.Write(path(".dev.tty.prompt"), @cmdlineprompt)

      # parse args
      @commandcache = Parse(args)

      # return true, if there is some work to do:
      # first, try to interpret system commands
      if ProcessSystemCommands(@commandcache)
        # it was system command, there is work only in interactive mode
        @commandcache = {}
        @done = !@interactive
        @aborted = false
        return @interactive
      else
        # we cannot handle this on our own, return true if there is some command to be processed
        # i.e, there is no parsing error
        @done = Builtins.size(@commandcache) == 0
        @aborted = @done
        return !@done
      end
    end

    # Scan a command line from stdin, return it split into a list
    #
    # @return [Array<String>] the list of command line parts, nil for end of file
    def Scan
      res = Convert.to_string(SCR.Read(path(".dev.tty")))
      return nil if res.nil?
      String.ParseOptions(res, "separator" => " ")
    end

    # Set prompt and read input from command line
    # @param [String] prompt Set prompt
    # @param [Symbol] type Type
    # @return [String] Entered string
    def GetInput(prompt, type)
      # set the required prompt
      SCR.Write(path(".dev.tty.prompt"), prompt)

      res = nil

      if type == :nohistory
        res = Convert.to_string(SCR.Read(path(".dev.tty.nohistory")))
      elsif type == :noecho
        res = Convert.to_string(SCR.Read(path(".dev.tty.noecho")))
      else
        res = Convert.to_string(SCR.Read(path(".dev.tty")))
      end

      # set the default prompt
      SCR.Write(path(".dev.tty.prompt"), @cmdlineprompt)

      res
    end

    # Read input from command line
    # @param [String] prompt Set prompt to this value
    # @return [String] Entered string
    def UserInput(prompt)
      GetInput(prompt, :nohistory)
    end

    # Read input from command line
    #
    # Read input from command line, input is not displayed and not stored in
    # the command line history. This function should be used for reading a password.
    # @param [String] prompt Set prompt to this value
    # @return [String] Entered string
    def PasswordInput(prompt)
      GetInput(prompt, :noecho)
    end

    #  Get next user-given command
    #
    #  Get next user-given command. If there is a command available, returns it, otherwise ask
    #  the user for a command (in interactive mode). Also processes system commands.
    #
    #  @return [Hash] of the new command. If there are no more commands, it returns exit or abort depending
    #  on the result user asked for.
    #
    #  @see #Parse
    def Command
      # if we are done already, return the result
      if @done
        if @aborted
          return { "command" => "abort" }
        else
          return { "command" => "exit" }
        end
      end

      # there is a command in the cache
      if Builtins.size(@commandcache) != 0
        result = deep_copy(@commandcache)
        @commandcache = {}
        @done = !@interactive
        return deep_copy(result)
      else
        # if in interactive mode, ask user for input
        if @interactive
          loop do
            newcommand = []
            newcommand = Scan() while Builtins.size(newcommand) == 0

            # EOF reached
            if newcommand.nil?
              @done = true
              return { "command" => "exit" }
            end

            @commandcache = Parse(newcommand)
            break if !ProcessSystemCommands(@commandcache)
            break if @done
          end

          if @done
            if @aborted
              return { "command" => "abort" }
            else
              return { "command" => "exit" }
            end
          end

          # we are not done, return the command asked back to module
          result = deep_copy(@commandcache)
          @commandcache = {}

          return deep_copy(result)
        else
          # there is no further commands left
          @done = true
          return { "command" => "exit" }
        end
      end
    end

    #  Should module start UI?
    #
    #  @return [Boolean] true, if the user asked for standard UI (no parameter was passed by command line)
    def StartGUI
      !Mode.commandline
    end

    #  Is module started in interactive command-line mode?
    #
    #  @return [Boolean] true, if the user asked for interactive command-line mode
    def Interactive
      @interactive
    end

    #  User asked for abort (forgetting the changes)
    #
    #  @return [Boolean] true, if the user asked abort
    def Aborted
      @aborted
    end

    # Abort the command line handling
    def Abort
      @aborted = true
      @done = true

      nil
    end

    #  Are there some commands to be processed?
    #
    #  @return [Boolean] true, if there is no more commands to be processed, either because the user
    #  used command line, or the interactive mode was finished
    def Done
      @done
    end

    # Check uniqueness of an option
    #
    # Check uniqueness of an option. Simply pass the list of user-specified
    # options and a list of mutually exclusive options. In case of
    # error, Report::Error is used.
    #
    # @param [Hash{String => String}] options  options specified by the user on the command line to be checked
    # @param [Array] unique_options	list of mutually exclusive options to check against
    # @return	nil if there is a problem, otherwise the unique option found
    def UniqueOption(options, unique_options)
      options = deep_copy(options)
      unique_options = deep_copy(unique_options)
      # sanity check
      if Builtins.size(unique_options) == 0
        Builtins.y2error(
          "Unique test of options required, but the list of the possible options is empty"
        )
        return nil
      end

      # first do a filtering, then convert to a list of keys
      cmds = Builtins.maplist(Builtins.filter(options) do |opt, _value|
        Builtins.contains(unique_options, opt)
      end) { |key, _value| key }

      # if it is OK, quickly return
      return Ops.get_string(cmds, 0) if Builtins.size(cmds) == 1

      # something is wrong, prepare the error report
      i = 0
      opt_list = ""
      while Ops.less_than(i, Ops.subtract(Builtins.size(unique_options), 1))
        opt_list = Ops.add(
          opt_list,
          Builtins.sformat("'%1', ", Ops.get(unique_options, i))
        )
        i = Ops.add(i, 1)
      end

      # translators: the last command %1 in a list of unique commands
      opt_list = Ops.add(
        opt_list,
        Builtins.sformat(_("or '%1'"), Ops.get(unique_options, i))
      )

      if Builtins.size(cmds) == 0
        if Builtins.size(unique_options) == 1
          # translators: error message - missing unique command for command line execution
          Report.Error(
            Builtins.sformat(
              _("Specify the command '%1'."),
              Ops.get(unique_options, 0)
            )
          )
        else
          # translators: error message - missing unique command for command line execution
          Report.Error(
            Builtins.sformat(_("Specify one of the commands: %1."), opt_list)
          )
        end
        return nil
      end

      if Builtins.size(cmds) != 1
        # size( unique_options ) == 1 here does not make sense

        Report.Error(
          Builtins.sformat(_("Specify only one of the commands: %1."), opt_list)
        )
        return nil
      end

      Ops.get_string(cmds, 0)
    end

    # Parse the Command Line
    #
    # Function to parse the command line, start a GUI or handle interactive and
    # command line actions as supported by the {#CommandLine} module.
    #
    # @param [Hash] commandline	a map used in the CommandLine module with information
    #                      about the handlers for GUI and commands.
    # @return [Object]		false if there was an error or no changes to be written (for example "help").
    #			true if the changes should be written, or a value returned by the
    #			handler
    def Run(commandline)
      commandline = deep_copy(commandline)
      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Command line interface started")

      # Initialize the arguments
      @done = false
      return !Aborted() if !Init(commandline, WFM.Args)

      ret = true

      initialized = false
      if Ops.get(commandline, "initialize").nil?
        # no initialization routine
        # set initialized state to true => call finish handler at the end in command line mode
        initialized = true
      end

      # Start GUI
      if StartGUI()
        if !Builtins.haskey(commandline, "guihandler")
          Builtins.y2error(
            "Missing GUI handler for %1",
            Ops.get_string(commandline, "id", "<unknown>")
          )
          # translators: error message - the module does not provide command line interface
          Error(_("There is no user interface available for this module."))
          return false
        end

        if Ops.is(Ops.get(commandline, "guihandler"), "symbol ()")
          exec = Convert.convert(
            Ops.get(commandline, "guihandler"),
            from: "any",
            to:   "symbol ()"
          )
          symbol_ret = exec.call
          Builtins.y2debug("GUI handler ret=%1", symbol_ret)
          return symbol_ret
        else
          exec = Convert.convert(
            Ops.get(
              commandline,
              "guihandler",
              fun_ref(method(:fake_false), "boolean ()")
            ),
            from: "any",
            to:   "boolean ()"
          )
          ret = exec.call
          Builtins.y2debug("GUI handler ret=%1", ret)
          return ret
        end
      else
        # translators: progress message - command line interface ready
        PrintVerbose(_("Ready"))

        until Done()
          m = Command()
          command = Ops.get_string(m, "command", "exit")
          options = Ops.get_map(m, "options", {})

          # start initialization code if it wasn't already used
          if !initialized
            # check whether command is defined in the map (i.e. it is not predefined command or invalid command)
            # and start initialization if it's defined
            if Builtins.haskey(Ops.get_map(commandline, "actions", {}), command) &&
                Ops.get(commandline, "initialize")
              # non-GUI handling
              PrintVerbose(_("Initializing"))
              ret2 = commandline["initialize"].call
              if !ret2
                Builtins.y2milestone("Module initialization failed")
                return false
              else
                initialized = true
              end
            end
          end

          exec = Convert.convert(
            Ops.get(commandline, ["actions", command, "handler"]),
            from: "any",
            to:   "boolean (map <string, string>)"
          )

          # there is a handler, execute the action
          if !exec.nil?
            res = exec.call(options)

            # if it is not interactive, abort on errors
            Abort() if !Interactive() && res == false
          else
            if !Done()
              Builtins.y2error("Unknown command '%1' from CommandLine", command)
              next
            end
          end
        end

        ret = !Aborted()
      end

      if ret && Ops.get(commandline, "finish") && initialized
        # translators: Progress message - the command line interface is about to finish
        PrintVerbose(_("Finishing"))
        ret = commandline["finish"].call
        if !ret
          Builtins.y2milestone("Module finishing failed")
          return false
        end
        # translators: The command line interface is finished
        PrintVerbose(_("Done"))
      else
        # translators: The command line interface is finished without writing the changes
        PrintVerbose(_("Quitting (without changes)"))
      end

      Builtins.y2milestone("Commandline interface finished")
      Builtins.y2milestone("----------------------------------------")

      ret
    end

    # Ask user, commandline equivalent of Popup::YesNo()
    # @return [Boolean] true if user entered "yes"
    def YesNo
      # prompt message displayed in the commandline mode
      # when user is asked to replay "yes" or "no" (localized)
      prompt = _("yes or no?")

      ui = UserInput(prompt)

      # yes - used in the command line mode as input text for yes/no confirmation
      yes = _("yes")

      # no - used in the command line mode as input text for yes/no confirmation
      no = _("no")

      ui = UserInput(prompt) while ui != yes && ui != no

      ui == yes
    end

    # Return verbose flag
    # boolean verbose flag
    def Verbose
      @verbose
    end

    publish variable: :cmdlineprompt, type: "string", private: true
    publish variable: :systemcommands, type: "map <string, map <string, any>>", private: true
    publish variable: :modulecommands, type: "map", private: true
    publish variable: :allcommands, type: "map", private: true
    publish variable: :interactive, type: "boolean", private: true
    publish variable: :done, type: "boolean", private: true
    publish variable: :aborted, type: "boolean", private: true
    publish variable: :commandcache, type: "map <string, any>", private: true
    publish variable: :verbose, type: "boolean", private: true
    publish variable: :cmdlinespec, type: "map", private: true
    publish variable: :nosupport, type: "string", private: true
    publish function: :PrintInternal, type: "void (string, boolean)", private: true
    publish function: :Print, type: "void (string)"
    publish function: :PrintNoCR, type: "void (string)"
    publish function: :PrintVerbose, type: "void (string)"
    publish function: :PrintVerboseNoCR, type: "void (string)"
    publish function: :PrintTable, type: "void (term, list <term>)"
    publish function: :Error, type: "void (string)"
    publish function: :Parse, type: "map <string, any> (list)"
    publish function: :PrintHead, type: "void ()", private: true
    publish function: :PrintActionHelp, type: "void (string)", private: true
    publish function: :PrintGeneralHelp, type: "void ()", private: true
    publish function: :ProcessSystemCommands, type: "boolean (map)", private: true
    publish function: :Init, type: "boolean (map, list)"
    publish function: :Scan, type: "list <string> ()"
    publish function: :GetInput, type: "string (string, symbol)", private: true
    publish function: :UserInput, type: "string (string)"
    publish function: :PasswordInput, type: "string (string)"
    publish function: :Command, type: "map ()"
    publish function: :StartGUI, type: "boolean ()"
    publish function: :Interactive, type: "boolean ()"
    publish function: :Aborted, type: "boolean ()"
    publish function: :Abort, type: "void ()"
    publish function: :Done, type: "boolean ()"
    publish function: :UniqueOption, type: "string (map <string, string>, list)"
    publish function: :Run, type: "any (map)"
    publish function: :YesNo, type: "boolean ()"
    publish function: :Verbose, type: "boolean ()"
  end

  CommandLine = CommandLineClass.new
  CommandLine.main
end
