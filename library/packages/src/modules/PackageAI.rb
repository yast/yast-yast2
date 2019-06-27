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
# File:  modules/PackageAI.ycp
# Package:  yast2
# Summary:  Packages manipulation (autoinstallation)
# Authors:  Martin Vidner <mvidner@suse.cz>
#    Michal Svec <msvec@suse.cz>
# Flags:  Stable
#
# $Id$
require "yast"

module Yast
  class PackageAIClass < Module
    def main
      textdomain "base"

      @toinstall = []
      @toremove = []

      @last_op_canceled = false

      Yast.include self, "packages/common.rb"

      # default value of settings modified
      @modified = false
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    def DoInstall(packages)
      packages = deep_copy(packages)
      @toinstall = Convert.convert(
        Builtins.union(@toinstall, packages),
        from: "list",
        to:   "list <string>"
      )
      @toremove = Builtins.filter(@toremove) do |p|
        !Builtins.contains(packages, p)
      end
      @modified = true
      true
    end

    def DoRemove(packages)
      packages = deep_copy(packages)
      @toremove = Convert.convert(
        Builtins.union(@toremove, packages),
        from: "list",
        to:   "list <string>"
      )
      @toinstall = Builtins.filter(@toinstall) do |p|
        !Builtins.contains(packages, p)
      end
      @modified = true
      true
    end

    def DoInstallAndRemove(toinst, torem)
      toinst = deep_copy(toinst)
      torem = deep_copy(torem)
      DoInstall(toinst)
      DoRemove(torem)
      @modified = true
      true
    end

    def Available(_package)
      true
    end

    def Installed(package)
      Builtins.contains(@toinstall, package)
    end

    # Is a package installed? Checks only the package name in contrast to Installed() function.
    # @return true if yes
    def PackageInstalled(package)
      Installed(package)
    end

    # Is a package available? Checks only package name, not list of provides.
    # @return true if yes
    def PackageAvailable(package)
      Available(package)
    end

    def InstallKernel(_kernel_modules)
      # the kernel packages are handled by autoyast on its own
      true
    end

    publish variable: :toinstall, type: "list <string>"
    publish variable: :toremove, type: "list <string>"
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
    publish variable: :modified, type: "boolean"
    publish function: :SetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :PackageInstalled, type: "boolean (string)"
    publish function: :PackageAvailable, type: "boolean (string)"
    publish function: :InstallKernel, type: "boolean (list <string>)"
  end

  PackageAI = PackageAIClass.new
  PackageAI.main
end
