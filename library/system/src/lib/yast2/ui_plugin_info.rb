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
require "yast2/shared_lib_info"

module Yast
  # Class to get information about UI plug-ins used by a process (by default
  # the current process) from its /proc/self/maps file.
  #
  # You can also get information for a different process by specifying its
  # /proc/$pid/maps file.
  #
  # For testing, a fixed file can be used.
  class UiPluginInfo < SharedLibInfo
    include Yast::Logger

    # Constructor.
    # @param maps_file [String] name of the maps file to use
    #
    def initialize(maps_file = "/proc/self/maps")
      @ui_plugins = nil # Lazy init
      super(maps_file)
      log.info("Creating SharedLibInfo from #{maps_file}")
    end

    # Find the UI plug-ins among the shared libs.
    #
    # @return [Array<String>] Complete paths of the UI plug-ins
    #
    def ui_plugins
      @ui_plugins ||= shared_libs.select { |lib| lib =~ /yui\/libyui-/ }
      log.info("UI plug-ins: #{@ui_plugins}")
      @ui_plugins
    end

    # Return the short name of a UI plug-in, i.e. only the lib base name with
    # any leading "libyui-" removed, i.e. something like "qt", "ncurses".
    #
    # @param ui_plugin [String] full name (with or without path) of the UI plug-in
    # @return [String] corresponding short name
    #
    def short_name(ui_plugin)
      name = SharedLibInfo.lib_basename(ui_plugin)
      return nil if name.nil?

      name.gsub(/^libyui-/, "")
    end

    # Find the main UI plug-in (if there are several).
    # This is generally the one with the shortest name.
    #
    # @return [String, nil] Short name of the main UI plug-in
    def main_ui_plugin
      return nil if ui_plugins.empty?

      plugins = ui_plugins.map { |p| SharedLibInfo.lib_basename(p) }
      main_plugin = plugins.min { |a, b| a.size <=> b.size }
      short_name(main_plugin)
    end

    # Find the SO number of the UI main plug-in.
    #
    # @return [String, nil] SO number (e.g. "15.0.0")
    #
    def ui_so_number
      ui_short_name = main_ui_plugin
      return nil if ui_short_name.nil?

      plugin = ui_plugins.find { |p| p =~ /#{ui_short_name}\.so/ }
      SharedLibInfo.so_number(plugin)
    end

    # Find the SO major number of the UI main plug-in.
    #
    # @return [String, nil] SO number (e.g. "15")
    #
    def ui_so_major
      so = ui_so_number
      return nil if so.nil?

      so.split(".").first
    end
  end
end
