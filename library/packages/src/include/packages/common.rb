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
module Yast
  module PackagesCommonInclude
    def initialize_packages_common(_include_target)
      textdomain "base"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Mode"
      Yast.import "CommandLine"
    end

    # Are all of these packages available?
    # @param [Array<String>] packages list of packages
    # @return [Boolean] true if yes (nil = an error occurred)
    def AvailableAll(packages)
      packages = deep_copy(packages)
      error = false

      which = Builtins.find(packages) do |p|
        avail = Available(p)
        error = true if avail.nil?
        !avail
      end

      return nil if error

      which.nil?
    end

    # Is any of these packages available?
    # @param [Array<String>] packages list of packages
    # @return [Boolean] true if yes (nil = an error occurred)
    def AvailableAny(packages)
      packages = deep_copy(packages)
      error = false

      which = Builtins.find(packages) do |p|
        avail = Available(p)
        error = true if avail.nil?
        avail
      end

      return nil if error

      !which.nil?
    end

    # Are all of these packages installed?
    # @param [Array<String>] packages list of packages
    # @return [Boolean] true if yes
    def InstalledAll(packages)
      packages = deep_copy(packages)
      which = Builtins.find(packages) { |p| !Installed(p) }
      which.nil?
    end

    # Is any of these packages installed?
    # @param [Array<String>] packages list of packages
    # @return [Boolean] true if yes
    def InstalledAny(packages)
      packages = deep_copy(packages)
      which = Builtins.find(packages) { |p| Installed(p) }
      !which.nil?
    end

    def AskPackages(packs, install)
      packs = deep_copy(packs)
      pkgs = Builtins.mergestring(packs, ", ")
      text = if install
               # the message is followed by list of required packages
               _("These packages need to be installed:")
      else
               # the message is followed by list of required packages
               _("These packages need to be removed:")
      end

      text += " " + pkgs

      CommandLine.Print(text)

      CommandLine.YesNo
    end

    # Main package installatio|removal dialog
    # @param [Array<String>] packages list of packages
    # @param [Boolean] install true if install, false if remove
    # @param [String] message optional installation|removal text (nil -> standard will be used)
    # @return true on success
    def PackageDialog(packages, install, message)
      packages = deep_copy(packages)
      Builtins.y2debug("Asking for packages: %1", packages)
      packs = Builtins.filter(packages) do |package|
        install ? !Installed(package) : Installed(package)
      end
      Builtins.y2debug("Remaining packages: %1", packs)

      return true if Ops.less_than(Builtins.size(packs), 1)

      # Popup Text
      text = _("These packages need to be installed:") + "<p>"
      # Popup Text
      text = _("These packages need to be removed:") + "<p>" if install == false

      Builtins.foreach(packs) do |p|
        text = Ops.add(text, Builtins.sformat("%1<br>", p))
      end

      if !message.nil?
        text = Builtins.sformat(message, Builtins.mergestring(packs, ", "))
      end

      doit = if Mode.commandline
               CommandLine.Interactive ? AskPackages(packs, install) : true
      else
               Popup.AnyQuestionRichText(
                 "",
                 text,
                 40,
                 10,
                 # labels changed for bug #215195
                 #	Label::ContinueButton (), Label::CancelButton (),
                 # push button label
                 install ? Label.InstallButton : _("&Uninstall"),
                 Label.CancelButton,
                 :focus_yes
               )
      end

      if doit
        @last_op_canceled = false
        return DoRemove(packs) if install == false
        return DoInstall(packs)
      end

      @last_op_canceled = true
      false
    end

    # Install a package with a custom text message
    # @param [String] package to be installed
    # @param [String] message custom text message
    # @return True on success
    def InstallMsg(package, message)
      PackageDialog([package], true, message)
    end

    # Install list of packages with a custom text message
    # @param [Array<String>] packages The list packages to be installed
    # @param [String] message custom text message
    # @return True on success
    def InstallAllMsg(packages, message)
      packages = deep_copy(packages)
      PackageDialog(packages, true, message)
    end
    # FIXME

    # Remove a package with a custom text message
    # @param [String] package  package to be removed
    # @param [String] message custom text message
    # @return True on success
    def RemoveMsg(package, message)
      PackageDialog([package], false, message)
    end

    # Remove a list of packages with a custom text message
    # @param [Array<String>] packages The list of packages to be removed
    # @param [String] message custom text message
    # @return True on success
    def RemoveAllMsg(packages, message)
      packages = deep_copy(packages)
      PackageDialog(packages, false, message)
    end

    def Install(package)
      InstallMsg(package, nil)
    end

    def InstallAll(packages)
      packages = deep_copy(packages)
      InstallAllMsg(packages, nil)
    end
    # FIXME

    def Remove(package)
      RemoveMsg(package, nil)
    end

    def RemoveAll(packages)
      packages = deep_copy(packages)
      RemoveAllMsg(packages, nil)
    end

    # Return result of the last operation
    # Use immediately after calling any Package*:: function
    # @return true if it last operation was canceled
    def LastOperationCanceled
      @last_op_canceled
    end
  end
end
