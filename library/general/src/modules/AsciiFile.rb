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
# Module: 		AsciiFile.ycp
#
# Authors:		Thomas Fehr (fehr@suse.de)
#
# Purpose: 		Handle reading and modifying of ascii files.
#
# $Id$
require "yast"

module Yast
  # Assume this /etc/fstab file
  #
  #     # main filesystem
  #     UUID=001c0d61-e99f-4ab7-ba4b-bda6f54a052d       /       btrfs   defaults 0 0
  #
  # then with this set-up
  #
  #     file = {}
  #     file_ref = arg_ref(file)  # an artefact of YCP API
  #     AsciiFile.SetComment(file_ref, "^[ \t]*#")
  #     AsciiFile.SetDelimiter(file_ref, " \t")
  #     AsciiFile.SetListWidth(file_ref, [20, 20, 10, 21, 1, 1])
  #
  # this main call
  #
  #     AsciiFile.ReadFile(file_ref, "/etc/fstab")
  #     # note that the result is `file["l"]`
  #     # as the rest of `file` are the parsing parameters
  #     result = file["l"]
  #
  # will produce
  #
  #     result.size               # =>  2
  #     # an integer keyed hash starting at ONE!
  #     result.keys               # =>  [1, 2]
  #     result[1]["comment"]      # =>  true
  #     result[1]["line"]         # =>  "# main filesystem"
  #     result[2]["fields"].size  # =>  6
  #     result[2]["fields"][1]    # =>  "/"
  class AsciiFileClass < Module
    def main
      textdomain "base"

      @blanks = "                                                             "
    end

    # Sets the string how the comment starts
    #
    # @param [map &] file content
    # @param [String] comment delimiter
    def SetComment(file, comment)
      Ops.set(file.value, "comment", Ops.add(comment, ".*"))

      nil
    end

    # Sets the widths of records on one line
    #
    # @param [ArgRef<Hash>] file content
    # @param [Array] widths list of widths
    def SetListWidth(file, widths)
      widths = deep_copy(widths)
      Ops.set(file.value, "widths", widths)

      nil
    end

    # Sets the delimiter between the records on one line
    #
    # @param [ArgRef<Hash>] file content
    # @param [String] delim delimiter
    def SetDelimiter(file, delim)
      Ops.set(file.value, "delim", delim)

      nil
    end

    # Private function
    def AssertLineValid(file, line)
      if Builtins.haskey(Ops.get_map(file.value, "l", {}), line) &&
          Ops.get_boolean(file.value, ["l", line, "buildline"], false)
        delim = Builtins.substring(
          Ops.get_string(file.value, "delim", " "),
          0,
          1
        )
        lstr = ""
        num = 0
        Builtins.foreach(Ops.get_list(file.value, ["l", line, "fields"], [])) do |text|
          lstr = Ops.add(lstr, delim) if Ops.greater_than(num, 0)
          lstr = Ops.add(lstr, text)
          if Ops.less_than(
            Builtins.size(text),
            Ops.get_integer(file.value, ["widths", num], 0)
          )
            lstr = Ops.add(
              lstr,
              Builtins.substring(
                @blanks,
                0,
                Ops.subtract(
                  Ops.get_integer(file.value, ["widths", num], 0),
                  Builtins.size(text)
                )
              )
            )
          end
          num = Ops.add(num, 1)
        end
        Ops.set(file.value, ["l", line, "line"], lstr)
        Ops.set(file.value, ["l", line, "buildline"], false)

        return lstr
      end
      Ops.get_string(file.value, ["l", line, "line"], "")
    end

    # Reads the file from the disk
    #
    # @param [ArgRef<Hash>] file content
    # @param [String] pathname file name
    def ReadFile(file, pathname)
      Builtins.y2milestone("path=%1", pathname)
      lines = []
      if Ops.greater_than(SCR.Read(path(".target.size"), pathname), 0)
        value = Convert.to_string(SCR.Read(path(".target.string"), pathname))
        lines = Builtins.splitstring(value, "\n")
      end
      lineno = 1
      lmap = {}
      Builtins.foreach(lines) do |line|
        l = {}
        Ops.set(l, "line", line)
        if Ops.greater_than(
          Builtins.size(Ops.get_string(file.value, "comment", "")),
          0
        ) &&
            Builtins.regexpmatch(
              line,
              Ops.get_string(file.value, "comment", "")
            )
          Ops.set(l, "comment", true)
        end
        if !Ops.get_boolean(l, "comment", false) &&
            Ops.greater_than(
              Builtins.size(Ops.get_string(file.value, "delim", "")),
              0
            )
          fields = []
          while Ops.greater_than(Builtins.size(line), 0)
            pos = Builtins.findfirstnotof(
              line,
              Ops.get_string(file.value, "delim", "")
            )
            if !pos.nil? && Ops.greater_than(pos, 0)
              line = Builtins.substring(line, pos)
            end
            pos = Builtins.findfirstof(
              line,
              Ops.get_string(file.value, "delim", "")
            )
            if !pos.nil? && Ops.greater_than(pos, 0)
              fields = Builtins.add(fields, Builtins.substring(line, 0, pos))
              line = Builtins.substring(line, pos)
            else
              fields = Builtins.add(fields, line)
              line = ""
            end
          end
          Ops.set(l, "fields", fields)
        end
        Ops.set(lmap, lineno, l)
        lineno = Ops.add(lineno, 1)
      end
      if Ops.greater_than(Builtins.size(lmap), 0) &&
          Builtins.size(
            Ops.get_string(lmap, [Ops.subtract(lineno, 1), "line"], "")
          ) == 0
        lmap = Builtins.remove(lmap, Ops.subtract(lineno, 1))
      end
      Ops.set(file.value, "l", lmap)

      nil
    end

    # Returns the list of rows where matches searched string in the defined column
    #
    # @param [Hash] file content
    # @param [Integer] field		column (counted from 0 to n)
    # @param [String] content		searched string
    # @return [Array<Fixnum>]	matching rows
    def FindLineField(file, field, content)
      file = deep_copy(file)
      ret = []
      Builtins.foreach(Ops.get_map(file, "l", {})) do |num, line|
        if !Ops.get_boolean(line, "comment", false) &&
            Ops.get_string(line, ["fields", field], "") == content
          ret = Builtins.add(ret, num)
        end
      end
      Builtins.y2milestone("field %1 content %2 ret %3", field, content, ret)
      deep_copy(ret)
    end

    # Returns map of wanted line
    #
    # @param [ArgRef<Hash>] file content
    # @param [Integer] line	row number (counted from 1 to n)
    # @return [Hash]		of wanted line
    def GetLine(file, line)
      ret = {}
      if Builtins.haskey(Ops.get_map(file.value, "l", {}), line)
        file_ref = arg_ref(file.value)
        AssertLineValid(file_ref, line)
        file.value = file_ref.value
        ret = Ops.get_map(file.value, ["l", line], {})
      end
      Builtins.y2milestone("line %1 ret %2", line, ret)
      deep_copy(ret)
    end

    # Returns count of lines in file
    #
    # @param [Hash] file content
    # @return [Fixnum]	count of lines
    def NumLines(file)
      file = deep_copy(file)
      Builtins.size(Ops.get_map(file, "l", {}))
    end

    # Changes the record in the file defined by row and column
    #
    # @param [ArgRef<Hash>] file content
    # @param [Integer] line	row number (counted from 1 to n)
    # @param [Integer] field	column number (counted from 0 to n)
    def ChangeLineField(file, line, field, entry)
      Builtins.y2debug("line %1 field %2 entry %3", line, field, entry)
      changed = false
      if !Builtins.haskey(Ops.get_map(file.value, "l", {}), line)
        Ops.set(file.value, ["l", line], {})
        Ops.set(file.value, ["l", line, "fields"], [])
      end
      if Ops.less_than(
        Builtins.size(Ops.get_list(file.value, ["l", line, "fields"], [])),
        field
      )
        changed = true
        i = 0
        while Ops.less_than(i, field)
          if Builtins.size(
            Ops.get_string(file.value, ["l", line, "fields", i], "")
          ) == 0
            Ops.set(file.value, ["l", line, "fields", i], "")
          end
          i = Ops.add(i, 1)
        end
      end
      if Ops.get_string(file.value, ["l", line, "fields", field], "") != entry
        Ops.set(file.value, ["l", line, "fields", field], entry)
        changed = true
      end
      if changed
        Ops.set(file.value, ["l", line, "changed"], true)
        Ops.set(file.value, ["l", line, "buildline"], true)
      end

      nil
    end

    # Changes a complete line
    #
    # @param [ArgRef<Hash>] file content
    # @param [Integer] line	row number (counted from 1 to n)
    # @param [Array] entry	array of new fields on the line
    def ReplaceLine(file, line, entry)
      entry = deep_copy(entry)
      Builtins.y2debug("line %1 entry %2", line, entry)
      if !Builtins.haskey(Ops.get_map(file.value, "l", {}), line)
        Ops.set(file.value, ["l", line], {})
      end
      Ops.set(file.value, ["l", line, "fields"], entry)
      Ops.set(file.value, ["l", line, "changed"], true)
      Ops.set(file.value, ["l", line, "buildline"], true)

      nil
    end

    # Appends a new line at the bottom
    #
    # @param [ArgRef<Hash>] file content
    # @param [Array] entry	array of new fields on the line
    def AppendLine(file, entry)
      entry = deep_copy(entry)
      line = Ops.add(Builtins.size(Ops.get_map(file.value, "l", {})), 1)
      Builtins.y2debug("new line %1 entry %2", line, entry)
      Ops.set(file.value, ["l", line], {})
      Ops.set(file.value, ["l", line, "fields"], entry)
      Ops.set(file.value, ["l", line, "changed"], true)
      Ops.set(file.value, ["l", line, "buildline"], true)

      nil
    end

    # Removes lines
    #
    # @param [ArgRef<Hash>] file content
    # @param [Array<Fixnum>] lines to remove (counted from 1 to n)
    def RemoveLines(file, lines)
      lines = deep_copy(lines)
      Builtins.y2debug("lines %1", lines)
      Builtins.foreach(lines) do |num|
        if Builtins.haskey(Ops.get_map(file.value, "l", {}), num)
          Ops.set(
            file.value,
            "l",
            Builtins.remove(Ops.get_map(file.value, "l", {}), num)
          )
        end
      end

      nil
    end

    # Writes a content into the file
    #
    # @param [ArgRef<Hash>] file content
    # @param [String] fpath file name
    def RewriteFile(file, fpath)
      Builtins.y2milestone("path %1", fpath)
      Builtins.y2debug("out: %1", file.value)
      out = ""
      Builtins.foreach(Ops.get_map(file.value, "l", {})) do |num, _entry|
        out = Ops.add(
          Ops.add(
            out,
            (
              file_ref = arg_ref(file.value)
              assert_line_valid_result = AssertLineValid(file_ref, num)
              file.value = file_ref.value
              assert_line_valid_result
            )
          ),
          "\n"
        )
      end
      Builtins.y2debug("Out text: %1", out)
      if Builtins.size(out) == 0
        if Ops.greater_or_equal(SCR.Read(path(".target.size"), fpath), 0)
          SCR.Execute(path(".target.remove"), fpath)
        end
      else
        SCR.Write(path(".target.string"), fpath, out)
      end

      nil
    end

    publish function: :SetComment, type: "void (map &, string)"
    publish function: :SetListWidth, type: "void (map &, list)"
    publish function: :SetDelimiter, type: "void (map &, string)"
    publish function: :ReadFile, type: "void (map &, string)"
    publish function: :FindLineField, type: "list <integer> (map, integer, string)"
    publish function: :GetLine, type: "map (map &, integer)"
    publish function: :NumLines, type: "integer (map)"
    publish function: :ChangeLineField, type: "void (map &, integer, integer, string)"
    publish function: :ReplaceLine, type: "void (map &, integer, list <string>)"
    publish function: :AppendLine, type: "void (map &, list)"
    publish function: :RemoveLines, type: "void (map &, list <integer>)"
    publish function: :RewriteFile, type: "void (map &, string)"
  end

  AsciiFile = AsciiFileClass.new
  AsciiFile.main
end
