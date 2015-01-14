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
# File:	modules/Package.ycp
# Package:	yast2
# Summary:	Packages manipulation
# Authors:	Martin Vidner <mvidner@suse.cz>
#		Michal Svec <msvec@suse.cz>
# Flags:	Stable
#
# $Id$
#
# The documentation is maintained at
# <a href="../index.html">.../docs/index.html</a>.
require "yast"

module Yast
  class PackageClass < Module
    def main
      textdomain "base"

      Yast.import "Mode"
      Yast.import "PackageAI"
      Yast.import "PackageSystem"

      # **
      # Packages Manipulation

      @FunctionsSystem = {
        "DoInstall"          => fun_ref(
          PackageSystem.method(:DoInstall),
          "boolean (list <string>)"
        ),
        "DoRemove"           => fun_ref(
          PackageSystem.method(:DoRemove),
          "boolean (list <string>)"
        ),
        "DoInstallAndRemove" => fun_ref(
          PackageSystem.method(:DoInstallAndRemove),
          "boolean (list <string>, list <string>)"
        ),
        "Available"          => fun_ref(
          PackageSystem.method(:Available),
          "boolean (string)"
        ),
        "Installed"          => fun_ref(
          PackageSystem.method(:Installed),
          "boolean (string)"
        ),
        "InstallKernel"      => fun_ref(
          PackageSystem.method(:InstallKernel),
          "boolean (list <string>)"
        ),
        "PackageInstalled"   => fun_ref(
          PackageSystem.method(:PackageInstalled),
          "boolean (string)"
        ),
        "PackageAvailable"   => fun_ref(
          PackageSystem.method(:PackageAvailable),
          "boolean (string)"
        )
      }

      @FunctionsAI = {
        "DoInstall"          => fun_ref(
          PackageAI.method(:DoInstall),
          "boolean (list <string>)"
        ),
        "DoRemove"           => fun_ref(
          PackageAI.method(:DoRemove),
          "boolean (list <string>)"
        ),
        "DoInstallAndRemove" => fun_ref(
          PackageAI.method(:DoInstallAndRemove),
          "boolean (list <string>, list <string>)"
        ),
        "Available"          => fun_ref(
          PackageAI.method(:Available),
          "boolean (string)"
        ),
        "Installed"          => fun_ref(
          PackageAI.method(:Installed),
          "boolean (string)"
        ),
        "InstallKernel"      => fun_ref(
          PackageAI.method(:InstallKernel),
          "boolean (list <string>)"
        ),
        "PackageInstalled"   => fun_ref(
          PackageAI.method(:PackageInstalled),
          "boolean (string)"
        ),
        "PackageAvailable"   => fun_ref(
          PackageAI.method(:PackageAvailable),
          "boolean (string)"
        )
      }

      @last_op_canceled = false

      Yast.include self, "packages/common.rb"
    end

    # If Yast is running in the autoyast configuration mode
    # no changes will be done on the target system by using
    # the PackageAI class.
    def functions
      Mode.config ? @FunctionsAI : @FunctionsSystem
    end

    # Install list of packages
    # @param [Array<String>] packages list of packages to be installed
    # @return True on success
    def DoInstall(packages)
      packages = deep_copy(packages)
      function = Convert.convert(
        Ops.get(functions, "DoInstall"),
        from: "any",
        to:   "boolean (list <string>)"
      )
      function.call(packages)
    end

    # Remove list of packages
    # @param [Array<String>] packages list of packages to be removed
    # @return True on success
    def DoRemove(packages)
      packages = deep_copy(packages)
      function = Convert.convert(
        Ops.get(functions, "DoRemove"),
        from: "any",
        to:   "boolean (list <string>)"
      )
      function.call(packages)
    end

    # Install and Remove list of packages in one go
    # @param [Array<String>] toinstall list of packages to be installed
    # @param [Array<String>] toremove list of packages to be removed
    # @return True on success
    def DoInstallAndRemove(toinstall, toremove)
      toinstall = deep_copy(toinstall)
      toremove = deep_copy(toremove)
      function = Convert.convert(
        Ops.get(functions, "DoInstallAndRemove"),
        from: "any",
        to:   "boolean (list <string>, list <string>)"
      )
      function.call(toinstall, toremove)
    end

    def Available(package)
      function = Convert.convert(
        Ops.get(functions, "Available"),
        from: "any",
        to:   "boolean (string)"
      )
      function.call(package)
    end

    def Installed(package)
      function = Convert.convert(
        Ops.get(functions, "Installed"),
        from: "any",
        to:   "boolean (string)"
      )
      function.call(package)
    end

    def PackageAvailable(package)
      function = Convert.convert(
        Ops.get(functions, "PackageAvailable"),
        from: "any",
        to:   "boolean (string)"
      )
      function.call(package)
    end

    def PackageInstalled(package)
      function = Convert.convert(
        Ops.get(functions, "PackageInstalled"),
        from: "any",
        to:   "boolean (string)"
      )
      function.call(package)
    end

    def InstallKernel(kernel_modules)
      kernel_modules = deep_copy(kernel_modules)
      function = Convert.convert(
        Ops.get(functions, "InstallKernel"),
        from: "any",
        to:   "boolean (list <string>)"
      )
      function.call(kernel_modules)
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
  end

  Package = PackageClass.new
  Package.main
end
