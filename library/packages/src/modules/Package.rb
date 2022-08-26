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
require "y2packager/resolvable"

Yast.import "CommandLine"
Yast.import "Mode"
Yast.import "PackageAI"
Yast.import "PackageSystem"
Yast.import "Popup"

module Yast
  # This module implements support to query, install and remove packages.
  #
  # ## Prefer Package to PackageSystem
  #
  # Depending on the mode, this module decides if it should interact with PackageSystem (libzypp) or
  # PackageAI (AutoYaST). For instance, if you open a module in the AutoYaST UI, calling to
  # {CheckAndInstallPackages} does not install the package for real. Instead, it adds the package to
  # the list of packages to include in the profile. However, when running on other modes (normal,
  # installation, etc.), it just installs the package.
  #
  # ## Overriding default behavior
  #
  # There might a scenario where you want to force Package to work with the real packages. For
  # instance, while reading the configuration during a `clone_system` operation: the mode is still
  # `autoinst_config` but you are dealing with the underlying system. In those cases, you can force
  # {Package} to work with {PackageSystem}.
  #
  # If you are accessing this module through YCP (for instance, using Perl), you cannot pass the
  # :target option. If you need to specify this option, please consider using {PackageSystem} or
  # {PackageAI} functions directly.
  #
  # @example Forcing to check for packages on the underlying system
  #   Yast::Package.Installed("firewalld", target: :system)
  #
  # See https://bugzilla.suse.com/show_bug.cgi?id=1196963 for further details.
  class PackageClass < Module
    extend Forwardable
    include Yast::Logger

    def_delegators :backend, :Available, :PackageAvailable, :DoInstallAndRemove, :InstallKernel

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

    # @!method InstallKernel(kernel_modules)
    #   Installs the given kernel modules
    #   @param kernel_modules [Array<String>] Names of the kernel modules to install
    #   @return [Boolean] true on success
    def main
      textdomain "base"

      @last_op_canceled = false
      @installed_packages = []
      @removed_packages = []
    end

    # Determines whether the package is provided or not
    #
    # This method checks whether any installed package provides the given "package".
    #
    # @param package [String] Package name
    # @param target [Symbol,nil] :autoinst or :system. If it is nil,
    #   it guesses the backend depending on the mode.
    # @return [Boolean] true if the package exists; false otherwise
    # @see PackageInstalled
    def Installed(package, target: nil)
      find_backend(target).Installed(package)
    end

    # Determines whether the package is installed or not
    #
    # This method check just the package's name.
    #
    # @param package [String] Package name
    # @param target [Symbol,nil] :autoinst or :system. If it is nil,
    #   it guesses the backend depending on the mode.
    # @return [Boolean] true if the package exists; false otherwise
    # @see Installed
    def PackageInstalled(package, target: nil)
      find_backend(target).PackageInstalled(package)
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

    # Install and remove packages in one go
    #
    # @param toinstall [Array<String>] Name of the packages to install
    # @param toremove [Array<String>] Name of the packages to remove
    # @return [Boolean] true on success
    def DoInstallAndRemove(toinstall, toremove)
      ret = backend.DoInstallAndRemove(toinstall, toremove)
      return false unless ret

      if !InstalledAll(toinstall)
        log.error("Required packages have not been installed")
        return false
      end

      true
    end

    def reset
      @installed_packages.clear
      @removed_packages.clear
    end

    # Tries to find a package according to the pattern
    #
    # @param pattern [String] a regex pattern to match, no escaping done
    # @return list of matching package names
    def by_pattern(pattern)
      raise ArgumentError, "Missing search pattern" if pattern.nil? || pattern.empty?

      init_packager

      # NOTE: Resolvable.find
      # - takes POSIX regexp, later select uses Ruby regexp
      # - supports regexps only for dependencies, so we need to filter result
      # according to package name
      Y2Packager::Resolvable.find({ provides_regexp: "^#{pattern}$" }, [:name])
        .select { |p| p.name =~ /\A#{pattern}\z/ }
        .map(&:name)
        .uniq
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
    # @param target [Symbol,nil] :autoinst or :system. If it is nil,
    #   it guesses the backend depending on the mode.
    # @return [Boolean] true if yes
    def InstalledAll(packages, target: nil)
      packages = deep_copy(packages)
      which = Builtins.find(packages) { |p| !Installed(p, target: target) }
      which.nil?
    end

    # Is any of these packages installed?
    # @param [Array<String>] packages list of packages
    # @param target [Symbol,nil] :autoinst or :system. If it is nil,
    #   it guesses the backend depending on the mode.
    # @return [Boolean] true if yes
    def InstalledAny(packages, target: nil)
      packages = deep_copy(packages)
      which = Builtins.find(packages) { |p| Installed(p, target: target) }
      !which.nil?
    end

    # Asks the user if the given packages should be installed or removed
    #
    # It only makes sense in CommandLine mode.
    #
    # @param packs [Array<String>] List of packages to install/remove
    # @param install [Boolean] True to install the packages, false to remove them
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
      log.info "Asking for packages: #{packages}"
      packs = Builtins.filter(packages) do |package|
        install ? !Installed(package) : Installed(package)
      end
      log.info "Remaining packages: #{packs}"

      return true if packs.empty?

      check_transactional_system!(packs, install ? :install : :remove)

      # Popup Text
      text = _("These packages need to be installed:") + "<p>"
      # Popup Text
      text = _("These packages need to be removed:") + "<p>" if install == false

      Builtins.foreach(packs) do |p|
        text = Ops.add(text, Builtins.sformat("%1<br>", p))
      end

      text = Builtins.sformat(message, Builtins.mergestring(packs, ", ")) if !message.nil?

      doit = if Mode.commandline
        CommandLine.Interactive ? AskPackages(packs, install) : true
      else
        Popup.AnyQuestionRichText(
          "",
          text,
          40,
          10,
          # labels changed for bug #215195
          #  Label::ContinueButton (), Label::CancelButton (),
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

    # Installs a package
    #
    # @param package [String] package to be installed
    # @return [Boolean] true on success
    def Install(package)
      InstallMsg(package, nil)
    end

    # Installs a list of packages
    #
    # @param packages [Array<String>] list of packages to be installed
    # @return [Boolean] true on success
    def InstallAll(packages)
      packages = deep_copy(packages)
      InstallAllMsg(packages, nil)
    end

    # Removes a package
    #
    # @param package [String] package to be removed
    # @return [Boolean] true on success
    def Remove(package)
      RemoveMsg(package, nil)
    end

    # Removes a list of packages
    #
    # @param packages [Array<String>] list of packages to be removed
    # @return [Boolean] true on success
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

    # Return if system is transactional and does not support direct package
    # install
    # @return [Boolean]
    def IsTransactionalSystem
      return @transactional unless @transactional.nil?
      mounts = SCR.Read(path(".proc.mounts"))
      root = mounts.find { |m| m["file"] == WFM.scr_root }
      log.info "root in mounts #{root.inspect}"

      raise "Failed to find #{WFM.scr_root} at /proc/mounts" unless root
      # check if there are ro keyword in mount
      @transactional = /(?:^|,)ro(?:,|$)/.match?(root["mntops"])
    end

    publish function: :Available, type: "boolean (string)"
    publish function: :AvailableAll, type: "boolean (list <string>)"
    publish function: :AvailableAny, type: "boolean (list <string>)"
    publish function: :DoInstall, type: "boolean (list <string>)"
    publish function: :DoInstallAndRemove, type: "boolean (list <string>, list <string>)"
    publish function: :DoRemove, type: "boolean (list <string>)"
    publish function: :Install, type: "boolean (string)"
    publish function: :InstallAll, type: "boolean (list <string>)"
    publish function: :InstallAllMsg, type: "boolean (list <string>, string)"
    publish function: :InstallAny, type: "boolean (list <string>)"
    publish function: :InstallAnyMsg, type: "boolean (list <string>, string)"
    publish function: :InstallKernel, type: "boolean (list <string>)"
    publish function: :InstallMsg, type: "boolean (string, string)"
    publish function: :Installed, type: "boolean (string)"
    publish function: :InstalledAll, type: "boolean (list <string>)"
    publish function: :InstalledAny, type: "boolean (list <string>)"
    publish function: :LastOperationCanceled, type: "boolean ()"
    publish function: :PackageAvailable, type: "boolean (string)"
    publish function: :PackageInstalled, type: "boolean (string)"
    publish function: :Remove, type: "boolean (string)"
    publish function: :RemoveAll, type: "boolean (list <string>)"
    publish function: :RemoveAllMsg, type: "boolean (list <string>, string)"
    publish function: :RemoveMsg, type: "boolean (string, string)"
    publish function: :IsTransactionalSystem, type: "boolean ()"
    publish function: :by_pattern, type: "list <string> (string)"

  private

    # Makes sure the package database is initialized.
    def init_packager
      Pkg.TargetInitialize(Installation.destdir)
      Pkg.TargetLoad
      Pkg.SourceRestore
      Pkg.SourceLoad
    end

    # If Yast is running in the autoyast configuration mode
    # no changes will be done on the target system by using
    # the PackageAI class.
    def backend
      Mode.config ? PackageAI : PackageSystem
    end

    # Find the backend for the given target
    #
    # @param target [Symbol,nil] :autoinst or :system. If it is nil,
    #   it guesses the backend depending on the mode.
    def find_backend(target)
      return backend if target.nil?

      found_backend = case target
      when :system
        PackageSystem
      when :autoinst
        PackageAI
      end

      log.warn "select_backend: target '#{target}' is unknown." if found_backend.nil?

      found_backend || backend
    end

    # checks if working on transactional system
    # if so, then it shows popup to user and abort yast
    def check_transactional_system!(packages, mode = :install)
      return unless IsTransactionalSystem()

      msg = _("Transactional system detected. ")
      case mode
      when :install then msg += _("Following packages have to be installed manually:")
      when :remove then msg += _("Following packages have to be removed manually:")
      else
        raise "Unknown mode #{mode}"
      end
      msg += "<p><ul><li>#{packages.join("</li><li>")}</li></ul></p>"
      msg += _("Please start YaST again after reboot.")
      Popup.LongMessage(msg)
      raise Yast::AbortException
    end
  end

  Package = PackageClass.new
  Package.main
end
