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
    # Wrap given text breaking lines longer than given wrap size. It supports
    # custom separator, max number of lines to split in and cut text to add
    # as last line if cut was needed.
    #
    # @param [String] text to be wrapped
    # @param [String] wrap size
    # @param [Hash <String>] optional parameters as separator and prepend_text.
    # @return [String] wrap text
    def wrap_text(text, wrap = 76, separator: " ", prepend_text: "",
      n_lines: nil, cut_text: nil)
      lines = []
      message_line = prepend_text
      text.split(/\s+/).each_with_index do |t, i|
        if !message_line.empty? && "#{message_line}#{t}".size > wrap
          lines << message_line
          message_line = ""
        end

        message_line << separator if !message_line.empty? && i != 0
        message_line << t
      end

      lines << message_line if !message_line.empty?

      if n_lines && lines.size > n_lines
        lines = lines[0..n_lines - 1]
        lines << cut_text if cut_text
      end

      lines.join("\n")
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
      direction = lang.start_with?("ar", "he") ? "rtl" : "ltr"
      "<div dir=\"#{direction}\">#{text}</div>"
    end
  end
end
