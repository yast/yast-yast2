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
# File:  modules/CommandLine.ycp
# Package:  yast2
# Summary:  Command line interface for YaST2 modules
# Author:  Stanislav Visnovsky <visnov@suse.cz>
#
# $Id$
require "yast"

module Yast
  class CommandLineClass < Module
    include Yast::Logger

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
            "help"     => _(
              "Print the help for this module"
            ),
            "readonly" => true
          },
          "longhelp"    => {
            # translators: help for 'longhelp' option on command line
            "help"     => _(
              "Print a long version of help for this module"
            ),
            "readonly" => true
          },
          "xmlhelp"     => {
            # translators: help for 'xmlhelp' option on command line
            "help"     => _(
              "Print a long version of help for this module in XML format"
            ),
            "readonly" => true
          },
          "interactive" => {
            # translators: help for 'interactive' option on command line
            "help"     => _(
              "Start interactive shell to control the module"
            ),
            # interactive mode itself does not mean that write is needed.
            # The first action that is not readonly will switch flag.
            "readonly" => true
          },
          "exit"        => {
            # translators: help for 'exit' command line interactive mode
            "help"     => _(
              "Exit interactive mode and save the changes"
            ),
            "readonly" => true
          },
          "abort"       => {
            # translators: help for 'abort' command line interactive mode
            "help"     => _(
              "Abort interactive mode without saving the changes"
            ),
            "readonly" => true
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
    #  @param [String] string to be printed
    #  @param [Boolean] newline if newline character should be added or not
    def PrintInternal(string, newline)
      return if !Mode.commandline

      # avoid using of uninitialized value in .dev.tty perl agent
      if string.nil?
        Builtins.y2warning("CommandLine::Print: invalid argument (nil)")
        return
      end

      if @interactive
        if newline
          SCR.Write(path(".dev.tty"), string)
        else
          SCR.Write(path(".dev.tty.nocr"), string)
        end
      elsif newline
        SCR.Write(path(".dev.tty.stderr"), string)
      else
        SCR.Write(path(".dev.tty.stderr_nocr"), string)
      end

      nil
    end

    #  Print a String
    #
    #  Print a string to /dev/tty in interactive mode, to stderr in non-interactive
    #  Suppress printing if there are no commands to be handled (starting GUI)
    #
    #  @param [String] string to be printed
    def Print(string)
      PrintInternal(string, true)
    end

    #  Print a String, don't add a trailing newline character
    #
    #  Print a string to /dev/tty in interactive mode, to stderr in non-interactive
    #  Suppress printing if there are no commands to be handled (starting GUI)
    #
    #  @param [String] string to be printed
    def PrintNoCR(string)
      PrintInternal(string, false)
    end

    # Same as Print(), but the string is printed only when verbose command
    # line mode was activated
    # @param [String] string to print
    def PrintVerbose(string)
      Print(string) if @verbose

      nil
    end

    # Same as PrintNoCR(), but the string is printed only when verbose command
    # line mode was activated
    # @param [String] string to print
    def PrintVerboseNoCR(string)
      PrintNoCR(string) if @verbose

      nil
    end

    #  Print a Table
    #
    #  Print a table using Print(). Format of table is as libyui but not all features
    #  are supported, e.g. no icons.
    #
    #  @param [Yast::Term] header  header of table in libyui format
    #  @param [Array<Yast::Term>] content  content of table in libyui format
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
            ret = Builtins.add(ret, Ops.get_string(Builtins.argsof(t), 0, "")) if Builtins.contains([:Left, :Center, :Right], Builtins.symbolof(t))
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
    # @param [String] message  error message to be printed. Use nil for no message
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
    #  @param [Array] arguments  the list of arguments to be parsed
    #  @return [Hash{String => Object}]  containing the command and it's option. In case of
    #        error it is an empty map.
    def Parse(arguments)
      args = deep_copy(arguments)
      return {} if Ops.less_than(Builtins.size(args), 1)

      # Parse command
      command = args.shift
      Builtins.y2debug("command=%1", command)
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

        return {}
      end

      # build the list of options for the command
      opts = Ops.get_list(@allcommands, ["mappings", command], [])
      allopts = Ops.get_map(@allcommands, "options", {})
      cmdoptions = {}
      Builtins.maplist(opts) do |k|
        cmdoptions = Builtins.add(cmdoptions, k, Ops.get_map(allopts, k, {})) if Ops.is_string?(k)
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
        case Builtins.size(o)
        when 2
          givenoptions = Builtins.add(
            givenoptions,
            Ops.get(o, 0, ""),
            Ops.get(o, 1, "")
          )
        when 0
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
            case opttype
            when "regex"
              opttypespec = Ops.get_string(cmdoptions, [o, "typespec"], "")
              ret = TypeRepository.regex_validator(opttypespec, v)
              if ret != true
                # translators: error message, %2 is the value given
                Print(
                  Builtins.sformat(_("Invalid value for option '%1': %2"), o, v)
                )
                @aborted = true if !@interactive
              end
            when "enum"
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
            when "integer"
              i = Builtins.tointeger(v)
              ret = !i.nil?
              if ret == true
                # update value of the option to integer
                Ops.set(givenoptions, o, i)
              else
                # translators: error message, %2 is the value given
                Print(
                  Builtins.sformat(_("Invalid value for option '%1': %2"), o, v)
                )
                @aborted = true if !@interactive
              end
            else
              ret = (v == "") ? false : TypeRepository.is_a(v, opttype)

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
          # type is missing
          elsif v != ""
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
      head += "-" * (head.size - 1) # -1 to remove newline char from count
      head = Ops.add(Ops.add("\n", head), "\n")

      Print(head)
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
        longestarg = Builtins.size(t) if Ops.greater_than(Builtins.size(t), longestarg)
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

      if @interactive
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
      else
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
      end

      Print("")
      # translators: command line title: list of available commands
      Print(_("Commands:"))

      longest = 0
      Builtins.foreach(Ops.get_map(@modulecommands, "actions", {})) do |action, _desc|
        longest = Builtins.size(action) if Ops.greater_than(Builtins.size(action), longest)
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
    # @param [Hash] command  a map of the current command
    # @return    true, if the command was handled
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

        #      TODO: DTD specification
        Ops.set(
          doc,
          "listEntries",
          "commands" => "command",
          "options"  => "option",
          "examples" => "example"
        )
        #      doc["cdataSections"] = [];
        Ops.set(
          doc,
          "systemID",
          Ops.add(Directory.schemadir, "/commandline.dtd")
        )
        #      doc["nameSpace"] = "http://www.suse.com/1.0/yast2ns";
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

        begin
          XML.YCPToXMLFile(:xmlhelp, exportmap, xmlfilename)
        rescue XMLSerializationError => e
          # error message - creation of xml failed
          Print(
            _("Failed to create XML file.")
          )
          Builtins.y2error("Failed to serialize xml help: #{e.inspect}")
          return false
        end

        Builtins.y2milestone("exported XML map: %1", exportmap)
        return true
      end

      false
    end

    #  Initialize Module
    #
    #  Initialize the module, setup the command line syntax and arguments passed on the command line.
    #
    #  @param [Hash] cmdlineinfo    the map describing the module command line
    #  @param [Array] args      arguments given by the user on the command line
    #  @return [Boolean]    true, if there are some commands to be processed (and cmdlineinfo passes sanity checks)
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
        cmdlineinfo = Builtins.remove(cmdlineinfo, "id") if Builtins.haskey(cmdlineinfo, "id")

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
        @interactive
      else
        # we cannot handle this on our own, return true if there is some command to be processed
        # i.e, there is no parsing error
        @done = Builtins.size(@commandcache) == 0
        @aborted = @done
        !@done
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

      res = case type
      when :nohistory
        Convert.to_string(SCR.Read(path(".dev.tty.nohistory")))
      when :noecho
        Convert.to_string(SCR.Read(path(".dev.tty.noecho")))
      else
        Convert.to_string(SCR.Read(path(".dev.tty")))
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
      return { "command" => @aborted ? "abort" : "exit" } if @done

      # there is a command in the cache
      if Builtins.size(@commandcache) != 0
        result = deep_copy(@commandcache)
        @commandcache = {}
        @done = !@interactive
        deep_copy(result)
      # if in interactive mode, ask user for input
      elsif @interactive
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

        return { "command" => @aborted ? "abort" : "exit" } if @done

        # we are not done, return the command asked back to module
        result = deep_copy(@commandcache)
        @commandcache = {}

        deep_copy(result)
      else
        # there is no further commands left
        @done = true
        { "command" => "exit" }
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
    # @param [Array] unique_options  list of mutually exclusive options to check against
    # @return  nil if there is a problem, otherwise the unique option found
    def UniqueOption(options, unique_options)
      return nil if options.nil? || unique_options.nil?

      # sanity check
      if unique_options.empty?
        log.error "Unique list of options required, but the list of the possible options is empty"
        return nil
      end

      # first do a filtering, then convert to a list of keys
      cmds = unique_options & options.keys

      # if it is OK, quickly return
      return cmds.first if cmds.size == 1

      msg = if cmds.empty?
        if unique_options.size == 1
          # translators: error message - missing unique command for command line execution
          Builtins.sformat(_("Specify the command '%1'."), unique_options.first)
        else
          # translators: error message - missing unique command for command line execution
          Builtins.sformat(_("Specify one of the commands: %1."), format_list(unique_options))
        end
      else
        Builtins.sformat(_("Specify only one of the commands: %1."), format_list(cmds))
      end

      Report.Error(msg)
      nil
    end

    # Parse the Command Line
    #
    # Function to parse the command line, start a GUI or handle interactive and
    # command line actions as supported by the {Yast::CommandLine} module.
    #
    # @param [Hash] commandline  a map used in the CommandLine module with information
    #                      about the handlers for GUI and commands.
    # @option commandline [String] "help" global help text.
    #   Help for options and actions are separated. Mandatory if module support command line.
    # @option commandline [String] "id" module id. Mandatory if module support command line.
    # @option commandline [Yast::FunRef("symbol ()")|Yast::FunRef("boolean ()")] "guihandler"
    #   function to be called when gui requested. Mandatory for modules with GUI.
    # @option commandline [Yast::FunRef("boolean ()")] "initialize" function that is called before
    #   any action handler is called. Usually module initialization happens there.
    # @option commandline [Yast::FunRef("boolean ()")] "finish" function that is called after
    #   all action handlers are called. Usually writing of changes happens there. NOTE: calling
    #   is skipped if all called handlers are readonly.
    # @option commandline [Hash<String, Object>] "actions" definition of actions. Hash has action
    #   name as key and value is hash with following keys:
    #
    #      - **"help"** _String|Array<String>_ mandatory action specific help text.
    #        Options help text is defined separately. If array is passed it will be
    #        printed indended on multiple lines.
    #      - **"handler"** _Yast::FunRef("boolean (map <string, string>)")_ handler when action is
    #        specified. Parameter is passed options. Mandatory.
    #      - **"example"** _String_ optional example of action invocation.
    #        By default no example is provided.
    #      - **"options"** _Array<String>_ optional list of flags. So far only `"non_strict"`
    #        supported. Useful when action arguments is not well defined, so unknown option does
    #        not finish with error. By default it is empty array.
    #      - **"readonly"** _Boolean_ optional flag that if it is set to true then
    #        invoking action is not reason to run finish handler, but if another
    #        action without readonly is called, it will run finish handler.
    #        Default value is `false`.
    #
    # @option commandline [Hash<String, Object>] "options" definition of options. Hash has action
    #   name as key and value is hash with following keys:
    #
    #      - **"help"** _String|Array<String>_ mandatory action specific help text.
    #        If array is passed it will be printed indended on multiple lines.
    #      - **"type"** _String_ optional type check for option parameter. By default no
    #        type checking is done. It aborts if no checking is done and a value is passed on CLI.
    #        Possible values are ycp types and additionally enum and regex. For enum additional
    #        key **"typespec"** with array of values have to be specified. For regex additional
    #        key **"typespec"** with string containing ycp regexp is required. For integer it
    #        does conversion of a string value to an integer value.
    #      - **"typespec"** _Object_ additional type specification. See **"type"** for details.
    #
    # @option commandline [Hash<String, Array<String>>] "mappings" defines connection between
    #   **"actions"** and its **"options"**. The key is action and the value is a list of options it
    #   supports.
    # @return [Object] false if there was an error or there are no changes to be written (for example "help").
    #      true if the changes should be written, or a value returned by the
    #      handler. Actions that are read-only return also true on success even if there is nothing to write.
    #
    # @example Complete CLI support. Methods definition are skipped for simplicity.
    #   Yast::CommandLine.Run(
    #     "help"       => _("Foo Configuration"),
    #     "id"         => "foo",
    #     "guihandler" => fun_ref(method(:FooSequence), "symbol ()"),
    #     "initialize" => fun_ref(Foo.method(:ReadNoGUI), "boolean ()"),
    #     "finish"     => fun_ref(Foo.method(:WriteNoGUI), "boolean ()"),
    #     "actions"    => {
    #       "list"   => {
    #         "help"     => _(
    #           "Display configuration summary"
    #           ),
    #         "example"  => "foo list configured",
    #         "readonly" => true,
    #         "handler"  => fun_ref(
    #           method(:ListHandler),
    #           "boolean (map <string, string>)"
    #         )
    #       },
    #       "edit"   => {
    #         "help"    => _("Change existing configuration"),
    #         "handler" => fun_ref(
    #           method(:EditHandler),
    #           "boolean (map <string, string>)"
    #         )
    #       },
    #     },
    #     "options"    => {
    #       "configured"   => {
    #         "help" => _("List only configured foo fighters")
    #       }
    #     },
    #     "mappings"   => {
    #       "list"   => ["configured"]
    #     }
    #   )
    def Run(commandline)
      commandline = deep_copy(commandline)
      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Command line interface started")

      # Initialize the arguments
      @done = false
      return !Aborted() if !Init(commandline, WFM.Args)

      ret = true
      # no action is readonly, but the first module without "readonly" will switch the flag to `false`
      read_only = true

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
          if !initialized && (Builtins.haskey(Ops.get_map(commandline, "actions", {}), command) &&
                Ops.get(commandline, "initialize"))
            # non-GUI handling
            PrintVerbose(_("Initializing"))
            ret2 = commandline["initialize"].call
            if ret2
              initialized = true
            else
              Builtins.y2milestone("Module initialization failed")
              return false
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
            # unless an action explicitly mentions that it is read-only it will run the finish handler
            read_only = false unless commandline["actions"][command]["readonly"]

            # if it is not interactive, abort on errors
            Abort() if !Interactive() && res == false
          elsif !Done()
            Builtins.y2error("Unknown command '%1' from CommandLine", command)
            next
          end
        end

        ret = !Aborted()
      end

      if ret && Ops.get(commandline, "finish") && initialized && !read_only
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

  private

    def format_list(list)
      # translators: the last entry in output of list
      list[0..-2].map { |l| "'#{l}'" }.join(", ") + " " +
        Builtins.sformat(_("or '%1'"), list[-1])
    end
  end

  CommandLine = CommandLineClass.new
  CommandLine.main
end
