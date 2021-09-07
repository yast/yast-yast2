# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "yast"

# Class to get information about shared libraries used by a process from its
# /proc/self/maps file.
#
# You can also get information for a different process by specifying its
# /proc/$pid/maps file.
#
# For testing, a fixed file can be used.
module Yast2
  class SharedLibInfo
    include Yast::Logger

    # @return [Array<String>] Complete paths of the shared libs
    attr_reader :shared_libs

    def initialize(maps_file = "/proc/self/maps")
      clear
      read(maps_file)
    end

    def clear
      @shared_libs = []
    end

    def read(maps_file = "/proc/self/maps")
      return if maps_file.nil? || maps_file.empty?

      open(maps_file).each { |line| parse_maps_line(line) }
      @shared_libs.uniq!
    end

    # Return the directory name of a shared lib with a full path.
    # This is really only an alias for File.dirname().
    #
    def self.dirname(lib)
      File.dirname(lib)
    end

    # Return the library basename of a shared lib (with or without a full
    # path). Unlike File.basename(), this also cuts off the SO number.
    #
    # Example:
    #   "/usr/lib64/libscr.so.3.0.0" -> "libscr"
    #   "/usr/lib64/libc-2.33.so"    -> "libc-2.33"
    #
    def self.lib_basename(lib)
      split_lib_name(lib).first
    end

    # Return the so number of a shared lib (with or without a full
    # path).
    #
    # Example:
    #   "/usr/lib64/libscr.so.3.0.0" -> "3.0.0"
    #   "/usr/lib64/libc-2.33.so"    -> nil
    #
    def self.so_number(lib)
      split_lib_name(lib).last
    end

    # Split a library name (with or without a full path) up into its base name
    # and its SO number and return both.
    #
    # Example:
    #   "/usr/lib64/libscr.so.3.0.0" -> ["libscr", "3.0.0"]
    #   "/usr/lib64/libc-2.33.so"    -> ["libc-2.33", nil]
    #
    def self.split_lib_name(lib)
      full_name = File.basename(lib) # "libscr.so.3.0.0"
      full_name.split(/\.so\.?/) # ["libscr", "3.0.0"]
    end

    private

    # Parse one entry of /proc/self/maps and add an entry to @shared_libs if
    # applicable.
    #
    # @param line [String] one line of /proc/self/maps
    # @return [String, nil] the shared lib with path on this line
    #
    def parse_maps_line(line)
      # Sample lines:
      #
      # 7fb22485f000-7fb22486f000 r--p 000f0000 08:02 132839    /usr/lib64/yui/libyui-qt.so.15.0.0
      # 7fb22486f000-7fb224872000 rw-p 00100000 08:02 132839    /usr/lib64/yui/libyui-qt.so.15.0.0
      # 7fb2248a2000-7fb2248d8000 r--p 00000000 08:02 1054948   /usr/lib64/libyui.so.15.0.0
      # 7f8cadbc5000-7f8cadbc9000 rw-p 00000000 00:00 0
      # 7fffe6181000-7fffe6183000 r-xp 00000000 00:00 0         [vdso]
      #
      # See also
      # https://www.kernel.org/doc/html/latest/filesystems/proc.html
      line.strip!
      return nil if line.empty? || line.start_with?("#")

      path = line.split[5]
      @shared_libs << path unless path.nil? || path.start_with?("[")
      path
    end
  end
end
