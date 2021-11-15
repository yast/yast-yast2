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
require "yast2/ui_plugin_info"

Yast.import "Package"
Yast.import "Report"
Yast.import "Popup"

module Yast
  # Class to check if a UI extension plug-in ("pkg", "graph") is installed.
  # If it's not installed, ask the user if the package containing it should be
  # installed and (if the user answers "yes") install it.
  #
  class UIExtensionChecker
    include Yast::Logger
    include Yast::I18n

    # Constructor: Create a UI extension checker for the specified extension.
    #
    # @param ext_name [String] Short name of the UI extension ("pkg", "graph")
    # @param force_ui [Boolean] Enforce creating a UI?
    #
    def initialize(ext_name, force_ui = true)
      textdomain "base"
      @ext_name = ext_name
      @ok = false
      ensure_ui_created if force_ui
      @ui_plugin_info = UIPluginInfo.new
      ensure_ext_installed
    end

    # Check if the UI extension was either installed to begin with or if the
    # user (after being asked) confirmed to install it, and it was installed
    # successfully.
    #
    # @return [Boolean] UI extension is available now
    #
    def ok?
      @ok
    end

  private

    # Ensure that the UI extension is installed: If it isn't installed yet
    # anyway, ask the user if it should be installed and if yes, install it.
    #
    # @return [Boolean] UI extension is available now (same as ok?)
    #
    def ensure_ext_installed
      return if installed?

      if available_for_ui?
        ask && install
      else
        not_available_error
      end
      @ok
    end

    # Ensure that the UI is actually created: In CLI mode, that might be
    # delayed because normally they should't create a UI at all.
    #
    def ensure_ui_created
      # Just a UI call that doesn't do anything; this is already sufficient to
      # load the UI main plug-in completely if it wasn't loaded yet.
      # See also bsc#1192650
      UI.WidgetExists(:foo)
    end

    # Check if the UI extension plug-in is installed.
    # This also sets @ok.
    #
    # @return [Boolean] true if the UI extension is already installed, false if not
    #
    def installed?
      # Notice that this intentionally checks if the extension plug-in binary
      # is available, and that it is available in the same path as the main UI
      # plug-in: That way it also works for libyui developers that had to bump
      # the UI SO version, or for third-party developers who like to install
      # their binaries to a different path to avoid interfering with existing
      # distro packages.
      #
      # If this would check for the package instead (which includes the SO
      # number, e.g. libyui-qt-pkg42 for libyui-qt42), none of that would work:
      # After a libyui SO version bump, there is no corresponding package yet
      # in OBS with that name that could be installed, so this would always
      # throw an error - an error that is hard to recover from in a development
      # environment.
      #
      # 2021-09-15 shundhammer
      #
      ext_plugin = @ui_plugin_info.ui_extension_plugin_complete(@ext_name)
      @ok = File.exist?(ext_plugin)
      log.info("Not found: #{ext_plugin}") unless @ok
      @ok
    end

    # Open a dialog to ask the user if the UI extension should be installed.
    #
    # @return [Boolean] true if the user wants to install the extension, false if not
    #
    def ask
      # Translators: %s is a software packge name like libyui-qt-pkg15
      msg = _("This needs package %s to be installed.") % ext_pkg
      msg += "\n\n"
      msg += _("Press \"Continue\" to install this package now or \"Cancel\" to exit.")
      @ok = Popup.ContinueCancel(msg)
    end

    # Install the package for the UI extension.
    # This also sets @ok.
    #
    def install
      @ok = Package.DoInstall([ext_pkg])
      if !@ok
        log.error("UI extension package could not be installed: #{ext_pkg}")
        # Translators: %s is a software packge name like libyui-qt-pkg15
        Report.Error(_("Package %s could not be installed.") % ext_pkg)
      end
      @ok
    end

    # Return the package name for the UI extension.
    #
    # @return [String] package name
    #
    def ext_pkg
      @ui_plugin_info.ui_extension_pkg(@ext_name)
    end

    # Check if the UI extension is available for this UI.
    #
    # @return [Boolean] true if the extension is available, false if not
    #
    def available_for_ui?
      ui = @ui_plugin_info.main_ui_plugin
      case @ext_name
      when "pkg"
        ["qt", "ncurses"].include?(ui)
      when "graph"
        ui == "qt"
      else
        log.error("Unknown UI extension #{@ext_name}")
        false
      end
    end

    # Post an error that the UI extension is not available for this UI.
    #
    def not_available_error
      @ok = false
      # Translators: %s is a UI extension name like pkg or graph
      Report.Error(_("UI extension \"%s\" is not available for this UI.") % @ext_name)
    end
  end
end
