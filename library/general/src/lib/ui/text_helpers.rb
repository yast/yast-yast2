# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

module UI
  # Provides a set of methods to manipulate and transform UI text
  module TextHelpers
    # Wrap text breaking lines in the first whitespace that does not exceed given line width
    #
    # Additionally, it also allows retrieving only an excerpt of the wrapped text according to the
    # maximum number of lines indicated, adding one more with the cut_text text when it is given.
    #
    # @param text [String] text to be wrapped
    # @param line_width [Integer] max line length
    # @param n_lines [Integer, nil] the maximum number of lines
    # @param cut_text [String] the omission text to be used when the text should be cut
    #
    # @return [String]
    def wrap_text(text, line_width = 76, n_lines: nil, cut_text: "")
      return text if line_width > text.length

      wrapped_text = text.lines.collect! do |line|
        l = (line.length > line_width) ? line.gsub(/(.{1,#{line_width}})(?:\s+|$)/, "\\1\n") : line
        l.strip
      end

      result = wrapped_text.join("\n")
      result = head(result, n_lines, omission: cut_text) if n_lines
      result
    end

    # Returns only the first requested lines of the given text
    #
    # If the omission param is given, an extra line holding it will be included
    #
    # @param text [String]
    # @param max_lines [Integer]
    # @param omission [String] the text to be added
    #
    # @return [String] the first requested lines if the text has more; full text otherwise
    def head(text, max_lines, omission: "")
      lines = text.lines

      return text if lines.length <= max_lines

      result = text.lines[0...max_lines]
      result << omission unless omission.empty?
      result.join
    end

    # Wrap a given text in direction markers
    #
    # @param [String] text to be wrapped. This text may contain tags and they
    #   will not be escaped
    # @param [String] language code (it gets the current one by default)
    # @return [String] wrapped text
    def div_with_direction(text, lang = nil)
      Yast.import "Language"
      lang ||= Yast::Language.language
      # RTL languages: Arabic, Farsi, Hebrew
      direction = lang.start_with?("ar", "fa", "he") ? "rtl" : "ltr"
      "<div dir=\"#{direction}\">#{text}</div>"
    end
  end
end
