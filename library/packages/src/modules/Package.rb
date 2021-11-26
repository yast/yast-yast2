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
# File:  modules/Package.ycp
# Package:  yast2
# Summary:  Packages manipulation
# Authors:  Martin Vidner <mvidner@suse.cz>
#    Michal Svec <msvec@suse.cz>
# Flags:  Stable
#
# $Id$
#
# The documentation is maintained at
# <a href="../index.html">.../docs/index.html</a>.
require "yast"
require "forwardable"

Yast.import "Mode"
Yast.import "PackageAI"
Yast.import "PackageSystem"

module Yast
  class PackageClass < Module
    extend Forwardable

    def_delegators :backend, :Installed, :Available, :PackageInstalled,
      :PackageAvailable, :DoInstallAndRemove, :InstallKernel

    # @!method Installed(package)
    #   Determines whether the package is provided or not
    #
    #   This method checks whether any installed package provides the given "package".
    #
    #   @param package [String] Package name
    #   @return [Boolean] true if the package exists; false otherwise
    #   @see PackageInstalled

    # @!method PackageInstalled(package)
    #   Determines whether the package is installed or not
    #
    #   This method check just the package's name.
    #
    #   @param package [String] Package name
    #   @return [Boolean] true if the package exists; false otherwise
    #   @see Installed

    # @!method Available(package)
    #   Determines whether the package is available or not
    #
    #   This method checks whether any available package provides the given "package".
    #
    #   @param package [String] Package name
    #   @return [Boolean] true if the package is available; false otherwise
    #   @see PackageAvailable

    # @!method PackageAvailable(package)
    #   Determines whether the package  with the given name is available
    #
    #   This method check just the package's name.
    #
    #   @param package [String] Package name
    #   @return [Boolean] true if the package is available; false otherwise
    #   @see Available

    # @!method DoInstall(packages)
    #   Installs the given packages
    #   @param packages [Array<String>] Name of the packages to install
    #   @return [Boolean] true if packages were successfully installed

    # @!method DoRemove(packages)
    #   Removes the given packages
    #   @param packages [Array<String>] Name of the packages to remove
    #   @return [Boolean] true if packages were successfully removed

    # @!method DoInstallAndRemove(toinstall, toremove)
    #   Install and remove packages in one go
    #   @param toinstall [Array<String>] Name of the packages to install
    #   @param toremove [Array<String>] Name of the packages to remove
    #   @return [Boolean] true on success

    # @!method InstallKernel(kernel_modules)
    #   Installs the given kernel modules
    #   @param kernel_modules [Array<String>] Names of the kernel modules to install
    #   @return [Boolean] true on success
    def main
      textdomain "base"

      @last_op_canceled = false
      @installed_packages = []
      @removed_packages = []
      Yast.include self, "packages/common.rb"
    end

    # Check if packages are installed
    #
    # Install them if they are not and user approves installation
    #
    # @param packages [Array<String>] list of packages to check (and install)
    # @return [Boolean] true if installation succeeded or packages were installed,
    # false otherwise
    def CheckAndInstallPackages(packages)
      return true if Mode.config
      return true if InstalledAll(packages)

      InstallAll(packages)
    end

    # Check if packages are installed
    #
    #
    # Install them if they are not and user approves installation
    # If installation fails (or wasn't allowed), ask user if he wants to continue
    #
    # @param packages [Array<String>] a list of packages to check (and install)
    # @return [Boolean] true if installation succeeded, packages were installed
    # before or user decided to continue, false otherwise
    def CheckAndInstallPackagesInteractive(packages)
      success = CheckAndInstallPackages(packages)
      return true if success

      if !LastOperationCanceled()
        if Mode.commandline
          # error report
          Report.Error(_("Installing required packages failed."))
        else
          Popup.ContinueCancel(
            # continue/cancel popup
            _(
              "Installing required packages failed. If you continue\n" \
              "without installing required packages,\n" \
              "YaST may not work properly.\n"
            )
          )
        end
      elsif Mode.commandline
        Report.Error(
          # error report
          _("Cannot continue without installing required packages.")
        )
      else
        Popup.ContinueCancel(
          # continue/cancel popup
          _(
            "If you continue without installing required \npackages, YaST may not work properly.\n"
          )
        )
      end
    end

    def DoInstall(packages)
      DoInstallAndRemove(packages, [])
    end

    def DoRemove(packages)
      DoInstallAndRemove([], packages)
    end

    def reset
      @installed_packages.clear
      @removed_packages.clear
    end

    publish function: :Available, type: "boolean (string)"
    publish function: :Installed, type: "boolean (string)"
    publish function: :DoInstall, type: "boolean (list <string>)"
    publish function: :DoRemove, type: "boolean (list <string>)"
    publish function: :DoInstallAndRemove, type: "boolean (list <string>, list <string>)"
    publish function: :AvailableAll, type: "boolean (list <string>)"
    publish function: :AvailableAny, type: "boolean (list <string>)"
    publish function: :InstalledAll, type: "boolean (list <string>)"
    publish function: :InstalledAny, type: "boolean (list <string>)"
    publish function: :InstallMsg, type: "boolean (string, string)"
    publish function: :InstallAllMsg, type: "boolean (list <string>, string)"
    publish function: :InstallAnyMsg, type: "boolean (list <string>, string)"
    publish function: :RemoveMsg, type: "boolean (string, string)"
    publish function: :RemoveAllMsg, type: "boolean (list <string>, string)"
    publish function: :Install, type: "boolean (string)"
    publish function: :InstallAll, type: "boolean (list <string>)"
    publish function: :InstallAny, type: "boolean (list <string>)"
    publish function: :Remove, type: "boolean (string)"
    publish function: :RemoveAll, type: "boolean (list <string>)"
    publish function: :LastOperationCanceled, type: "boolean ()"
    publish function: :PackageAvailable, type: "boolean (string)"
    publish function: :PackageInstalled, type: "boolean (string)"
    publish function: :InstallKernel, type: "boolean (list <string>)"

  private

    # If Yast is running in the autoyast configuration mode
    # no changes will be done on the target system by using
    # the PackageAI class.
    def backend
      Mode.config ? PackageAI : PackageSystem
    end
  end

  Package = PackageClass.new
  Package.main
end
