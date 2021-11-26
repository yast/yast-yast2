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

Yast.import "PackagesProposal"

module Yast
  class PackageAIClass < Module
    def main
      textdomain "base"

      @last_op_canceled = false

      Yast.include self, "packages/common.rb"
    end

    def DoInstallAndRemove(toinst, torem)
      if !toinst.empty?
        Yast::PackagesProposal.AddResolvables("autoyast", :package, toinst)
        Yast::PackagesProposal.RemoveTaboos("autoyast", toinst) # FIXME: should be done by PackagesProposal
      end

      if !torem.empty?
        Yast::PackagesProposal.AddTaboos("autoyast", torem)
        Yast::PackagesProposal.RemoveResolvables("autoyast", :package, torem)
      end

      true
    end

    def Available(_package)
      true
    end

    def Installed(package)
      PackagesProposal.GetResolvables("autoyast").include?(package)
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
    publish function: :PackageInstalled, type: "boolean (string)"
    publish function: :PackageAvailable, type: "boolean (string)"
    publish function: :InstallKernel, type: "boolean (list <string>)"
  end

  PackageAI = PackageAIClass.new
  PackageAI.main
end
