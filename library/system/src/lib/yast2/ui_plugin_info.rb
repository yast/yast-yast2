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
  #
  # The information stored in this class is only a snapshot in the life time of
  # the process. As new shared libs are loaded (e.g. plug-ins are loaded with
  # dlopen()), this information may become outdated. In that case, simply let
  # the old instance go out of scope and create a new one.
  #
  # More information: https://github.com/yast/yast-yast2/pull/1194
  #
  class UiPluginInfo < SharedLibInfo
    include Yast::Logger

    # Constructor.
    # @param maps_file [String] name of the maps file to use
    #
    def initialize(maps_file = "/proc/self/maps")
      super
      # Lazy init for those member variables
      @ui_plugins = nil
      @main_ui_plugin_complete = nil
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
      name&.gsub(/^libyui-/, "")
    end

    # Return the complete name (with path and SO number) of the main UI
    # plug-in.  Several UI plug-ins might be loaded; the main plug-in is
    # generally the one with the shortest lib base name ("qt", "qt-pkg",
    # "qt-graph"; "ncurses", "ncurses-pkg").
    #
    # @return [String, nil] Complete name of the main UI plug-in
    #
    def main_ui_plugin_complete
      return nil if ui_plugins.empty?

      relevant_plugins = ui_plugins.reject { |p| p =~ /rest-api/ }
      @main_ui_plugin_complete ||= relevant_plugins.min do |a, b|
        SharedLibInfo.lib_basename(a).size <=> SharedLibInfo.lib_basename(b).size
      end
      @main_ui_plugin_complete
    end

    # Return the short name of the main UI plug-in, i.e. without path,
    # "libyui-" prefix and SO number Several UI plug-ins might be loaded; the
    # main plug-in is generally the one with the shortest lib base name ("qt",
    # "qt-pkg", "qt-graph"; "ncurses", "ncurses-pkg").
    #
    # @return [String, nil] Short name of the main UI plug-in
    #
    def main_ui_plugin
      name = SharedLibInfo.lib_basename(main_ui_plugin_complete)
      name&.gsub!(/^libyui-/, "")
    end

    # Find the SO number of the UI main plug-in.
    #
    # @return [String, nil] SO number (e.g. "15.0.0")
    #
    def ui_so_number
      SharedLibInfo.so_number(main_ui_plugin_complete)
    end

    # Find the SO major number of the UI main plug-in.
    #
    # @return [String, nil] SO number (e.g. "15")
    #
    def ui_so_major
      SharedLibInfo.so_major(main_ui_plugin_complete)
    end

    # Return the name of a UI extension plug-in with SO number for the current
    # UI main plug-in.
    #
    # Example:
    #   "pkg" for "libyui-qt.so.15.0.0" -> "libyui-qt-pkg.so.15.0.0"
    #   "pkg" for "libyui-ncurses.so.15.0.0" -> "libyui-ncurses-pkg.so.15.0.0"
    #
    # @param ext [String] Short name for the UI extension ("pkg", "graph")
    # @return [String] lib name without path for that extension and the current UI
    #
    def ui_extension_plugin(ext)
      (ui_name, so_number) = SharedLibInfo.split_lib_name(main_ui_plugin_complete)
      return nil if ui_name.nil?

      SharedLibInfo.build_lib_name("#{ui_name}-#{ext}", so_number)
    end

    # Return the complete name (with path) of a UI extension plug-in with SO
    # number for the current UI main plug-in.
    #
    # Example:
    #   "pkg" for "/usr/lib64/yui/libyui-qt.so.15.0.0" -> "/usr/lib64/yui/libyui-qt-pkg.so.15.0.0"
    #   "pkg" for "/usr/lib64/yui/libyui-ncurses.so.15.0.0" -> "/usr/lib64/yui/libyui-ncurses-pkg.so.15.0.0"
    #
    # @param ext [String] Short name for the UI extension ("pkg", "graph")
    # @return [String] lib name with path for that extension and the current UI
    #
    def ui_extension_plugin_complete(ext)
      return nil if main_ui_plugin_complete.nil?

      File.join(File.dirname(main_ui_plugin_complete), ui_extension_plugin(ext))
    end

    # Return the package name (with standard SUSE libyui package naming
    # conventions) for a UI extension for the current UI main plug-in.
    #
    # Example:
    #   "pkg" for "libyui-qt.so.15.0.0" -> "libyui-qt-pkg15"
    #   "pkg" for "libyui-ncurses.so.15.0.0" -> "libyui-ncurses-pkg15"
    #
    # @param ext [String] Short name for the UI extension ("pkg", "graph")
    # @return [String] package name for that extension and the current UI
    #
    def ui_extension_pkg(ext)
      ui = main_ui_plugin
      return nil if ui.nil?

      "libyui-#{ui}-#{ext}#{ui_so_major}"
    end
  end
end
