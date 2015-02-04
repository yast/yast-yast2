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
# File:	modules/String.ycp
# Package:	yast2
# Summary:	String manipulation routines
# Authors:	Michal Svec <msvec@suse.cz>
#
# $Id$
require "yast"

module Yast
  class StringClass < Module
    include Yast::Logger

    # @note it is ascii chars only
    UPPER_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    LOWER_CHARS = "abcdefghijklmnopqrstuvwxyz"
    ALPHA_CHARS = UPPER_CHARS + LOWER_CHARS
    DIGIT_CHARS = "0123456789"
    ALPHA_NUM_CHARS = ALPHA_CHARS + DIGIT_CHARS
    PUNCT_CHARS = "!\"\#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
    GRAPHICAL_CHARS = ALPHA_NUM_CHARS + PUNCT_CHARS
    SPACE_CHARS = "\f\r\n\t\v"
    PRINTABLE_CHARS = SPACE_CHARS + GRAPHICAL_CHARS

    def main
      textdomain "base"

      # 64 characters is the base undeline length
    end

    # Quote a string with 's
    #
    # More precisely it protects single quotes inside the string but does not
    # prepend or append single quotes.
    #
    # @param [String] var unquoted string
    # @return quoted string
    # @example quote("a'b") -> "a'\''b"
    def Quote(var)
      return "" if var.nil?

      var.gsub("'", "'\\\\''")
    end

    # Unquote a string with 's (quoted with quote)
    # @param [String] var quoted string
    # @return unquoted string
    # @see #quote
    def UnQuote(var)
      return "" if var.nil?
      log.debug "var=#{var}"

      var.gsub("'\\''", "'")
    end

    # Optional parenthesized text
    # @return " (Foo)" if Foo is neither empty or nil, else ""
    def OptParens(s)
      opt_format(" (%1)", s)
    end

    # @param [Array<String>] l a list of strings
    # @return only non-"" items
    def NonEmpty(l)
      l = deep_copy(l)
      Builtins.filter(l) { |i| i != "" }
    end

    # @param [String] s \n-terminated items
    # @return the items as a list, with empty lines removed
    def NewlineItems(s)
      NonEmpty(Builtins.splitstring(s, "\n"))
    end

    # @param [Boolean] value boolean
    # @return [Boolean] value as "Yes" or "No"
    def YesNo(value)
      if value
        # human text for Boolean value
        return _("Yes")
      else
        # human text for Boolean value
        return _("No")
      end
    end

    # Return a pretty description of a byte count
    #
    # Return a pretty description of a byte count with required precision
    # and using B, KiB, MiB, GiB or TiB as unit as appropriate.
    #
    # Uses the current locale defined decimal separator
    # (i.e. the result is language dependant).
    #
    # @param [Fixnum] bytes	size (e.g. free diskspace, memory size) in Bytes
    # @param [Fixnum] precision number of fraction digits in output, if negative (less than 0) the precision is set automatically depending on the suffix
    # @param [Boolean] omit_zeroes if true then do not add zeroes
    #	(useful for memory size - 128 MiB RAM looks better than 128.00 MiB RAM)
    # @return formatted string
    #
    # @example FormatSizeWithPrecision(128, 2, true) -> "128 B"
    # @example FormatSizeWithPrecision(4096, 2, true) -> "4 KiB"
    # @example FormatSizeWithPrecision(4096, 2, false) -> "4.00 KiB"
    # @example FormatSizeWithPrecision(1024*1024, 2, true) -> "1 MiB"
    def FormatSizeWithPrecision(bytes, precision, omit_zeroes)
      return "" if bytes.nil?

      units = [
        # Byte abbreviated
        _("B"),
        # KiloByte abbreviated
        _("KiB"),
        # MegaByte abbreviated
        _("MiB"),
        # GigaByte abbreviated
        _("GiB"),
        # TeraByte abbreviated
        _("TiB")
      ]

      index = 0
      whole = Builtins.tofloat(bytes)

      while (Ops.greater_or_equal(whole, 1024.0) ||
          Ops.less_or_equal(whole, -1024.0)) &&
          Ops.less_than(Ops.add(index, 1), Builtins.size(units))
        whole = Ops.divide(whole, 1024.0)
        index = Ops.add(index, 1)
      end

      if precision.nil?
        precision = 0
      elsif Ops.less_than(precision, 0)
        # auto precision - depends on the suffix, but max. 3 decimal digits
        precision = Ops.less_or_equal(index, 3) ? index : 3
      end

      if omit_zeroes == true
        max_difference = 0.9
        i = precision

        while Ops.greater_than(i, 0)
          max_difference = Ops.divide(
            max_difference,
            Convert.convert(10, from: "integer", to: "float")
          )
          i = Ops.subtract(i, 1)
        end

        if Ops.less_than(
          Ops.subtract(
            whole,
            Convert.convert(
              Builtins.tointeger(whole),
              from: "integer",
              to:   "float"
            )
          ),
          max_difference
          )
          precision = 0
        end
      end

      Ops.add(
        Ops.add(Builtins::Float.tolstring(whole, precision), " "),
        Ops.get_string(units, index, "")
      )
    end

    # Return a pretty description of a byte count
    #
    # Return a pretty description of a byte count, with two fraction digits
    # and using B, KiB, MiB, GiB or TiB as unit as appropriate.
    #
    # Uses the current locale defined decimal separator
    # (i.e. the result is language dependant).
    #
    # @param [Fixnum] bytes	size (e.g. free diskspace) in Bytes
    # @return formatted string
    #
    # @example FormatSize(23456767890) -> "223.70 MiB"
    def FormatSize(bytes)
      return "" if bytes.nil?

      # automatic precision, don't print trailing zeroes for sizes < 1MiB
      FormatSizeWithPrecision(bytes, -1, Ops.less_than(bytes, 1 << 20))
    end

    # Add a download rate status to a message.
    #
    # Add the current and the average download rate to the message.
    #
    # @param [String] text the message with %1 placeholder for the download rate string
    # @param [Fixnum] avg_bps average download rate (in B/s)
    # @param [Fixnum] curr_bps current download rate (in B/s)
    #
    # @return [String] formatted message
    def FormatRateMessage(text, avg_bps, curr_bps)
      rate = ""

      if Ops.greater_than(curr_bps, 0)
        rate = format_rate(curr_bps)

        if Ops.greater_than(avg_bps, 0)
          # format download rate message: %1 = the current download rate (e.g. "242.6kB/s")
          # %2 is the average download rate (e.g. "228.3kB/s")
          # to translators: keep translation of "on average" as short as possible
          rate = Builtins.sformat(
            _("%1 (on average %2)"),
            rate,
            format_rate(avg_bps)
          )
        end
      end

      # add download rate to the downloading message
      # %1 is URL, %2 is formatted download rate, e.g. "242.6kB/s (avg. 228.3kB/s)"
      # in ncurses UI the strings are exchanged (%1 is the rate, %2 is URL)
      # due to limited space on the screen
      Builtins.sformat(text, rate)
    end

    # Format an integer number as (at least) two digits; use leading zeroes if
    # necessary.
    # @param [Fixnum] x input
    # @return [String] number as two-digit string
    #
    def FormatTwoDigits(x)
      if Ops.less_than(x, 10) && Ops.greater_or_equal(x, 0)
        Builtins.sformat("0%1", x)
      else
        Builtins.sformat("%1", x)
      end
    end

    # Format an integer seconds value with min:sec or hours:min:sec
    # @param [Fixnum] seconds time (in seconds)
    # @return [String] formatted string (empty for negative values)
    #
    def FormatTime(seconds)
      return "" if Ops.less_than(seconds, 0)

      if Ops.less_than(seconds, 3600) # Less than one hour
        return Builtins.sformat(
          "%1:%2",
          FormatTwoDigits(Ops.divide(seconds, 60)),
          FormatTwoDigits(Ops.modulo(seconds, 60))
        ) # More than one hour - we don't hope this will ever happen, but who knows?
      else
        hours = Ops.divide(seconds, 3600)
        seconds = Ops.modulo(seconds, 3600)
        return Builtins.sformat(
          "%1:%2:%3",
          hours,
          FormatTwoDigits(Ops.divide(seconds, 60)),
          FormatTwoDigits(Ops.modulo(seconds, 60))
        )
      end
    end

    # Remove spaces and tabs at begin and end of input string.
    # @param [String] input string to be stripped
    # @return stripped string
    # @deprecated if remove also \n then use {::String#strip}, otherwise simple sub is enough
    # @example CutBlanks("  \tany  input     ") -> "any  input"
    def CutBlanks(input)
      return "" if input.nil?

      input.sub(/\A[ \t]*(.*[^ \t])[ \t]*\z/, "\\1")
    end

    # Remove any leading zeros
    #
    # Remove any leading zeros that make tointeger inadvertently
    # assume an octal number (e.g. "09" -> "9", "0001" -> "1",
    # but "0" -> "0")
    #
    # @param [String] input number that might contain leadig zero
    # @return [String] that has leading zeros removed
    # @deprecated if conversion to integer is needed in decimal use {::String#to_i}
    def CutZeros(input)
      return "" if input.nil?

      input.sub(/\A0*([0-9])/, "\\1")
    end

    # Repeat a string
    #
    # Repeat a string number of times.
    #
    # @param input string to repeat
    # @param input number number of repetitions
    # @return [String] repeated string
    # @deprecated use {::String#operator*} instead
    def Repeat(text, number)
      return "" if text.nil? || number.nil? || number < 1

      text * number
    end

    # Add the padding character around the text to make it long enough
    #
    # Add the padding character around the text to make it long enough. If the
    # text is longer than requested, no changes are made.
    #
    # @param [String] text text to be padded
    # @param [Fixnum] length requested length
    # @param [String] padding padding character
    # @param [Symbol] alignment alignment to use, either `left or `right
    # @return padded text
    def SuperPad(text, length, padding, alignment)
      text ||= ""
      return text if length.nil? || text.size >= length || padding.nil?

      pad = padding * (length - text.size)

      if alignment == :right
        return pad + text
      else
        return text + pad
      end
    end

    # Add spaces after the text to make it long enough
    #
    # Add spaces after the text to make it long enough. If the text is longer
    # than requested, no changes are made.
    #
    # @param [String] text text to be padded
    # @param [Fixnum] length requested length
    # @return padded text
    def Pad(text, length)
      SuperPad(text, length, " ", :left)
    end

    # Add zeros before the text to make it long enough.
    #
    # Add zeros before the text to make it long enough. If the text is longer
    # than requested, no changes are made.
    #
    # @param [String] text text to be padded
    # @param [Fixnum] length requested length
    # @return padded text
    def PadZeros(text, length)
      SuperPad(text, length, "0", :right)
    end

    # Parse string of values
    #
    # Parse string of values - split string to values, quoting and backslash sequences are supported
    # @param [String] options Input string
    # @param [Hash] parameters Parmeter used at parsing - map with keys:
    # "separator":<string> - value separator (default: " \t"),
    # "unique":<boolean> - result will not contain any duplicates, first occurance of the string is stored into output (default: false),
    # "interpret_backslash":<boolean> - convert backslash sequence into one character (e.g. "\\n" => "\n") (default: true)
    # "remove_whitespace":<boolean> - remove white spaces around values (default: true),
    # @return [Array<String>] List of strings
    def ParseOptions(options, parameters)
      parameters = deep_copy(parameters)
      ret = []

      # parsing options
      separator = Ops.get_string(parameters, "separator", " \t")
      unique = Ops.get_boolean(parameters, "unique", false)
      interpret_backslash = Ops.get_boolean(
        parameters,
        "interpret_backslash",
        true
      )
      remove_whitespace = Ops.get_boolean(parameters, "remove_whitespace", true)

      Builtins.y2debug(
        "Input: string: '%1', parameters: %2",
        options,
        parameters
      )
      Builtins.y2debug(
        "Used values: separator: '%1', unique: %2, remove_whitespace: %3",
        separator,
        unique,
        remove_whitespace
      )

      return [] if options.nil?

      # two algorithms are used:
      # first is much faster, but only usable if string
      # doesn't contain any double qoute characters
      # and backslash sequences are not interpreted
      # second is more general, but of course slower

      if Builtins.findfirstof(options, "\"").nil? &&
          interpret_backslash == false
        # easy case - no qouting, don't interpres backslash sequences => use splitstring
        values = Builtins.splitstring(options, separator)

        Builtins.foreach(values) do |v|
          v = CutBlanks(v) if remove_whitespace == true
          if unique == true
            ret = Builtins.add(ret, v) if !Builtins.contains(ret, v)
          else
            ret = Builtins.add(ret, v)
          end
        end
      else
        # quoting is used or backslash interpretation is enabled
        # so it' not possible to split input
        # parsing each character is needed - use finite automaton

        # state
        state = :out_of_string
        # position in the input string
        index = 0
        # parsed value - buffer
        str = ""

        while Ops.less_than(index, Builtins.size(options))
          character = Builtins.substring(options, index, 1)

          Builtins.y2debug(
            "character: %1 state: %2 index: %3",
            character,
            state,
            index
          )

          # interpret backslash sequence
          if character == "\\" && interpret_backslash == true
            if Ops.less_than(Ops.add(index, 1), Builtins.size(options))
              nextcharacter = Builtins.substring(options, Ops.add(index, 1), 1)
              index = Ops.add(index, 1)

              # backslah sequences
              backslash_seq = {
                "a"  => "\a", # alert
                "b"  => "\b", # backspace
                "e"  => "\e", # escape
                "f"  => "\f", # FF
                "n"  => "\n", # NL
                "r"  => "\r", # CR
                "t"  => "\t", # tab
                "v"  => "\v", # vertical tab
                "\\" => "\\", # backslash
                # backslash will be removed later,
                # double quote and escaped double quote have to be different
                # as it have different meaning
                "\"" => "\\\""
              }

              if backslash_seq[nextcharacter]
                character = backslash_seq[nextcharacter]
              else
                # ignore backslash in invalid backslash sequence
                character = nextcharacter
              end

              Builtins.y2debug("backslash sequence: '%1'", character)
            else
              Builtins.y2warning(
                "Missing character after backslash (\\) at the end of string"
              )
            end
          end

          if state == :out_of_string
            # ignore separator or white space at the beginning of the string
            if Builtins.issubstring(separator, character) == true ||
                remove_whitespace == true &&
                    (character == " " || character == "\t")
              index = Ops.add(index, 1)
              next
            # start of a quoted string
            elsif character == "\""
              state = :in_quoted_string
            else
              # start of a string
              state = :in_string

              if character == "\\\""
                str = "\""
              else
                str = character
              end
            end
          # after double quoted string - handle non-separator chars after double quote
          elsif state == :in_quoted_string_after_dblqt
            if Builtins.issubstring(separator, character) == true
              ret = Builtins.add(ret, str) if !unique || !Builtins.contains(ret, str)

              str = ""
              state = :out_of_string
            elsif character == "\\\""
              str = Ops.add(str, "\"")
            else
              str = Ops.add(str, character)
            end
          elsif state == :in_quoted_string
            if character == "\""
              # end of quoted string
              state = :in_quoted_string_after_dblqt
            elsif character == "\\\""
              str = Ops.add(str, "\"")
            else
              str = Ops.add(str, character)
            end
          elsif state == :in_string
            if Builtins.issubstring(separator, character) == true
              state = :out_of_string

              str = CutBlanks(str) if remove_whitespace == true

              ret = Builtins.add(ret, str) if !unique || !Builtins.contains(ret, str)

              str = ""
            elsif character == "\\\""
              str = Ops.add(str, "\"")
            else
              str = Ops.add(str, character)
            end
          end

          index = Ops.add(index, 1)
        end

        # error - still in quoted string
        if state == :in_quoted_string || state == :in_quoted_string_after_dblqt
          if state == :in_quoted_string
            Builtins.y2warning(
              "Missing trainling double quote character(\") in input: '%1'",
              options
            )
          end

          if unique == true
            ret = Builtins.add(ret, str) if !Builtins.contains(ret, str)
          else
            ret = Builtins.add(ret, str)
          end
        end

        # process last string in the buffer
        if state == :in_string
          str = CutBlanks(str) if remove_whitespace

          if unique == true
            ret = Builtins.add(ret, str) if !Builtins.contains(ret, str)
          else
            ret = Builtins.add(ret, str)
          end
        end
      end

      Builtins.y2debug("Parsed values: %1", ret)

      deep_copy(ret)
    end

    # Remove first or every match of given regular expression from a string
    #
    # (e.g. CutRegexMatch( "abcdef12ef34gh000", "[0-9]+", true ) -> "abcdefefgh",
    # CutRegexMatch( "abcdef12ef34gh000", "[0-9]+", false ) -> "abcdefef34gh000")
    #
    # @param [String] input string that might occur regex
    # @param [String] regex regular expression to search for, must not contain brackets
    # @param [Boolean] glob flag if only first or every occuring match should be removed
    # @return [String] that has matches removed
    def CutRegexMatch(input, regex, glob)
      return "" if input.nil? || Ops.less_than(Builtins.size(input), 1)
      output = input
      if Builtins.regexpmatch(output, regex)
        p = Builtins.regexppos(output, regex)
        loop do
          output = Ops.add(
            Builtins.substring(output, 0, Ops.get_integer(p, 0, 0)),
            Builtins.substring(
              output,
              Ops.add(Ops.get_integer(p, 0, 0), Ops.get_integer(p, 1, 0))
            )
          )
          p = Builtins.regexppos(output, regex)
          break unless glob
          break unless Ops.greater_than(Builtins.size(p), 0)
        end
      end
      output
    end

    # Function for escaping (replacing) (HTML|XML...) tags with their
    # (HTML|XML...) meaning.
    #
    # Usable to present text "as is" in RichText.
    #
    # @param [String] text to escape
    # @return [String]	escaped text
    def EscapeTags(text)
      text = Builtins.mergestring(Builtins.splitstring(text, "&"), "&amp;")
      text = Builtins.mergestring(Builtins.splitstring(text, "<"), "&lt;")
      text = Builtins.mergestring(Builtins.splitstring(text, ">"), "&gt;")

      text
    end

    # Shorthand for select (splitstring (s, separators), 0, "")
    # Useful now that the above produces a deprecation warning.
    # @param [String] s string to be split
    # @param [String] separators characters which delimit components
    # @return first component or ""
    def FirstChunk(s, separators)
      l = Builtins.splitstring(s, separators)
      Ops.get(l, 0, "")
    end

    # The 26 lowercase ASCII letters
    def CLower
      LOWER_CHARS
    end

    # The 52 upper and lowercase ASCII letters
    def CAlpha
      ALPHA_CHARS
    end

    # Digits: 0123456789
    def CDigit
      DIGIT_CHARS
    end

    # The 62 upper and lowercase ASCII letters and digits
    def CAlnum
      ALPHA_NUM_CHARS
    end

    # Printable ASCII charcters except whitespace, 33-126
    def CGraph
      GRAPHICAL_CHARS
    end

    # Printable ASCII characters including whitespace
    def CPrint
      PRINTABLE_CHARS
    end

    # Characters valid in a filename (not pathname).
    # Naturally "/" is disallowed. Otherwise, the graphical ASCII
    # characters are allowed.
    # @return [String] for ValidChars
    def ValidCharsFilename
      Builtins.deletechars(CGraph(), "/")
    end

    # - hidden for documentation -
    #
    # Local function for finding longest records in the table.
    #
    # @param	list <list <string> > table items
    # @return	list <integer> longest records by columns
    def FindLongestRecords(items)
      items = deep_copy(items)
      longest = []

      # searching all rows
      Builtins.foreach(items) do |row|
        # starting with column 0
        col_counter = 0
        # testing all columns on the row
        Builtins.foreach(row) do |col|
          col_size = Builtins.size(col)
          # found longer record for this column
          if Ops.greater_than(col_size, Ops.get(longest, col_counter, -1))
            Ops.set(longest, col_counter, col_size)
          end
          # next column
          col_counter = Ops.add(col_counter, 1)
        end
      end

      deep_copy(longest)
    end

    # - hidden for documentation -
    #
    # Local function creates table row.
    #
    # @param	list <string> row items
    # @param	list <integer> columns lengths
    # @param	integer record horizontal padding
    # @return	string padded table row
    def CreateTableRow(row_items, cols_lenghts, horizontal_padding)
      row_items = deep_copy(row_items)
      cols_lenghts = deep_copy(cols_lenghts)
      row = ""

      col_counter = 0
      records_count = Ops.subtract(Builtins.size(row_items), 1)

      Builtins.foreach(row_items) do |record|
        padding = Ops.get(cols_lenghts, col_counter, 0)
        if Ops.less_than(col_counter, records_count)
          padding = Ops.add(padding, horizontal_padding)
        end
        row = Ops.add(row, Pad(record, padding))
        col_counter = Ops.add(col_counter, 1)
      end

      row
    end

    # - hidden for documentation -
    #
    # Local function returns underline string /length/ long.
    #
    # @param	integer length of underline
    # @return	string /length/ long underline
    def CreateUnderline(length)
      return "" unless length

      "-" * length
    end

    # - hidden for documentation -
    #
    # Local function for creating header underline for table.
    # It uses maximal lengths of records defined in cols_lenghts.
    #
    # @param	list <integer> maximal lengths of records in columns
    # @param	integer horizontal padding of records
    # @return	string table header underline
    def CreateTableHeaderUnderline(cols_lenghts, horizontal_padding)
      cols_lenghts = deep_copy(cols_lenghts)
      col_counter = 0
      # count of added paddings
      records_count = Ops.subtract(Builtins.size(cols_lenghts), 1)
      # total length of underline
      total_size = 0

      Builtins.foreach(cols_lenghts) do |col_size|
        total_size = Ops.add(total_size, col_size)
        # adding padding where necessary
        if Ops.less_than(col_counter, records_count)
          total_size = Ops.add(total_size, horizontal_padding)
        end
        col_counter = Ops.add(col_counter, 1)
      end

      CreateUnderline(total_size)
    end

    # Function creates text table without using HTML tags.
    # (Useful for commandline)
    # Undefined option uses the default one.
    #
    # @param [Array<String>] header
    # @param [Array<Array<String>>] items
    # @param [Hash{String => Object}] options
    # @return	[String] table
    #
    # Header: [ "Id", "Configuration", "Device" ]
    # Items: [ [ "1", "aaa", "Samsung Calex" ], [ "2", "bbb", "Trivial Trinitron" ] ]
    # Possible Options: horizontal_padding (for columns), table_left_padding (for table)
    def TextTable(header, items, options)
      header = deep_copy(header)
      items = deep_copy(items)
      options = deep_copy(options)
      current_horizontal_padding = Ops.get_integer(
        options,
        "horizontal_padding",
        2
      )
      current_table_left_padding = Ops.get_integer(
        options,
        "table_left_padding",
        4
      )

      cols_lenghts = FindLongestRecords(Builtins.add(items, header))

      # whole table is left-padded
      table_left_padding = Pad("", current_table_left_padding)
      # the last row has no newline
      rows_count = Builtins.size(items)
      table = ""

      table = Ops.add(
        Ops.add(
          Ops.add(table, table_left_padding),
          CreateTableRow(header, cols_lenghts, current_horizontal_padding)
        ),
        "\n"
      )
      table = Ops.add(
        Ops.add(
          Ops.add(table, table_left_padding),
          CreateTableHeaderUnderline(cols_lenghts, current_horizontal_padding)
        ),
        "\n"
      )
      rows_counter = 1
      Builtins.foreach(items) do |row|
        table = Ops.add(
          Ops.add(
            Ops.add(table, table_left_padding),
            CreateTableRow(row, cols_lenghts, current_horizontal_padding)
          ),
          Ops.less_than(rows_counter, rows_count) ? "\n" : ""
        )
        rows_counter = Ops.add(rows_counter, 1)
      end
      table
    end

    # Function returns underlined text header without using HTML tags.
    # (Useful for commandline)
    #
    # @param	string header line
    # @param	integer left padding
    # @return	[String] underlined header line
    def UnderlinedHeader(header_line, left_padding)
      Ops.add(
        Ops.add(
          Ops.add(Ops.add(Pad("", left_padding), header_line), "\n"),
          Pad("", left_padding)
        ),
        CreateUnderline(Builtins.size(header_line))
      )
    end

    # Replace substring in a string. All substrings source are replaced by string target.
    # @param [String] s input string
    # @param [String] source the string which will be replaced
    # @param [String] target the new string which is used instead of source
    # @return [String] result
    def Replace(s, source, target)
      return nil if s.nil?

      if source.nil? || source == ""
        Builtins.y2warning("invalid parameter source: %1", source)
        return s
      end

      if target.nil?
        Builtins.y2warning("invalid parameter target: %1", target)
        return s
      end

      pos = Builtins.find(s, source)
      while Ops.greater_or_equal(pos, 0)
        tmp = Ops.add(Builtins.substring(s, 0, pos), target)
        if Ops.greater_than(
          Builtins.size(s),
          Ops.add(pos, Builtins.size(source))
          )
          tmp = Ops.add(
            tmp,
            Builtins.substring(s, Ops.add(pos, Builtins.size(source)))
          )
        end

        s = tmp

        pos = Builtins.find(s, source)
      end

      s
    end

    # Make a random base-36 number.
    # srandom should be called beforehand.
    # @param [Fixnum] len string length
    # @return random string of 0-9 and a-z
    def Random(len)
      return "" if Ops.less_or_equal(len, 0)
      digits = DIGIT_CHARS + LOWER_CHARS # uses the character classes from above
      base = Builtins.size(digits)
      max = 1
      i = len
      while Ops.greater_than(i, 0)
        max = Ops.multiply(max, base)
        i = Ops.subtract(i, 1)
      end
      rnum = Builtins.random(max)
      ret = ""
      i = len
      while Ops.greater_than(i, 0)
        digit = Ops.modulo(rnum, base)
        rnum = Ops.divide(rnum, base)
        ret = Ops.add(ret, Builtins.substring(digits, digit, 1))
        i = Ops.subtract(i, 1)
      end
      ret
    end

    # Format file name - truncate the middle part of the directory to fit to the reqested lenght.
    # Path elements in the middle of the string are replaced by ellipsis (...).
    # The result migth be longer that requested size if size of the last element
    # (with ellipsis) is longer than the requested size. If the requested size is greater than
    # size of the input then the string is not modified. The last part (file name) is never removed.
    #
    # @example FormatFilename("/really/very/long/file/name", 15) -> "/.../file/name"
    # @example FormatFilename("/really/very/long/file/name", 5) -> ".../name"
    # @example FormatFilename("/really/very/long/file/name", 100) -> "/really/very/long/file/name"
    #
    # @param [String] file_path file name
    # @param [Fixnum] len requested maximum lenght of the output
    # @return [String] Truncated file name
    def FormatFilename(file_path, len)
      return file_path if Ops.less_or_equal(Builtins.size(file_path), len)

      dir = Builtins.splitstring(file_path, "/")
      file = Ops.get(dir, Ops.subtract(Builtins.size(dir), 1), "")
      dir = Builtins.remove(dir, Ops.subtract(Builtins.size(dir), 1))

      # there is a slash at the end, add the directory name
      if file == ""
        file = Ops.add(
          Ops.get(dir, Ops.subtract(Builtins.size(dir), 1), ""),
          "/"
        )
        dir = Builtins.remove(dir, Ops.subtract(Builtins.size(dir), 1))
      end

      if Ops.less_or_equal(Builtins.size(Builtins.mergestring(dir, "/")), 3) ||
          Builtins.size(dir) == 0
        # the path is short, replacing by ... cannot help
        return file_path
      end

      ret = ""
      loop do
        # put the ellipsis in the middle of the path
        ellipsis = Ops.divide(Builtins.size(dir), 2)

        # ellipsis - used to replace part of text to make it shorter
        # example: "/really/very/long/file/name", "/.../file/name")
        Ops.set(dir, ellipsis, _("..."))

        ret = Builtins.mergestring(Builtins.add(dir, file), "/")

        if Ops.greater_than(Builtins.size(ret), len)
          # still too long, remove the ellipsis and start a new iteration
          dir = Builtins.remove(dir, ellipsis)
        else
          # the size is OK
          break
        end
        break unless Ops.greater_than(Builtins.size(dir), 0)
      end

      ret
    end

    # Remove a shortcut from a label, so that it can be inserted into help
    # to avoid risk of different translation of the label
    # @param [String] label string a label possibly including a shortcut
    # @return [String] the label without the shortcut mark
    def RemoveShortcut(label)
      ret = label
      if Builtins.regexpmatch(label, "^(.*[^&])?(&&)*&[[:alnum:]].*$")
        ret = Builtins.regexpsub(
          label,
          "^((.*[^&])?(&&)*)&([[:alnum:]].*)$",
          "\\1\\4"
        )
      end
      ret
    end

    # Checks whether string str starts with test.
    def StartsWith(str, test)
      Builtins.search(str, test) == 0
    end

    # Find a mount point for given directory/file path. Returns "/" if no mount point matches
    # @param dir requested path , e.g. "/usr/share"
    # @param dirs list of mount points, e.g. [ "/", "/usr", "/boot" ]
    # @return string a mount point from the input list or "/" if not found
    def FindMountPoint(dir, dirs)
      dirs = deep_copy(dirs)
      while !dir.nil? && dir != "" && !Builtins.contains(dirs, dir)
        # strip the last path component and try it again
        comps = Builtins.splitstring(dir, "/")
        comps = Builtins.remove(comps, Ops.subtract(Builtins.size(comps), 1))
        dir = Builtins.mergestring(comps, "/")
      end

      dir = "/" if dir.nil? || dir == ""

      dir
    end

    publish function: :Quote, type: "string (string)"
    publish function: :UnQuote, type: "string (string)"
    publish function: :OptParens, type: "string (string)"
    publish function: :NonEmpty, type: "list <string> (list <string>)"
    publish function: :NewlineItems, type: "list <string> (string)"
    publish function: :YesNo, type: "string (boolean)"
    publish function: :FormatSizeWithPrecision, type: "string (integer, integer, boolean)"
    publish function: :FormatSize, type: "string (integer)"
    publish function: :FormatRateMessage, type: "string (string, integer, integer)"
    publish function: :FormatTime, type: "string (integer)"
    publish function: :CutBlanks, type: "string (string)"
    publish function: :CutZeros, type: "string (string)"
    publish function: :Repeat, type: "string (string, integer)"
    publish function: :SuperPad, type: "string (string, integer, string, symbol)"
    publish function: :Pad, type: "string (string, integer)"
    publish function: :PadZeros, type: "string (string, integer)"
    publish function: :ParseOptions, type: "list <string> (string, map)"
    publish function: :CutRegexMatch, type: "string (string, string, boolean)"
    publish function: :EscapeTags, type: "string (string)"
    publish function: :FirstChunk, type: "string (string, string)"
    publish function: :CLower, type: "string ()"
    publish function: :CAlpha, type: "string ()"
    publish function: :CDigit, type: "string ()"
    publish function: :CAlnum, type: "string ()"
    publish function: :CGraph, type: "string ()"
    publish function: :CPrint, type: "string ()"
    publish function: :ValidCharsFilename, type: "string ()"
    publish function: :TextTable, type: "string (list <string>, list <list <string>>, map <string, any>)"
    publish function: :UnderlinedHeader, type: "string (string, integer)"
    publish function: :Replace, type: "string (string, string, string)"
    publish function: :Random, type: "string (integer)"
    publish function: :FormatFilename, type: "string (string, integer)"
    publish function: :RemoveShortcut, type: "string (string)"
    publish function: :StartsWith, type: "boolean (string, string)"
    publish function: :FindMountPoint, type: "string (string, list <string>)"

  private

    # Optional formatted text
    # @return sformat (f, s) if s is neither empty or nil, else ""
    def opt_format(f, s)
      s == "" || s.nil? ? "" : Builtins.sformat(f, s)
    end

    # Return a pretty description of a download rate
    #
    # Return a pretty description of a download rate, with two fraction digits
    # and using B/s, KiB/s, MiB/s, GiB/s or TiB/s as unit as appropriate.
    #
    # @param [Fixnum] bytes_per_second download rate (in B/s)
    # @return formatted string
    #
    # @example format_rate(6780) -> ""
    # @example format_rate(0) -> ""
    # @example format_rate(895321) -> ""
    def format_rate(bytes_per_second)
      # covert a number to download rate string
      # %1 is string - size in bytes, B, KiB, MiB, GiB or TiB
      Builtins.sformat(_("%1/s"), FormatSize(bytes_per_second))
    end
  end

  String = StringClass.new
  String.main
end
