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

module Yast
  # Class to get information about shared libraries used by a process (by
  # default the current process) from its /proc/self/maps file.
  #
  # You can also get information for a different process by specifying its
  # /proc/$pid/maps file.
  #
  # For testing, a fixed file can be used.
  class SharedLibInfo
    # @return [Array<String>] Complete paths of the shared libs
    attr_reader :shared_libs

    # Constructor.
    # @param maps_file [String] name of the maps file to use
    #
    def initialize(maps_file = "/proc/self/maps")
      clear
      read(maps_file)
    end

    # Return the library basename of a shared lib. Unlike File.basename(), this
    # also cuts off the SO number.
    #
    # Example:
    #   "/usr/lib64/libscr.so.3.0.0" -> "libscr"
    #   "/usr/lib64/libc-2.33.so"    -> "libc-2.33"
    #
    # @param lib [String] full name (with or without path) of a shared lib
    # @return [String] the name of the lib without path and without .so number
    #
    def self.lib_basename(lib)
      (name, _so_number) = split_lib_name(lib)
      name
    end

    # Return the so number of a shared lib (with or without a full path).
    #
    # Example:
    #   "/usr/lib64/libscr.so.3.0.0" -> "3.0.0"
    #   "/usr/lib64/libc-2.33.so"    -> nil
    #
    # @param lib [String] full name (with or without path) of a shared lib
    # @return [String, nil] the .so number part of the lib ("3.0.0")
    #
    def self.so_number(lib)
      # There might be only one component if there is no SO number,
      # so we can't simply use .last: We want to return nil in that case
      (_name, so_number) = split_lib_name(lib)
      so_number
    end

    # Return the SO major number of a shared lib (with or without a full path)
    #
    # Example:
    #   "/usr/lib64/libscr.so.3.0.0" -> "3"
    #   "/usr/lib64/libc-2.33.so"    -> nil
    #
    # @param lib [String] full name (with or without path) of a shared lib
    # @return [String, nil] the major .so of the lib ("3")
    #
    def self.so_major(lib)
      so = so_number(lib)
      return nil if so.nil?

      so.split(".").first
    end

    # Split a library name (with or without a full path) up into its base name
    # and its SO number and return both.
    #
    # Example:
    #   "/usr/lib64/libscr.so.3.0.0" -> ["libscr", "3.0.0"]
    #   "/usr/lib64/libc-2.33.so"    -> ["libc-2.33", nil]
    #
    # @param lib [String] full name (with or without path) of a shared lib
    # @return [Array<String>, nil] lib name split into name and so number
    #
    def self.split_lib_name(lib)
      return nil if lib.nil?

      full_name = File.basename(lib) # "libscr.so.3.0.0"
      full_name.split(/\.so\.?/) # ["libscr", "3.0.0"]
    end

    # Counterpart to split_lib_name: Build a library name from its base name
    # and its SO number.
    #
    # Example:
    #   "libscr", "3.0.0" -> "libscr.so.3.0.0"
    #   "libc-2.33", nil  -> "libc-2.33.so"
    #
    # @param basename [String] lib base name without path and SO number
    # @param so_number [String] lib SO number or nil or empty
    # @return [String]
    #
    def self.build_lib_name(basename, so_number)
      lib_name = basename + ".so"
      lib_name += "." + so_number unless so_number.nil? || so_number.empty?
      lib_name
    end

  protected

    # Clear all previous content.
    def clear
      @shared_libs = []
    end

    # Read a maps file formatted like /proc/self/maps.
    #
    # @param maps_file [String] name of the maps file to use
    #
    def read(maps_file = "/proc/self/maps")
      return if maps_file.nil? || maps_file.empty?

      File.open(maps_file).each { |line| parse_maps_line(line) }
      @shared_libs.sort!.uniq!
    end

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
      #
      line.strip!
      return nil if line.empty? || line.start_with?("#")

      path = line.split[5]
      return nil if path.nil?

      @shared_libs << path if shared_lib?(path)
      path
    end

    # Check if a path is a shared lib.
    #
    # @param lib [String] full name (with path) of a shared lib
    # @return [Boolean] true if it is a shared lib, false if not
    #
    def shared_lib?(path)
      path =~ /\.so/
    end
  end
end
