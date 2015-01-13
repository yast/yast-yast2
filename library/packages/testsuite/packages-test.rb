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
# File:	packages-test.ycp
# Package:	yast2
# Summary:	Packages manipulation test client
# Authors:	Michal Svec <msvec@suse.cz>
#
# $Id$
module Yast
  class PackagesTestClient < Client
    def main
      Yast.import "Popup"
      Yast.import "Package"

      @success = 0
      @failure = 0

      @e = "mtx"
      @n = "blemc"

      @el = [@e, "xntp-doc"]
      @nl = [@n, "bzum"]

      # FIXME: test presence of mtx, xntp-doc

      # failtest: T(``(Package::Installed("rpm")), false);

      T(->() { Package.Available(@e) }, true)
      T(->() { Package.Available(@n) }, false)

      T(->() { Package.AvailableAll(@el) }, true)
      T(->() { Package.AvailableAll(@nl) }, false)
      T(->() { Package.AvailableAll(Builtins.add(@el, "bzum")) }, false)

      T(->() { Package.AvailableAny(@el) }, true)
      T(->() { Package.AvailableAny(@nl) }, false)
      T(->() { Package.AvailableAny(Builtins.add(@el, "bzum")) }, true)

      T(->() { Package.Installed("rpm") }, true)
      T(->() { Package.Installed(@e) }, false)
      T(->() { Package.Installed(@n) }, false)

      T(->() { Package.InstalledAll(["rpm", "glibc"]) }, true)
      T(->() { Package.InstalledAll(["rpm", @e]) }, false)
      T(->() { Package.InstalledAll(["rpm", @n]) }, false)
      T(->() { Package.InstalledAll(@nl) }, false)
      T(->() { Package.InstalledAll([]) }, true)

      T(->() { Package.InstalledAny(["rpm", "glibc"]) }, true)
      T(->() { Package.InstalledAny(["rpm", @e]) }, true)
      T(->() { Package.InstalledAny(["rpm", @n]) }, true)
      T(->() { Package.InstalledAny(@el) }, false)
      T(->() { Package.InstalledAny(@nl) }, false)
      T(->() { Package.InstalledAny([]) }, false)

      T(->() { Package.DoInstall([@n]) }, false)
      T(->() { Package.DoInstall([@e]) }, true)
      T(->() { Package.Installed(@e) }, true)

      T(->() { Package.DoRemove([@n]) }, false)
      T(->() { Package.DoRemove([@e]) }, true)
      T(->() { Package.Installed(@e) }, false)

      if false
        T(->() { Package.Install(@n) }, false)
        T(->() { Package.Install(@e) }, false)

        Package.InstallAll(@el)
        Package.InstallAny(@el)

        Package.Remove(@e)
        Package.RemoveAll(@el)

        Package.DoInstallAndRemove([], [])
      end

      Popup.AnyMessage(
        "Package Testsuite",
        Builtins.sformat(
          "Number of Successes: %1\nNumber of Failures: %2",
          @success,
          @failure
        )
      ) 

      # EOF

      nil
    end

    # testing function
    def T(f, expect)
      f = deep_copy(f)
      r = Convert.to_boolean(Builtins.eval(f))
      if r != expect
        Popup.Error(
          Builtins.sformat("Failed: %1 = %2 (expected %3)", f, r, expect)
        )
        Builtins.y2internal(1, "Failed: %1 = %2 (expected %3)", f, r, expect)
        @failure = Ops.add(@failure, 1)
      else
        Builtins.y2security(1, "Passed: %1", f)
        @success = Ops.add(@success, 1)
      end

      nil
    end
  end
end

Yast::PackagesTestClient.new.main
