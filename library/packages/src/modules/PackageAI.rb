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
    end

    # Install and remove packages in one go
    #
    # @note In AutoYaST, packages are added or removed from the
    #       {Yast::PackagesProposalClass packages proposal} instead of actually
    #       installing or removing them from the system.
    #
    # @param toinstall [Array<String>] Name of the packages to install
    # @param toremove [Array<String>] Name of the packages to remove
    # @return [Boolean] true on success
    #
    # @see Yast::PackageClass#DoInstallAndRemove
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

    # Determines whether the package is installed or not
    #
    # @note In AutoYaST, this method always returns true.
    #
    # @param package [String] Package name
    # @return [Boolean] true if the package exists; false otherwise
    # @see Yast::PackageClass#Available
    def Available(_package)
      true
    end

    # Determines whether the package is installed or not
    #
    # @note In AutoYaST, this method just checks whether the package is included
    #       in the {Yast::PackagesProposalClass packages proposal}.
    #
    # @param package [String] Package name
    # @return [Boolean] true if the package exists; false otherwise
    #
    # @see Yast::PackageClass#Installed
    def Installed(package)
      PackagesProposal.GetResolvables("autoyast").include?(package)
    end

    # Determines whether the package is installed or not
    #
    # @note In AutoYaST this method is equivalent to #Installed
    #
    # @param package [String] Package name
    # @return [Boolean] true if the package exists; false otherwise
    #
    # @see Yast::PackageClass#PackageInstalled
    def PackageInstalled(package)
      Installed(package)
    end

    # Determines whether the package  with the given name is available
    #
    # @note In AutoYaST this method is equivalent to #Available
    #
    # @param package [String] Package name
    # @return [Boolean] true if the package is available; false otherwise
    # @see Yast::PackageClass#Available
    def PackageAvailable(package)
      Available(package)
    end

    # Installs the given kernel modules
    #
    # @note The kernel packages are handled by AutoYaST on its own, so this
    #       method just does nothing and always returns true.
    #
    # @param _kernel_modules [Array<String>] Names of the kernel modules to install
    # @return [Boolean] Always returns true
    # @see Yast::PackageClass#InstallKernel
    def InstallKernel(_kernel_modules)
      true
    end

    publish function: :Available, type: "boolean (string)"
    publish function: :Installed, type: "boolean (string)"
    publish function: :DoInstallAndRemove, type: "boolean (list <string>, list <string>)"
    publish function: :PackageInstalled, type: "boolean (string)"
    publish function: :PackageAvailable, type: "boolean (string)"
    publish function: :InstallKernel, type: "boolean (list <string>)"
  end

  PackageAI = PackageAIClass.new
  PackageAI.main
end
