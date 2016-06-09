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
# File:	modules/PackageSystem.ycp
# Package:	yast2
# Summary:	Packages manipulation (system)
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
  class PackageSystemClass < Module
    def main
      Yast.import "Pkg"
      textdomain "base"

      Yast.import "Kernel"
      Yast.import "Mode"
      Yast.import "PackageCallbacks"
      Yast.import "PackageLock"
      Yast.import "Report"
      Yast.import "Stage"
      Yast.import "CommandLine"

      # Was last operation canceled?
      #
      # Used to enhance the exit status to distinguish between package
      # installation fail and installation canceled by user, as in the second
      # case doesn't make much sense to display any error
      # Is set to true when user canceled package installation, from
      # PackageSystem::* functions
      @last_op_canceled = false

      # Has Pkg::TargetInit run?
      @target_initialized = false

      # Has Pkg::SourceStartCache run?
      @source_initialized = false

      Yast.include self, "packages/common.rb"

      @_rpm_query_binary_initialized = false
      @_rpm_query_binary = "rpm"
    end

    # Ensure that Pkg:: calls work.
    # This may become superfluous.
    def EnsureTargetInit
      # do not initialize the target system in the first installation stage when
      # running in instsys, there is no RPM DB in the RAM disk image (bnc#742420)
      if Stage.initial && !Mode.live_installation
        Builtins.y2milestone(
          "Skipping target initialization in first stage installation"
        )
        return
      end

      PackageLock.Check
      # always initizalize target, it should be cheap according to #45356
      @target_initialized = Pkg.TargetInit("/", false)

      nil
    end

    # Ensure that Pkg:: calls working with the installation sources work
    def EnsureSourceInit
      PackageLock.Check

      if @source_initialized
        # this way, if somebody closed the cache outside of Package
        # (typically in installation), we will reinitialize
        # it's cheap if cache is already initialized
        Pkg.SourceStartCache(true)
        return
      end

      if !@target_initialized
        # make sure we have the RPM keys imported
        EnsureTargetInit()
      end

      sources = Pkg.SourceStartCache(true)

      if Ops.greater_than(Builtins.size(sources), 0)
        @source_initialized = true
      else
        # all repositories are disabled or no repository defined
        Builtins.y2warning("No package repository available")
      end

      nil
    end

    def DoInstall(packages)
      packages = deep_copy(packages)
      DoInstallAndRemove(packages, [])
    end

    def DoRemove(packages)
      packages = deep_copy(packages)
      DoInstallAndRemove([], packages)
    end

    def SelectPackages(toinstall, toremove)
      toinstall = deep_copy(toinstall)
      toremove = deep_copy(toremove)
      ok = true

      Builtins.foreach(toinstall) do |p|
        if ok == true
          if Pkg.PkgInstall(p) != true
            Builtins.y2error("Package %1 install failed: %2", p, Pkg.LastError)
            ok = false
          end
        end
      end
      return false if ok != true

      Builtins.foreach(toremove) do |p|
        if ok == true
          if Pkg.PkgDelete(p) != true
            Builtins.y2error("Package %1 delete failed: %2", p, Pkg.LastError)
            ok = false
          end
        end
      end

      ok
    end

    def DoInstallAndRemoveInt(toinstall, toremove)
      toinstall = deep_copy(toinstall)
      toremove = deep_copy(toremove)
      Builtins.y2debug("toinstall: %1, toremove: %2", toinstall, toremove)
      return false if !PackageLock.Check

      EnsureSourceInit()
      EnsureTargetInit()
      ok = true

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "PackagesUI"

      # licenses: #35250
      licenses = Pkg.PkgGetLicensesToConfirm(toinstall)
      if Ops.greater_than(Builtins.size(licenses), 0)
        rt_licenses_l = Builtins.maplist(licenses) do |p, l|
          if Mode.commandline
            Builtins.sformat("%1\n%2", p, l)
          else
            Builtins.sformat("<p><b>%1</b></p>\n%2", p, l)
          end
        end

        accepted = false

        if Mode.commandline
          # print the licenses
          CommandLine.Print(Builtins.mergestring(rt_licenses_l, "\n"))
          # print the question
          CommandLine.Print(_("Do you accept this license agreement?"))

          accepted = !CommandLine.YesNo
        else
          accepted = !Popup.AnyQuestionRichText(
            # popup heading, with rich text widget and Yes/No buttons
            _("Do you accept this license agreement?"),
            Builtins.mergestring(rt_licenses_l, "\n"),
            70,
            20,
            Label.YesButton,
            Label.NoButton,
            :focus_none
          )
        end

        Builtins.y2milestone("Licenses accepted: %1", accepted)

        if !accepted
          Builtins.y2milestone("License not accepted: %1", toinstall)
          @last_op_canceled = true
          return false
        end

        # mark licenses as confirmed
        Builtins.foreach(licenses) { |p, _l| Pkg.PkgMarkLicenseConfirmed(p) }
        @last_op_canceled = false
      end

      return false if !SelectPackages(toinstall, toremove)

      if !Pkg.PkgSolve(false)
        Builtins.y2error("Package solve failed: %1", Pkg.LastError)

        # error message, after pressing [OK] the package manager is displayed
        Report.Error(
          _(
            "There are unresolved dependencies which need\nto be solved manually in the software manager."
          )
        )

        # disable repomanagement during installation
        repomgmt = !Mode.installation
        # start the package selector
        ret = PackagesUI.RunPackageSelector(
          "enable_repo_mgr" => repomgmt, "mode" => :summaryMode
        )

        Builtins.y2internal("Package selector returned: %1", ret)

        # do not fix the system
        return false if ret == :cancel || ret == :close
      end

      # is a package or a patch selected for installation?
      any_to_install = Pkg.IsAnyResolvable(:package, :to_install) ||
        Pkg.IsAnyResolvable(:patch, :to_install)

      # [int successful, list failed, list remaining, list srcremaining, list update_messages]
      result = Pkg.PkgCommit(0)
      Builtins.y2debug("PkgCommit: %1", result)
      if result.nil? || Ops.get_list(result, 1, []) != []
        Builtins.y2error(
          "Package commit failed: %1",
          Ops.get_list(result, 1, [])
        )
        return false
      end

      PackagesUI.show_update_messages(result)

      Builtins.foreach(Ops.get_list(result, 2, [])) do |remaining|
        if ok == true
          if Builtins.contains(toinstall, remaining)
            Builtins.y2error("Package remain: %1", remaining)
            ok = false
          end
        end
      end
      return false if ok != true

      # Show popup when new kernel was installed
      # But omit it during installation, one is run at its end.
      # #25071
      Kernel.InformAboutKernelChange if !Stage.initial && !Stage.cont

      # a package or a patch was installed, may be that there is a new yast agent
      if any_to_install
        # register the new agents
        SCR.RegisterNewAgents
      end

      # check if the required packages have been installed
      if !InstalledAll(toinstall)
        Builtins.y2error("Required packages have not been installed")
        return false
      end

      true
    end

    def DoInstallAndRemove(toinstall, toremove)
      toinstall = deep_copy(toinstall)
      toremove = deep_copy(toremove)
      # remember the current solver flags
      solver_flags = Pkg.GetSolverFlags

      # do not install recommended packages for already installed packages (bnc#445476)
      Pkg.SetSolverFlags("ignoreAlreadyRecommended" => true)

      ret = DoInstallAndRemoveInt(toinstall, toremove)

      # restore the original flags
      Pkg.SetSolverFlags(solver_flags)

      ret
    end

    # Is a package available?
    # @return true if yes (nil = no package source available)
    def Available(package)
      EnsureSourceInit()

      if !@source_initialized
        # error no source initialized
        return nil
      end

      Pkg.IsAvailable(package)
    end

    def InitRPMQueryBinary
      return if @_rpm_query_binary_initialized

      # rpmqpack is a way faster
      if Ops.greater_than(
        SCR.Read(path(".target.size"), "/usr/bin/rpmqpack"),
        -1
      )
        @_rpm_query_binary = "/usr/bin/rpmqpack "
        # than rpm itself
      elsif Ops.greater_than(SCR.Read(path(".target.size"), "/bin/rpm"), -1)
        @_rpm_query_binary = "/bin/rpm -q "
      end

      @_rpm_query_binary_initialized = true

      nil
    end

    # Is a package provided in the system? Is there any installed package providing 'package'?
    # @return true if yes
    def Installed(package)
      # This is a most commonly called function and so it's
      # important that it's fast, especially in the common
      # case, where all dependencies are satisfied.
      # Unfortunately, initializing Pkg reads the RPM database...
      # so we must avoid it.
      # added --whatprovides due to bug #76181
      0 ==
        Convert.to_integer(
          SCR.Execute(
            path(".target.bash"),
            Ops.add("rpm -q --whatprovides ", package)
          )
        )
      # return Pkg::IsProvided (package);
    end

    # Is a package installed? Checks only the package name in contrast to Installed() function.
    # @return true if yes
    def PackageInstalled(package)
      InitRPMQueryBinary()

      # This is commonly called function and so it's
      # important that it's fast, especially in the common
      # case, where all dependencies are satisfied.
      0 ==
        Convert.to_integer(
          SCR.Execute(
            path(".target.bash"),
            Ops.add(@_rpm_query_binary, package)
          )
        )
    end

    # Is a package available? Checks only package name, not list of provides.
    # @return true if yes (nil = no package source available)
    def PackageAvailable(package)
      EnsureSourceInit()

      if !@source_initialized
        # error no source initialized
        return nil
      end

      Pkg.PkgAvailable(package)
    end

    # Check if packages are installed
    #
    # Install them if they are not and user approves installation
    #
    # @param a list of packages to check (and install)
    # @return [Boolean] true if installation succeeded or packages were installed,
    # false otherwise
    def CheckAndInstallPackages(packages)
      packages = deep_copy(packages)
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
    # @param [Array<String>] packages a list of packages to check (and install)
    # @return [Boolean] true if installation succeeded, packages were installed
    # before or user decided to continue, false otherwise
    def CheckAndInstallPackagesInteractive(packages)
      packages = deep_copy(packages)
      success = CheckAndInstallPackages(packages)
      if !success
        if !LastOperationCanceled()
          if Mode.commandline
            # error report
            Report.Error(_("Installing required packages failed."))
          else
            success = Popup.ContinueCancel(
              # continue/cancel popup
              _(
                "Installing required packages failed. If you continue\n" \
                  "without installing required packages,\n" \
                  "YaST may not work properly.\n"
              )
            )
          end
        else
          if Mode.commandline
            Report.Error(
              # error report
              _("Cannot continue without installing required packages.")
            )
          else
            success = Popup.ContinueCancel(
              # continue/cancel popup
              _(
                "If you continue without installing required \npackages, YaST may not work properly.\n"
              )
            )
          end
        end
      end
      success
    end

    def InstallKernel(kernel_modules)
      kernel_modules = deep_copy(kernel_modules)
      # this function may be responsible for the horrible startup time
      Builtins.y2milestone("want: %1", kernel_modules)
      if kernel_modules == []
        return true # nothing to do
      end

      # check whether tag "kernel" is provided
      # do not initialize the package manager if it's not necessary
      rpm_command = "/bin/rpm -q --whatprovides kernel"
      Builtins.y2milestone("Starting RPM query: %1", rpm_command)
      output = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), rpm_command)
      )
      Builtins.y2debug("result of the query: %1", output)

      if Ops.get_integer(output, "exit", -1) == 0
        packages = Builtins.splitstring(
          Ops.get_string(output, "stdout", ""),
          "\n"
        )
        packages = Builtins.filter(packages) { |pkg| pkg != "" }
        Builtins.y2milestone("Packages providing tag 'kernel': %1", packages)

        return true if Ops.greater_than(Builtins.size(packages), 0)

        Builtins.y2milestone("Huh? Kernel is not installed??")
      else
        Builtins.y2warning("RPM query failed, quering the package manager...")
      end

      EnsureTargetInit()

      provides = Pkg.PkgQueryProvides("kernel")
      Builtins.y2milestone("provides: %1", provides)

      kernels = Builtins.filter(provides) do |l|
        Ops.get_symbol(l, 1, :NONE) == :BOTH ||
          Ops.get_symbol(l, 1, :NONE) == Ops.get_symbol(l, 2, :NONE)
      end

      if Builtins.size(kernels) != 1
        Builtins.y2error("not exactly one package provides tag kernel")
      end

      kernel = Ops.get_string(kernels, [0, 0], "none")
      packs = [kernel]

      EnsureSourceInit() if !Pkg.IsProvided(kernel)

      # TODO: for 9.2, we always install all packages, but
      # we could only install those really needed (#44394)
      InstallAll(packs)
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
    publish function: :EnsureTargetInit, type: "void ()"
    publish function: :EnsureSourceInit, type: "void ()"
    publish function: :PackageInstalled, type: "boolean (string)"
    publish function: :PackageAvailable, type: "boolean (string)"
    publish function: :CheckAndInstallPackages, type: "boolean (list <string>)"
    publish function: :CheckAndInstallPackagesInteractive, type: "boolean (list <string>)"
    publish function: :InstallKernel, type: "boolean (list <string>)"
  end

  PackageSystem = PackageSystemClass.new
  PackageSystem.main
end
